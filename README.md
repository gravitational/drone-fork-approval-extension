# Drone Untrusted Build Approval

## Installation

Create a shared secret:

```console
$ DRONE_SECRET="$(openssl rand -base64 32)"
```


Build the plugin:

```
$ docker build . drone-secret
```

Run the plugin:

```console
$ docker run -d \
  --publish=3000:3000 \
  --env=DRONE_SECRET
  --restart=always \
  --name=drone-approval
```

Update your [Drone server configuration](https://docs.drone.io/extensions/validation/)
to include the plugin address and the shared secret.

```text
DRONE_VALIDATE_PLUGIN_ENDPOINT=https://<your plugin host>:3000
DRONE_VALIDATE_PLUGIN_SECRET=<your secret>
```
