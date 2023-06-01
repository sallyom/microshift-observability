## Kepler on MicroShift in a RHEL based distribution

This assumes MicroShift is installed on a RHEL based machine.
SSH into the virtual machine.

### Execute below commands from within the RHEL machine

Configure cgroups-v2 and install `kernel-devel-$(uname -r)`.
The following script will not work if running in rpm-ostree based OS such as RHEL Device Edge.
With rpm-ostree based systems, be sure your machine is running with cgroupsv2 enabled,
and also that the package `kernel-devel-$(uname -r)` is installed.

```bash
curl -o configure-kepler-vm.sh https://raw.githubusercontent.com/sallyom/microshift-observability/main/manifests/sample-instrumented-applications/kepler/configure-microshift-vm-kepler.sh
./configure-kepler-vm.sh
# script will ask for your RH account creds for subscription if not already registered
# reboot VM and ssh back in
```

#### Start MicroShift service (if not already running)

```bash
sudo systemctl enable --now microshift
mkdir ~/.kube
sudo cp /var/lib/microshift/resources/kubeadmin/kubeconfig ~/.kube/config
sudo chown -R redhat:redhat ~/.kube
oc get pods -A # all pods should soon be running
```

#### Kepler Deployment

Kepler is a research project that that uses eBPF to probe CPU performance counters and Linux kernel tracepoints
to calculate an application's carbon footprint. Refer to [Kepler documentation](https://sustainable-computing.io/) for further information.

> **Note**
> For running in MicroShift on Red Hat Device Edge, I've found it's easiest to use `kustomize` to apply kepler manifests,
> and then an opentelemetry collector pod with `podman` rather than as a pod within MicroShift. This does not require any additional tools
> or operators to be installed. On systems where it's easy to mix K8s and non-K8s workloads, and where resource constraints are an issue,
> this approach works well. On other systems, `helm` and `opentelemetry operator` offer convenience.

```bash
git clone https://github.com/sustainable-computing-io/kepler.git
cd kepler
```

#### Modify Kepler manifests for OpenShift

Uncomment the OpenShift lines in `manifests/config/exporter/kustomization.yaml`
(`Line#3` and `Line#16` at time of this writing),
and remove the `[]` in the line `- patchesStrategicMerge: []`. Then, apply
the kepler manifests.

```bash
oc create ns kepler
oc apply --kustomize $(pwd)/manifests/config/base -n kepler

# patch kepler to run with hostnetwork, for compatibility with podman running opentelemetry collector
curl -o patch.yaml https://raw.githubusercontent.com/sallyom/microshift-observability/main/manifests/sample-instrumented-applications/kepler/patch.yaml
oc patch daemonset kepler-exporter --patch-file patch.yaml
# Check that kepler pod is up and running before proceeding
```

### Configure OpenShift cluster

Refer to [openshift-observability-hub](../../edge-pcp-to-ocp/README.md#hub-openshift-cluster) as an example
to configure an OpenShift cluster to receive telemetry from edge deployments. If you have any endpoint
where it's possible to send OTLP and/or Prometheus data, you can substitute that endpoint for the thanos-receive steps.
What's required is a `prometheusremotewrite` endpoint. Here the `thanos-receive` example mentioned above is being used.
 
#### Ensure OpenShift CA and token are on the edge system

```bash
# scp'd files from OpenShift are expected to be in $HOME on the edge system.
ssh redhat@<RHEL_VM>
ls ~/ca.crt ~/edge-token
```

### Run OpenTelemetry Collector pod (podman)

Download the opentelemetry config file

```bash
curl -o podman-otelconfig.yaml https://raw.githubusercontent.com/sallyom/microshift-observability/main/manifests/sample-instrumented-applications/kepler/podman-otelconfig.yaml
```

Edit [manifests/sample-instrumented-applications/kepler/podman-otelconfig.yaml](./podman-otelconfig.yaml) to suit your needs.
This example also collectos Performance Co-Pilot metrics. Remove that target from the receivers section if not running PCP.

```bash
cd $HOME
# Note the ca.crt & edge-token are assumed to exist at $(pwd)/.

sudo podman run --rm -d --name otelcol-host \
  --security-opt label=disable  \
  --user=0 \
  --cap-add SYS_ADMIN \
  --tmpfs /tmp --tmpfs /run \
  -v /var/log/:/var/log 
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -v $(pwd)/ca.crt:/conf/ca.crt:z \
  -v $(pwd)/edge-token:/conf/edge-token:z \
  -v $(pwd)/podman-otelconfig.yaml:/etc/otelcol-contrib/config.yaml:z\
  --net=host \
  quay.io/sallyom/ubi8-otelcolcontrib:latest --config=file:/etc/otelcol-contrib/config.yaml
```

### Deploy Grafana and the Prometheus DataSource with Kepler Dashboard

You can query metrics from your application in OpenShift, `-n thanos` with the `thanos-querier route`.
However, you might prefer to view the prometheus metrics in Grafana with the upstream
[kepler exporter dashboard](https://github.com/sustainable-computing-io/kepler/blob/main/grafana-dashboards/Kepler-Exporter.json)

To deploy grafana, prometheus, and the dashboard, run this against the **OpenShift cluster**

```bash
cd microshift-observability/manifests/sample-instrumented-applications/kepler/dashboard-example-kepler
./deploy-grafana.sh
```

You should now be able to access Grafana with `username: rhel` and `password:rhel` from the grafana route.

* Navigate to Dashboards -> to find Kepler Exporter dashboard.
* Navigate to Explore -> to find the Prometheus data source to query metrics from.

Hopefully, you'll see something like this!

![You might see something like this!](../../../images/kepler-microshift.png)
