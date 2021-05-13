/*
Copyright 2021 Gravitational, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package main

import (
	"context"
	"net/http"
	"os"
	"strings"

	"github.com/drone/drone-go/plugin/validator"

	"github.com/kelseyhightower/envconfig"
	log "github.com/sirupsen/logrus"
)

// plugin is fulfills the validator.Plugin interface
type plugin struct{}

// Validate approves builds from the same repository, and blocks builds from forks.
func (p *plugin) Validate(ctx context.Context, req *validator.Request) error {
	switch req.Build.Event {
	case "push", "tag": // triggered by folks with write access to the repo, therefore trusted
		log.Debugf("%s build ignored", req.Build.Event)
		return nil
	case "cron", "promote", "rollback", "custom": // triggered by folks with write access in drone
		log.Debugf("%s build ignored", req.Build.Event)
		return nil
	case "pull_request": // may be triggered by folks without write access, needs approval
		break
	default: // unknown new event, fail secure
		log.Warnf("%s build unrecognized", req.Build.Event)
		return validator.ErrBlock
	}

	sourceRepo := req.Build.Fork
	targetRepo := req.Repo.Slug
	if sourceRepo != targetRepo { // then the PR is coming from a fork
		log.WithFields(log.Fields{"source": sourceRepo, "target": targetRepo}).Infof("%s needs approval", req.Build.Link)
		return validator.ErrBlock
	} else {
		log.WithFields(log.Fields{"source": sourceRepo, "target": targetRepo}).Infof("%s approved", req.Build.Link)
		return nil
	}
}

// version and commit allow injection of version info via -ldflags
var (
	version = "unknown"
	commit  = "unknown"
)

// config contains all configuration as environment variables
type config struct {
	Bind   string `envconfig:"DRONE_BIND"`
	Debug  bool   `envconfig:"DRONE_DEBUG"`
	Secret string `envconfig:"DRONE_SECRET"`
}

func main() {
	if len(os.Args) > 1 {
		if strings.Contains(os.Args[1], "version") {
			log.Info("version:\t" + version)
			log.Info("commit: \t" + commit)
			return
		} else {
			log.Fatal("unexpected arguments: " + strings.Join(os.Args[1:], " "))
		}
	}

	var cfg config
	err := envconfig.Process("", &cfg)
	if err != nil {
		log.Fatal(err)
	}

	if cfg.Debug {
		log.SetLevel(log.DebugLevel)
	}

	if cfg.Secret == "" {
		log.Fatalln("missing DRONE_SECRET in environment")
	}
	if cfg.Bind == "" {
		cfg.Bind = ":80"
	}

	handler := validator.Handler(
		cfg.Secret,
		&plugin{},
		log.StandardLogger(),
	)

	log.Infof("server listening on address %s", cfg.Bind)

	http.Handle("/", handler)
	log.Fatal(http.ListenAndServe(cfg.Bind, nil))
}
