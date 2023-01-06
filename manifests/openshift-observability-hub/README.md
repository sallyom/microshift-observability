## Send Telemetry from MicroShift to OpenShift

Telemetry data from MicroShift can be directed to OpenShift (OCP) eliminating the need for prometheus in MicroShift.
Metrics are sent from MicroShift OpenTelemetry Collector using the `prometheusremotewrite` exporter to `thanos receiver` in the OCP cluster.
Traces are sent from MicroShift OpenTelemetry Collector to OCP OpentelemetryCollector and then to OCP Jaeger.


### Hub OpenShift cluster

Install `OpenTelemetry Operator` and `Jaeger Operator` from OperatorHub. Then deploy Thanos receiver outlined below.

#### Deploy Thanos Receive

Refer to [federated prometheus blog](https://cloud.redhat.com/blog/federated-prometheus-with-thanos-receive)
and also [thanos-receive OpenShift demo](https://github.com/rhthsa/openshift-demo/blob/main/thanos-receive.md)

For this example, thanos-store-gateway is not deployed. Refer to the blogs above to configure thanos storage for HA.

```bash
cd thanos-receiver
oc create ns thanos
oc apply -f thanos-scc.yaml

# If adding thanos-store-gateway run below command
#oc -n thanos create secret generic store-s3-credentials --from-file=store-s3-secret.yaml
#oc -n thanos create thanos-store-gateway-sa.yaml
#oc -n thanos adm policy add-scc-to-user anyuid -z thanos-store-gateway

# create thanos-receive, edge, and thanos-querier serviceaccounts and policies
oc -n thanos create -f sa.yaml
oc -n thanos adm policy add-cluster-role-to-user system:auth-delegator -z thanos-receive
oc -n thanos adm policy add-role-to-user view -z edge
oc -n thanos annotate serviceaccount thanos-receive serviceaccounts.openshift.io/oauth-redirectreference.thanos-receive='{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"thanos-receive"}}'
oc -n thanos annotate serviceaccount thanos-querier serviceaccounts.openshift.io/oauth-redirectreference.thanos-querier='{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"thanos-querier"}}'

# create serviceaccount tokens
oc -n thanos create -f thanos-sa-token-secrets.yaml 

# If adding thanos-store-gateway run below commands
# create thanos store gateway
# oc -n thanos create -f store-gateway.yaml
# oc -n thanos get pods -l "app=thanos-store-gateway"

# create thanos receiver
oc -n thanos create secret generic thanos-receive-proxy --from-literal=session_secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c43)
oc -n thanos apply -f thanos-receive.yaml
oc -n thanos create route reencrypt thanos-receive --service=thanos-receive --port=web-proxy --insecure-policy=Redirect

# create thanos querier
oc -n thanos create secret generic thanos-querier-proxy --from-literal=session_secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c43)
oc -n thanos create -f thanos-querier-thanos-receive.yaml
oc -n thanos create route reencrypt thanos-querier --service=thanos-querier --port=web-proxy --insecure-policy=Redirect

# scp edge serviceaccount token to edge cluster
oc -n thanos create token edge --duration 999999h > edge-token
scp edge-token redhat@<MICROSHIFT_VM>:

# back to openshift-observability-hub directory
cd ../

# create jaeger instance to visualize trace data
oc -n thanos apply -f jaeger.yaml

# create opentelemetry collector sidecar in thanos-receiver and route to collect trace data
oc -n thanos apply -f ocp-sidecar-otelcol.yaml
# this might be a bug, but have to kill the thanos-receive-0 pod to refresh and pick up the sidecar container
oc -n thanos delete pod thanos-receive-0
# check that thanos-receive-0 now has container -c otc-container running
oc -n thanos logs thanos-receive-0 -c otc-container
oc -n thanos apply -f ocp-route.yaml
```

#### Find Thanos Receive URL, scp to MicroShift for prometheusremotewrite exporter

```
oc -n thanos get route thanos-receive -o jsonpath='{.status.ingress[*].host}' > thanos-receive-url
scp thanos-receive-url redhat@<MICROSHIFT_VM>:
```

#### Find OCP OpenTelemetry Collector URL, scp to MicroShift for otlphttp exporter

```
oc -n thanos get route otelcol -o jsonpath='{.status.ingress[*].host}' > ocp-otelcol-url
scp ocp-otelcol-url redhat@<MICROSHIFT_VM>:
```

#### Extract root CA and SCP to edge MicroShift cluster

```bash
oc extract cm/kube-root-ca.crt -n openshift-config
scp ca.crt   redhat@<MICROSHIFT_VM>:
```

### Edge MicroShift cluster

#### Configure Authentication for Thanos Receive

Run the following from `edge MicroShift cluster otelcol namespace`, where OpenTelemetryCollector is running & collecting data

```bash
# scp'd files are at ~/redhat/.
cd
# may need 'oc delete cm/client-ca -n otelcol`, `oc delete cm/edge-token -n otelcol` first
oc create configmap -n otelcol client-ca --from-file ca.crt
oc create configmap -n otelcol edge-token --from-file edge-token
```
You should now be able to update the OpenTelemetry Collector configuration to remote write prometheus metrics to Thanos

It is assumed there is an `otelcol` namespace with the opentelemetrycollector running, and
that `github.com/sallyom/microshift-observability` is cloned in the VM.

#### Update OpenTelemetry Collector in MicroShift with OCP URLs, tokens

```bash
cd microshift-observability/manifests/openshift-observability-hub

# update deployment with client-ca and edge-token configmap volumes
oc apply -f microshift-otel-collector-deployment.yaml 
```

#### Edit microshift-otelcol-config.yaml to match your requirementss

* copy contents of `thanos-receive-url` to `microshift-otelcol-config.yaml` Line #45
* copy contents of `ocp-otelcol-url` to `microshift-otelcol-config.yaml` Line #35

```bash
oc apply -f microshift-otelcol-config.yaml
oc delete pods --all -n otelcol
```

In MicroShift, check the otelcol pod logs to ensure data is being received and exported.

Now you can view traces from the Jaeger UI running in OpenShift, `-n thanos` the `jaeger route`.
With the example from this repository, you should have CRI-O traces and possibly the sample-app
traces. 

You can also query metrics from your application in OpenShift, `-n thanos` the `thanos-querier route`

### Bonus - Import Grafana Dashboard for sample Kepler application

Run this against the **OpenShift hub cluster**

```bash
cd microshift-observability/manifests/openshift-observability-hub/thanos-receiver/dashboard-example-kepler
./deploy-grafana.sh
```

Here is a screenshot of Kepler grafana dashboard in OpenShift showing data from MicroShift edge cluster.

![kepler-dashboard-microshift-in-ocp.png](./kepler-dashboard-microshift-in-ocp.png)
