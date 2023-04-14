## Kepler on MicroShift in a RHEL based distribution

This assumes MicroShift is installed in a RHEL based machine
and the OpenTelemetry Operator is deployed.
SSH into the virtual machine.

Configure MicroShift and Kepler

```bash
# If running in KVM, or obtain the ip address otherwise
sudo virsh domifaddr microshift-starter # note the IP address 
export IP_ADDR=<ip address from above>
# password is 'redhat' for below cmds
scp ./configure-microshift-vm-kepler.sh  redhat@${IPADDR}:
ssh redhat@${IPADDR}
```

### Execute below commands from within the virtual machine

Configure cgroups-v2 and run the configuration script.
The following script will not work if running in rpm-ostree based OS such as RHEL Device Edge.
With rpm-ostree based systems, be sure your machine is running with cgroupsv2 enabled,
and also that the package `kernel-devel-$(uname -r)` is installed.

```bash
./configure-microshift-vm-kepler.sh ~/.pull-secret.json cgroupsv2=true
# script will ask for your RH account creds for subscription, then will run unattended
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
to calculate an application’s carbon footprint. Refer to [Kepler documentation](https://sustainable-computing.io/) for further information.

```bash
git clone https://github.com/sustainable-computing-io/kepler.git
cd kepler
```

#### Modify Kepler manifests for OpenShift

Uncomment the OpenShift lines in `manifests/config/exporter/kustomization.yaml`,
and remove the `[]` in the line `- patchesStrategicMerge: []`. Then, apply
the kepler manifests.

#### Modify Daemonset to Deployment

In `kepler/manifests/config/exporter/exporter.yaml` and
`kepler/manifests/config/exporter/patch/patch-openshift.yaml` edit `Daemonset` to `Deployment`.
This is because the OpenTelemetryCollector sidecar mode will not work with a DaemonSet,
and since MicroShift doesn't support multi-node deployments, a Deployment makes as much
sense as a Daemonset.

```bash
oc create ns kepler
oc apply --kustomize $(pwd)/manifests/config/base -n kepler
# Check that kepler pod is up and running before proceeding
```

#### Create OpenTelemetry Collector

(cd back to this repository)
Edit [manifests/sample-instrumented-applications/kepler/microshift-otelcollector.yaml](./microshift-otelcollector.yaml) to configure the correct receivers, exporters, and pipelines.

```bash
oc apply -n kepler -f manifests/sample-instrumented-applications/kepler/microshift-otelcollector.yaml
oc get pods -n kepler
# an opentelemetry collector sidecar container should be triggered and a pod should be running.
# examine the collector pod logs from `-c otc-container` to verify data is being received and
exported from kepler-exporter
```

View [this Grafana Engineering post](https://grafana.com/blog/2022/05/10/how-to-collect-prometheus-metrics-with-the-opentelemetry-collector-and-grafana/) for details on how to send data to Grafana Cloud.

### Import and view grafana dashboard

Follow the Grafana documentation to import the Kepler-Exporter dashboard.

[Kepler dashboard to import](https://github.com/sustainable-computing-io/kepler/blob/main/grafana-dashboards/Kepler-Exporter.json)

Hopefully, you'll see something like this!

![You might see something like this!](../../../images/kepler-microshift.png "MicroShift, Kepler, and OpenTelemetry")
