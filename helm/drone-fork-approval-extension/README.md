# Drone Fork Approval Extension installation with Helm

This page will guide you through using the `drone-fork-approval-extension` Helm chart to install the Drone Fork Approval Extension.

Before beginning installation, you need a functioning install of [Drone server on Kubernetes](https://github.com/drone/charts/blob/master/charts/drone/README.md).

## Use

This chart is not currently published to a helm repository. Instead, clone the git repo and use it locally.

### Clone

```
$ git clone https://github.com/gravitational/drone-fork-approval-extension
$ cd drone-fork-approval-extension
```

### Configuration (values)

A minimal install of Drone server requires the following helm value:

```yaml
# NOTE: Change this to match the DRONE_VALIDATE_PLUGIN_SECRET secret set in your Drone server configs.
secret: xxxxxxxxxxxxx
```

Save this in a file called `values.yaml`

### Install the Chart

Run `helm install` with your values provided:

```console
$ helm install -n drone drone-fork-approval-extension ./helm/drone-fork-approval-extension -f values.yaml
```

Once `helm install` command is complete, your Kubernetes cluster will begin creating resources. To see how your deploy is shaping up, run:

```console
$ kubectl -n drone get pods
NAME                                             READY   STATUS    RESTARTS   AGE
drone-ddf846495-5sv76                            1/1     Running   0          2h
drone-fork-approval-extension-56bc585bd8-vbgxm   1/1     Running   0          5m
drone-runner-kube-695fb98b55-rl8b4               1/1     Running   0          2h
```

If the `drone-fork-approval-extension` pod's state is `Running`, the extension launched.
Check the logs to make sure there are no warnings or errors:

```console
$ kubectl -n drone logs -l 'app.kubernetes.io/name=drone-fork-approval-extension'
time="2021-05-15T04:58:14Z" level=info msg="server listening on address :3888"
```

If you see the "server listening on address" text above without error, the Fork Approval Extension is running.

### Add Enviroment Variables to the Drone Deployment

Now that the extension is available in your kubernetes cluster, configure the
Drone service to reference the Fork Approval Extension. Add the following to
the `env` section of the Drone helm. Make sure `DRONE_VALIDATE_PLUGIN_SECRET`
matches the secret configured above.

```yaml
env:
  DRONE_VALIDATE_PLUGIN_ENDPOINT: http://drone-fork-approval-extension:3888
  DRONE_VALIDATE_PLUGIN_SECRET: xxxxxxxxxxxxx
```

Helm upgrade the Drone deployment with the edited yaml:

```console
$ helm upgrade -n drone drone drone/drone -f drone-values.yaml
```

Open a pull request against a drone enabled repo.  Check that it shows up in
the Fork Approval Extension logs:

```console
$ kubectl --namespace drone logs -l 'app.kubernetes.io/name=drone-fork-approval-extension'
time="2021-05-15T04:58:14Z" level=info msg="server listening on address :3888"
time="2021-05-15T05:11:56Z" level=info msg="https://github.com/danger-della/drone-external-auth-test/pull/5 needs approval" source=wadells/drone-external-auth-test target=danger-della/drone-external-auth-test
```

If you see an entry for the pull request, the Drone server is correctly integrated with the Fork Approval Extension.
