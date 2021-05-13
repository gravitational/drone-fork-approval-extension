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
# avoid lazily evaluation (and thus rerunning the shell command several times)
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
DOCKER_NOROOT := -u $$(id -u):$$(id -g)
# docker doesn't allow "+" in image tags: https://github.com/docker/distribution/issues/1201
DOCKER_VERSION := $(subst +,-,$(VERSION))
DOCKER_IID := $(BUILDDIR)/docker-$(DOCKER_VERSION).iid
DOCKER_REPO := quay.io/gravitational/drone-fork-approval-extension

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

.PHONY: build
build: ## Build the binary.
build: $(OUT)

$(OUT): $(GOSRC) $(MAKEFILE)
	go build $(LDFLAGS) -v -o $(OUT) $(ROOTDIR)

.PHONY: test
test: ## Run tests.
	go test -race ./...

.PHONY: lint
lint: ## Run static analysis against the source code.
	docker run $(DOCKER_NOROOT) --rm \
		-v $(ROOTDIR):$(ROOTDIR) \
		-w $(ROOTDIR) \
		-e XDG_CACHE_HOME=/tmp \
		golangci/golangci-lint:v1.35.2 golangci-lint run


.PHONY: image
image: ## Build docker image.
image: $(DOCKER_IID)

$(DOCKER_IID): $(OUT) $(DOCKERFILE)
	docker build $(ROOTDIR) --iidfile $(DOCKER_IID)

.PHONY: build-in-container
build-in-container: ## Build the binary in a container with a known go.
build-in-container: $(GOSRC) $(MAKEFILE)
	docker run $(DOCKER_NOROOT) --rm \
		-v "$(ROOTDIR):/go/src/drone-fork-approval-extension" \
		-w /go/src/drone-fork-approval-extension \
		-e XDG_CACHE_HOME=/tmp \
		golang:1.16 make test build

.PHONY: release
release: ## Build and tag the release image.
release: build-in-container $(DOCKER_IID)
	docker tag "$$(cat $(DOCKER_IID))" $(DOCKER_REPO):$(DOCKER_VERSION)


.PHONY: publish
publish: ## Publish release artifacts to docker repo.
publish: release
	docker push $(DOCKER_REPO):$(DOCKER_VERSION)

.PHONY: get-version
get-version:
	@echo $(VERSION)
