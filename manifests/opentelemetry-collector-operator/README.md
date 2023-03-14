### Deploy OpenTelemetry Collector Operator in MicroShift

Deploy the OpenTelemetry Collector Operator in MicroShift:

```bash
oc apply -n opentelemetry-collector-operator -f manifests/opentelemetry-collector-operator/otelcol-operator.yaml
```

An opentelemetry-collector operator pod should now be running in `-n opentelemetry-collector-operator`.

### Configure OpenShift cluster

Refer to [openshift-observability-hub](../openshift-observability-hub/README.md) and complete the
steps to configure an OpenShift cluster for collecting telemetry from edge deployments.
 
#### Configure Authentication for Thanos Receive

Run the following from `edge MicroShift cluster otelcol namespace`, where OpenTelemetryCollector will be running.

```bash
# scp'd files are at ~/redhat/.
cd
# may need 'oc delete cm/client-ca -n otelcol`, `oc delete cm/edge-token -n otelcol` first
oc create configmap -n otelcol client-ca --from-file ca.crt
oc create configmap -n otelcol edge-token --from-file edge-token
```

Update the OpenTelemetryCollector definition to remote write prometheus metrics to Thanos

It is assumed there is an `otelcol` namespace and the `OpenTelemetry Operator` is running in the cluster.
Also, github.com/sallyom/microshift-observability is cloned in the MicroShift VM.

#### Update OpenTelemetry Collector in MicroShift with OCP URLs, tokens

```bash
# update manifests/opentelemetry-collector-operator/microshift-otelcollector-remotewrite.yaml
* copy contents of `thanos-receive-url` to `microshift-otelcollector-remotewrite.yaml`
* copy contents of `ocp-otelcol-url` to `microshift-otelcollector-remotewrite.yaml`
```

#### Create an OpenTelemetryCollector resource in MicroShift `otelcol` namespace

```bash
# create an SCC for otelcol-collector serviceaccount and the ca-bundle configmap
oc apply -f manifests/opentelemetry-collector-operator/microshift-resources.yaml
oc apply -f manifests/opentelemetry-collector-operator/microshift-otelcollector-remotewrite.yaml
```

Creation of the `OpenTelemetryCollector` in `-n otelcol`, will trigger a collector deployment
and other required resources. Check the collector pod logs to ensure data is being received and exported.

Now you can view traces from the Jaeger UI running in OpenShift, `-n thanos` the `jaeger route`.
With the example from this repository, you should have CRI-O traces and possibly the sample-app
traces. 

You can also query metrics from your application in OpenShift, `-n thanos` the `thanos-querier route`

#### Create an OpenTelemetryCollector resource in MicroShift `sample-app` namespace

```bash
# scp'd files are at ~/redhat/.
cd
# may need 'oc delete cm/client-ca -n sample-app`, `oc delete cm/edge-token -n sample-app` first
oc create configmap -n sample-app client-ca --from-file ca.crt
oc create configmap -n sample-app edge-token --from-file edge-token
oc apply -f manifests/opentelemetry-collector-operator/sample-app-otelcollector-remotewrite.yaml
```

Creation of the `OpenTelemetryCollector` in `-n sample-app`, will trigger a collector deployment
and other required resources. Check the collector pod logs to ensure data is being received and exported.
