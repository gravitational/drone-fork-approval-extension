# Drone Fork Approval Extension

:electric_plug: Fork Approval is a simple [Drone Validation Extension](https://docs.drone.io/extensions/validation/)
that ensures every PR originating from a fork must have its Drone CI build
approved before it will run.

Perhaps you're worried about OSS contributors running crypto miners?
Perhaps you'd like to use privileged containers in your PR pipeline?

Fork Approval can help you do so safely!

## Usage

1. Create a shared secret:

```console
$ DRONE_SECRET="$(openssl rand -base64 32)"
```

2. Run the container:

```console
$ docker run --detach \
  --restart=always \
  --publish=3080:80 \
  --env=DRONE_SECRET \
  --name=drone-approval \
  quay.io/gravitational/drone-fork-approval-extension:0.1.0
```


3. Update your [Drone server configuration](https://docs.drone.io/extensions/validation/)
to include the plugin address and the shared secret.

```text
DRONE_VALIDATE_PLUGIN_ENDPOINT=https://<your plugin host>:3080
DRONE_VALIDATE_PLUGIN_SECRET=<your secret>
```

### Caveats
`gravitational/drone-fork-approval-extension` does not publish a `:latest` tag.
Choose a fixed version.

This extension does not support HTTPS in its go configuration. Please
put it behind [nginx](https://nginx.org/en/) or host the extension
on the same system that hosts your main drone server.

This extension has only been tested with GitHub.

## Development

Run `make help` for a list of targets.

## Design

Drone Fork Approval is intentionally limited in scope to keep its
security implications understandable and limited. The entire approval
workflow is summarized below:

```text
GitHub          Drone           Fork Approval
 |    webhook    |               |
 | ------------->|  .Validate()  |
 |               | ------------->|
                 |               | (source repo == target repo)? 200 : 499
 (if 499, wait   |<------------- |
  for approval)  |               |
                 |
Drone User       |
 |   approval    |                      Drone Runner
 | ------------->|                       |
 |               | --------------------->|
                 |                       | (execution begins)
```

For more information on the validation trigger logic, see:
 * https://github.com/drone/drone/blob/v1.10.1/trigger/trigger.go#L238-L256
 * https://github.com/drone/docs/blob/aea0b96ffbaebd5862a8439dd4e39ef57914d056/content/extensions/validation.md#response
 * https://github.com/drone/drone-go/blob/v1.6.0/plugin/validator/client.go#L37-L48
