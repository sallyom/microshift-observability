## Send Telemetry from MicroShift to OpenShift

Telemetry data from MicroShift can be directed to OpenShift (OCP) eliminating the need for prometheus in MicroShift.
Metrics are sent from MicroShift OpenTelemetry Collector using the `prometheusremotewrite` exporter to `thanos receiver` in the OCP cluster.
Traces are sent from MicroShift OpenTelemetry Collector to OCP OpentelemetryCollector and then to OCP Jaeger.


### Hub OpenShift cluster

Install `OpenTelemetry Operator` and `Jaeger Operator` from OperatorHub. Then deploy Thanos receiver outlined below.

#### Deploy Thanos Receive in OpenShift

For this example, we will use Thanos. A `Thanos Operator` as well as the `Observability Operator` are available in OperatorHub with
any OpenShift installation. However, for this example,
refer to [OpenShift with Thanos-Receive](../openshift-thanos-receive.md) to enable a simple Prometheus remote-write
endpoint with `thanos-receive`.

You can substitute `thanos-receive` for any endpoint where it's possible to send OTLP and/or Prometheus data.
What's required is a `prometheusremotewrite` endpoint or an `OTLP` receiver endpoint.
 
#### Deploy Jaeger and OpenTelemetry Collector in OpenShift

```bash
cd manifests/openshift-observability-hub

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

#### Copy OCP OpenTelemetry Collector URL to $HOME on MicroShift system for otlphttp exporter

```
oc -n thanos get route otelcol -o jsonpath='{.status.ingress[*].host}' > ocp-otelcol-url
scp ocp-otelcol-url redhat@<MICROSHIFT_VM>:
```

### Edge MicroShift cluster

If running a standalone deployment of the OpenTelemetry Collector in MicroShift,
follow the below steps in the MicroShift machine. If running the
`OpenTelemetry Operator` in MicroShift, follow the steps in the
[opentelemetry-collector-operator](../opentelemetry-collector-operator/README.md) document.

#### Ensure OpenShift CA, token, urls are on the edge system

```bash
# scp'd files from OpenShift are expected to be in $HOME on the edge system.

ssh redhat@<RHEL_VM>
ls ~/ca.crt ~/edge-token ~/thanos-receive-url ~/ocp-otelcol-url
```

#### Configure Authentication for Thanos Receive

Run the following from `edge/MicroShift cluster and the otelcol namespace`, where OpenTelemetryCollector is running & collecting data

```bash
# scp'd files are at $HOME
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

# update collector deployment with client-ca and edge-token configmap volumes
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
