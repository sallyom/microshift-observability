### Send Telemetry from MicroShift to OpenShift

#### Commands for OpenShift cluster

```bash
oc create ns monitoring
oc create -f manifests/openshift-observability-hub/enable-user-monitoring.yaml
```

Install `OpenTelemetry Operator` and `Jaeger Operator` from OperatorHub

*update the OpenTelemetryCollector deployment with a community image that accepts BasicAuth (for this example only)*

```bash
oc apply -f manifests/openshift-observability-hub/jaeger.yaml
oc apply -f manifests/openshift-observability-hub/ocp-otelcol.yaml

# Before scaling operator down, be sure there is a deployment of opentelemetry collector - it will have an error
# The error is because the released image version does not include a `BasicAuth` extension. For this example, BasicAuth
# is used because there is a bug with `BearerTokenAuth` extension.
oc scale --replicas=0 deployment/opentelemetry-operator-controller-manager -n openshift-operators

# Now you can update the deployment with a new image that accepts the BasicAuth extension
oc edit deployment otelcol-collector -n monitoring
# replace Image with Image: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.63.1

oc apply -f manifests/openshift-observability-hub/ocp-route.yaml
# extract the root CA to scp to MicroShift
oc extract cm/kube-root-ca.crt -n openshift-config --confirm
scp ca.crt   redhat@<MICROSHIFT_VM>:
```

#### Commands for MicroShift cluster

It is assumed there is an `otelcol` namespace with the opentelemetrycollector running
and `ca.crt` from the OpenShift cluster is copied here.

```bash
# may need 'oc delete cm/client-ca -n otelcol` first
oc create configmap -n otelcol client-ca --from-file ca.crt

# edit microshift-otelcol-config.yaml to match your requirementss
oc apply -f manifests/openshift-observability-hub/microshift-otelcol-config.yaml
oc delete pods --all -n otelcol
```

Now you can view traces from the Jaeger UI running in OpenShift, `-n monitoring`.
View logs of otelcol-collector pod in both clusters to confirm data is being collected.
With the example from this repository, you should have CRI-O traces and possibly the sample-app
traces. 

