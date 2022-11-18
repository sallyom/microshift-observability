## Deploying Kepler on MicroShift (in KVM) and export to GrafanaCloud

### MicroShift deployment in KVM

Follow the Microshift documentation for bootstrapping a MicroShift instance running in a RHEL 8.7 Virtual Machine.
[Red Hat Enterprise Linux 8.7 virtual machine with MicroShift](https://github.com/openshift/microshift/blob/main/docs/devenv_rhel8_auto.md)

Only follow the above documentation to start the machine. To configure the machine, follow the below steps.
Once the virtual machine is running, use the IP address and `microshift:microshift` to ssh into the virtual machine.
Also, scp the pull-secret (follow above documentation) and the configure script over to the VM.

```bash
sudo virsh domifaddr microshift-dev # note the IP address 
export IP_ADDR=<ip address from above>
# password is 'microshift' for below cmds
scp ./configure-microshift-vm.sh  microshift@${IPADDR}:
scp ~/.pull-secret.json microshift@${IPADDR}:
ssh microshift@${IPADDR}
```

## Execute below commands from within the virtual machine

Configure cgroups-v2 and run the configuration script.

```bash
./configure-microshift-vm.sh ~/.pull-secret.json
# script will ask for your RH account creds for subscription, then will run unattended
# reboot VM and ssh back in
```

Now enable and start crio and microshift services

```bash
sudo systemctl enable crio
sudo systemctl enable --now microshift
mkdir ~/.kube
sudo cp /var/lib/microshift/resources/kubeadmin/kubeconfig ~/.kube/config
sudo chown -R microshift:microshift ~/.kube
oc get pods -A # all pods should soon be running
# clean up configuration data no longer needed
echo 1 | /usr/bin/cleanup-all-microshift-data
```

### Kepler Deployment

```bash
git clone https://github.com/sustainable-computing-io/kepler.git
cd kepler
oc apply --kustomize $(pwd)/manifests/openshift/kepler
# Check that kepler pod is up and running before proceeding
```

### Deploy OpenTelemetry Operator and Cert-Manager

```bash
# OpenTelemetryOperator depends on cert-manager running
# https://cert-manager.io/docs/installation/#default-static-install
oc apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.yaml

oc apply -f $(pwd)/manifests/opentelemetry-operator.yaml
```

### Create OpenTelemetryCollector in kepler namespace

Trigger the deployment of an opentelemetry-collector pod in the kepler namespace.

Edit `manifests/otelcol.yaml` to configure the correct prometheus exporter. This example
configures a `prometheusremotewrite` exporter to send data to GrafanaCloud.
View [this Grafana Engineering post](https://grafana.com/blog/2022/05/10/how-to-collect-prometheus-metrics-with-the-opentelemetry-collector-and-grafana/) for more details.

```bash
oc apply -f $(pwd)/manifests/otelcol.yaml
```

An opentelemetry-collector deployment will be triggered by the creation of the OpenTelemetryCollector resource. View the logs of the opentelemetry-collector pod to
ensure the pod is collecting metrics from the kepler-exporter.
Follow the Grafana documentation to import the Kepler-Exporter dashboard.

[Kepler dashboard to import](https://github.com/sustainable-computing-io/kepler/blob/main/grafana-dashboards/Kepler-Exporter.json)
