package main

import (
	"context"
	"testing"

	"github.com/drone/drone-go/plugin/validator"
)

// a request captured from the wild, for illustration:
//
// *github.com/drone/drone-go/plugin/validator.Request {
// 		Build: github.com/drone/drone-go/drone.Build {
//			ID: 0,
//			RepoID: 1,
//			Trigger: "@hook",
//			Number: 0,
//			Parent: 0,
//			Status: "pending",
//			Error: "",
//			Event: "pull_request",
//			Action: "synchronized",
//			Link: "https://github.com/danger-della/drone-external-auth-test/pull/2",
//			Timestamp: 0,
//			Title: "External PR test",
//			Message: "External PR test",
//			Before: "21e9d7f9b8044f6482d2b0984e71d7290ce27547",
//			After: "34468fcf1556a5004a2cb1b112039ee89db71dcf",
//			Ref: "refs/pull/2/head",
//			Fork: "wadells/drone-external-auth-test",
//			Source: "extern-pr-test",
//			Target: "main",
//			Author: "wadells",
//			AuthorName: "",
//			AuthorEmail: "",
//			AuthorAvatar: "https://avatars.githubusercontent.com/u/187314?v=4",
//			Sender: "wadells",
//			Params: map[string]string nil,
//			Cron: "",
//			Deploy: "",
//			DeployID: 0,
//			Debug: false,
//			Started: 0,
//			Finished: 0,
//			Created: 1620711819,
//			Updated: 1620711819,
//			Version: 0,
//			Stages: []*github.com/drone/drone-go/drone.Stage len: 0, cap: 0, nil,},
//		Config: github.com/drone/drone-go/drone.Config {
//			Data: "...omitted, it is the yaml...",
//			Kind: "",},
//		Repo: github.com/drone/drone-go/drone.Repo {
//			ID: 1,
//			UID: "365374240",
//			UserID: 1,
//			Namespace: "danger-della",
//			Name: "drone-external-auth-test",
//			Slug: "danger-della/drone-external-auth-test",
//			SCM: "",
//			HTTPURL: "https://github.com/danger-della/drone-external-auth-test.git",
//			SSHURL: "git@github.com:danger-della/drone-external-auth-test.git",
//			Link: "https://github.com/danger-della/drone-external-auth-test",
//			Branch: "main",
//			Private: false,
//			Visibility: "public",
//			Active: true,
//			Config: ".drone.yml",
//			Trusted: false,
//			Protected: true,
//			IgnoreForks: false,
//			IgnorePulls: false,
//			CancelPulls: false,
//			CancelPush: false,
//			Throttle: 0,
//			Timeout: 60,
//			Counter: 0,
//			Synced: 0,
//			Created: 0,
//			Updated: 0,
//			Version: 0,
//			Signer: "",
//			Secret: "",
//			Build: (*"github.com/drone/drone-go/drone.Build")(0xc000694d20),},}

func TestForkPullRequest(t *testing.T) {
	p := &plugin{}
	req := validator.Request{}
	req.Build.Event = "pull_request"
	req.Build.Fork = "wadells/drone-external-auth-test"
	req.Repo.Slug = "danger-della/drone-external-auth-test"
	err := p.Validate(context.Background(), &req)
	if err != validator.ErrBlock {
		t.Fatal("expected PR from fork to be blocked")
	}
}

func TestSameRepoPullRequest(t *testing.T) {
	p := &plugin{}
	req := validator.Request{}
	req.Build.Event = "pull_request"
	req.Build.Fork = "danger-della/drone-external-auth-test"
	req.Repo.Slug = "danger-della/drone-external-auth-test"
	err := p.Validate(context.Background(), &req)
	if err != nil {
		t.Fatal("expected PR from the same repo to be approved")
	}
}

func TestUnknownEvent(t *testing.T) {
	p := &plugin{}
	req := validator.Request{}
	req.Build.Event = "merge_request"
	err := p.Validate(context.Background(), &req)
	if err != validator.ErrBlock {
		t.Fatal("expected build with unknown Event to be blocked")
	}

}
