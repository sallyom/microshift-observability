## Kepler on MicroShift local VM to GrafanaCloud

This assumes MicroShift is running in a virtual machine.
SCP the configure script over to the VM.
Then, ssh into the virtual machine.

```bash
sudo virsh domifaddr microshift-starter # note the IP address 
export IP_ADDR=<ip address from above>
# password is 'redhat' for below cmds
scp ./configure-microshift-vm-kepler.sh  redhat@${IPADDR}:
ssh redhat@${IPADDR}
```

### Execute below commands from within the virtual machine

Configure cgroups-v2 and run the configuration script.

```bash
./configure-microshift-vm-kepler.sh ~/.pull-secret.json cgroupsv2=true
# script will ask for your RH account creds for subscription, then will run unattended
# reboot VM and ssh back in
```

#### Start MicroShift service

```bash
sudo systemctl enable --now microshift
mkdir ~/.kube
sudo cp /var/lib/microshift/resources/kubeadmin/kubeconfig ~/.kube/config
sudo chown -R redhat:redhat ~/.kube
oc get pods -A # all pods should soon be running
```

#### Kepler Deployment

```bash
git clone https://github.com/sustainable-computing-io/kepler.git
cd kepler
```

Edit the daemonset yaml at `manifests/openshift/kepler/01-kepler-install.yaml` like so.

```bash
        env:
        - name: NODE_NAME
          value: <VM IP_ADDRESS>
```

Apply the kepler manifests.

```bash
oc apply --kustomize $(pwd)/manifests/openshift/kepler
# Check that kepler pod is up and running before proceeding
```

#### Create OpenTelemetry Collector

(cd back to this repository)
Edit `manifests/otel-collector/02-otelcol-config.yaml` to configure the correct receivers, exporters, and pipelines.
Then apply the configmap yaml files.
This example configures a `prometheusremotewrite` exporter to send data to GrafanaCloud.
View [this Grafana Engineering post](https://grafana.com/blog/2022/05/10/how-to-collect-prometheus-metrics-with-the-opentelemetry-collector-and-grafana/) for more details.

```bash
# A networkpolicy created in kepler ns will allow opentelemetry collector to communicate with kepler-exporter
oc create -f manifests/sample-app/kepler/networkpolicy.yaml
oc create ns otelcol
oc apply -n otelcol -k manifests/otel-collector/
```

An opentelemetry-collector pod should now be running in `-n otelcol`. View the logs of the kepler-exporter pod to
ensure kepler metrics are being exported from the kepler-exporter. View the logs of the opentelemetry collector pod
to ensure metrics are being collected from kepler-exporter.

### Import and view grafana dashboard

Follow the Grafana documentation to import the Kepler-Exporter dashboard.

[Kepler dashboard to import](https://github.com/sustainable-computing-io/kepler/blob/main/grafana-dashboards/Kepler-Exporter.json)

Hopefully, you'll see something like this!

![You might see something like this!](./images/kepler-microshift.png "MicroShift, Kepler, and OpenTelemetry")
