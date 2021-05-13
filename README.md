# Drone Fork Approval Extension

:electric_plug: Fork Approval is a simple [Drone Validation Extension](https://docs.drone.io/extensions/validation/)
that ensures every PR that comes from a fork must have its Drone CI build
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

## Development

Run `make help` for a list of targets.
