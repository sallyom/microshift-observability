## Observability in MicroShift

| :exclamation:  This repo is no longer maintained. Please instead view the contents at `https://github.com/redhat-et/edge-ocp-observability`   |
|-----------------------------------------------------------------------------------------------------------------------------------------------|

This repository is no longer maintained. The contents are now maintained at `https://github.com/redhat-et/edge-ocp-observability
This repository is a collection of manifests to enable observability in MicroShift. To get started, follow this README to deploy a VM and MicroShift.
Then, view the following observability scenarios:

1. [Kubernetes Metrics Server on MicroShift](manifests/metrics-server/README.md)
5. [Send Telemetry to OpenShift Cluster](manifests/openshift-observability-hub/README.md)
2. [OpenTelemetry Operator & Collector](manifests/opentelemetry-collector-operator/README.md)
3. [MicroShift Kepler Deployment with OpenShift Monitoring Stack](manifests/sample-instrumented-applications/kepler/README.md)
2. [Performance CoPilot in RHEL Device Edge](./manifests/edge-pcp-to-ocp/README.md)
3. [Sample Application with Traces](manifests/sample-instrumented-applications/sample-tracing-app/README.md)
4. [Jaeger Deployment](manifests/jaeger/jaeger.md)
2. [OpenTelemetry Collector No Operator](manifests/otel-collector/README.md)

### Bootstrap MicroShift

Refer to the [MicroShift Documentation](https://access.redhat.com/documentation/en-us/red_hat_build_of_microshift/4.13/html/installing/microshift-install-rpm#installing-microshift-from-rpm-package_microshift-install-rpm)
to install MicroShift.

[This repository](https://github.com/sallyom/edge-imagebuild) includes notes and documentation to compose a RH Device Edge iso with MicroShift enabled.

#### Start MicroShift service

```bash
sudo systemctl enable --now microshift
mkdir ~/.kube
sudo cp /var/lib/microshift/resources/kubeadmin/kubeconfig ~/.kube/config
sudo chown -R redhat:redhat ~/.kube
oc get pods -A # all pods should soon be running
```

### CPU/Memory from kube-metrics-server

`kubectl top pods -A`

![Utilization](images/top-pods.png)

### Screenshots

Data sent from local MicroShift virtual machine to OpenShift grafana

![Kepler Dashboard](images/kepler-dashboard-microshift-in-ocp.png)

Prometheus metrics from MicroShift virtual machine 

![MicroShift metrics](images/microshift-metrics.png)

Jaeger UI from OpenShift showing traces from MicroShift VM

![Jaeger traces exported from virtual machine](images/localjaeger.png)

