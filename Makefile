# Copyright 2021 Gravitational, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
ROOTDIR := $(patsubst %/,%,$(dir $(MAKEFILE)))

ifeq ($(origin VERSION), undefined)
# avoid lazy evaluation (and thus rerunning the shell command several times)
VERSION := $(shell ./version.sh)
endif

ifeq ($(origin COMMIT), undefined)
COMMIT := $(shell git rev-parse HEAD)
endif

BUILDDIR := $(ROOTDIR)/build
OUT := $(BUILDDIR)/drone-fork-approval-extension
GOSRC := $(shell find $(ROOTDIR) -type f -name '*.go') go.mod go.sum
LDFLAGS=-ldflags "-X=main.version=$(VERSION) -X=main.commit=$(COMMIT)"

DOCKERFILE := $(ROOTDIR)/Dockerfile
# XDG_CACHE_HOME set to avoid permissions issues with root owned /.cache
DOCKER_NOROOT := -u $$(id -u):$$(id -g) -e XDG_CACHE_HOME=/tmp
# docker doesn't allow "+" in image tags: https://github.com/docker/distribution/issues/1201
DOCKER_VERSION := $(subst +,-,$(VERSION))
RELEASE_IID := $(BUILDDIR)/release-$(DOCKER_VERSION).iid
DOCKER_REPO := quay.io/gravitational/drone-fork-approval-extension

DOCKERSUMDIR := $(ROOTDIR)/.dockersum
GOBUILD_IMAGE  := golang:1.16
GOBUILD_IID := $(DOCKERSUMDIR)/golang.iid
GOLANGCILINT_IMAGE := golangci/golangci-lint:v1.35.2
GOLANGCILINT_IID := $(DOCKERSUMDIR)/golangci-lint.iid

HELMSRC := $(shell find helm -type f)
HELM_IMAGE := alpine/helm:3.5.4
HELM_IID := $(DOCKERSUMDIR)/helm.iid
KUBEAUDIT_IMAGE := shopify/kubeaudit:v0.14.0
KUBEAUDIT_IID := $(DOCKERSUMDIR)/kubeaudit.iid
KUBEAUDIT_OUT := $(BUILDDIR)/helm-rendered.yaml

# kudos to https://gist.github.com/prwhite/8168133 for inspiration
.PHONY: help
help: ## Show this message.
	@echo 'Usage: make [options] [target] ...'
	@echo
	@echo 'Options: run `make --help` for options'
	@echo
	@echo 'Targets:'
	@grep -E --no-filename '^(.+)\:\ ##\ (.+)' ${MAKEFILE_LIST} | column -t -c 2 -s ':#' | sort | sed 's/^/  /'

.PHONY: clean
clean: ## Remove build artifacts.
	rm -rf $(BUILDDIR)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

.PHONY: build
build: ## Build the binary.
build: $(OUT)

$(OUT): $(GOSRC) $(MAKEFILE) | $(BUILDDIR)
	go build $(LDFLAGS) -v -o $(OUT) $(ROOTDIR)

.PHONY: test
test: ## Run tests.
	go test -race ./...

.PHONY: lint
lint: ## Run static analysis against the source code.
lint: lint-go lint-helm

$(HELM_IID): Makefile
	docker pull $(HELM_IMAGE)
	docker inspect --format='{{index .RepoDigests 0}}' $(HELM_IMAGE) > $(HELM_IID)

$(KUBEAUDIT_OUT): $(HELMSRC) $(HELM_IID) | $(BUILDDIR)
	docker run $(DOCKER_NOROOT) --rm \
		-v $(ROOTDIR):$(ROOTDIR) \
		-w $(ROOTDIR) \
		$$(cat $(HELM_IID)) \
		template -n drone drone-fork-approval-plugin ./helm/drone-fork-approval-extension --set secret=A1234567890 > $(KUBEAUDIT_OUT)

$(KUBEAUDIT_IID): Makefile
	docker pull $(KUBEAUDIT_IMAGE)
	docker inspect --format='{{index .RepoDigests 0}}' $(KUBEAUDIT_IMAGE) > $(KUBEAUDIT_IID)

.PHONY: lint-helm
lint-helm: ## Run kubeaudit against the rendered helm chart.
lint-helm: $(KUBEAUDIT_IID) $(KUBEAUDIT_OUT)
	docker run $(DOCKER_NOROOT) --rm \
		-v $(ROOTDIR):$(ROOTDIR) \
		-w $(ROOTDIR) \
		$$(cat $(KUBEAUDIT_IID)) all -k helm/.kubeaudit.yml -f $(KUBEAUDIT_OUT)

$(GOLANGCILINT_IID): Makefile
	docker pull $(GOLANGCILINT_IMAGE)
	docker inspect --format='{{index .RepoDigests 0}}' $(GOLANGCILINT_IMAGE) > $(GOLANGCILINT_IID)

.PHONY: lint-go
lint-go: ## Run golangci-lint against all go source.
lint-go: $(GOLANGCILINT_IID)
	docker run $(DOCKER_NOROOT) --rm \
		-v $(ROOTDIR):$(ROOTDIR) \
		-w $(ROOTDIR) \
		$$(cat $(GOLANGCILINT_IID)) golangci-lint run

.PHONY: image
image: ## Build docker image.
image: $(RELEASE_IID)

$(RELEASE_IID): $(OUT) $(DOCKERFILE)
	docker build $(ROOTDIR) --iidfile $(RELEASE_IID)

$(GOBUILD_IID): Makefile
	docker pull $(GOBUILD_IMAGE)
	docker inspect --format='{{index .RepoDigests 0}}' $(GOBUILD_IMAGE) > $(GOBUILD_IID)

.PHONY: build-in-container
build-in-container: ## Build the binary in a container with a known go.
build-in-container: $(GOSRC) $(GOBUILD_IID) $(MAKEFILE)
	docker run $(DOCKER_NOROOT) --rm \
		-v "$(ROOTDIR):/go/src/drone-fork-approval-extension" \
		-w /go/src/drone-fork-approval-extension \
		-e XDG_CACHE_HOME=/tmp \
		$$(cat $(GOBUILD_IID)) make build

.PHONY: test-in-container
test-in-container: ## Run tests in a container with a known go.
test-in-container: $(GOSRC) $(GOBUILD_IID) $(MAKEFILE)
	docker run $(DOCKER_NOROOT) --rm \
		-v "$(ROOTDIR):/go/src/drone-fork-approval-extension" \
		-w /go/src/drone-fork-approval-extension \
		$$(cat $(GOBUILD_IID)) make test

.PHONY: update-images
update-images: ## Update docker images used for building and testing.
	rm -rf $(DOCKERSUMDIR)
	mkdir -p $(DOCKERSUMDIR)
	$(MAKE) $(GOBUILD_IID) $(GOLANGCILINT_IID) $(KUBEAUDIT_IID) $(HELM_IID)

.PHONY: release
release: ## Build and tag the release image.
release: build-in-container test-in-container $(RELEASE_IID)
	docker tag "$$(cat $(RELEASE_IID))" $(DOCKER_REPO):$(DOCKER_VERSION)

.PHONY: publish
publish: ## Publish release artifacts to docker repo.
publish: release
	docker push $(DOCKER_REPO):$(DOCKER_VERSION)

.PHONY: get-version
get-version:
	@echo $(VERSION)
