## Kepler on MicroShift local VM to GrafanaCloud

### MicroShift deployment in KVM

Follow the Microshift documentation for bootstrapping a MicroShift instance running in a RHEL 8.7 Virtual Machine. Complete all prerequisites.
[Red Hat Enterprise Linux 8.7 virtual machine Getting Started with MicroShift](https://github.com/openshift/microshift/blob/main/docs/getting_started.md)

### Bootstrap MicroShift

[Bootstrap command from MicroShift documentation](https://raw.githubusercontent.com/openshift/microshift/main/docs/getting_started.md)

This command creates a `microshift-starter` virtual machine with 4 CPU cores, 6GB RAM and 50GB storage.

```bash
VMNAME=microshift-starter
DVDISO=/var/lib/libvirt/images/rhel-8.7-x86_64-dvd.iso
KICKSTART=https://raw.githubusercontent.com/openshift/microshift/main/docs/config/microshift-starter.ks

sudo -b bash -c " \
cd /var/lib/libvirt/images && \
virt-install \
    --name ${VMNAME} \
    --vcpus 4 \
    --memory 6144 \
    --disk path=./${VMNAME}.qcow2,size=50 \
    --network network=default,model=virtio \
    --events on_reboot=restart \
    --location ${DVDISO} \
    --extra-args \"inst.ks=${KICKSTART}\" \
"
```

To configure the machine, follow the below steps.
Use the IP address and `redhat:redhat` to access the virtual machine.
First, scp the pull-secret (follow above documentation) and the configure script over to the VM.
Then, ssh into the virtual machine.

```bash
sudo virsh domifaddr microshift-starter # note the IP address 
export IP_ADDR=<ip address from above>
# password is 'redhat' for below cmds
scp ./configure-microshift-vm.sh  redhat@${IPADDR}:
scp ~/.pull-secret.json redhat@${IPADDR}:
ssh redhat@${IPADDR}
```

### Execute below commands from within the virtual machine

Configure cgroups-v2 and run the configuration script.

```bash
./configure-microshift-vm.sh ~/.pull-secret.json
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
      hostNetwork: true
      containers:
      - name: kepler-exporter
and
        env:
        - name: NODE_NAME
          value: localhost
```

Apply the kepler manifests.

```bash
oc apply --kustomize $(pwd)/manifests/openshift/kepler
# Check that kepler pod is up and running before proceeding
```

#### Deploy OpenTelemetry Operator and Cert-Manager

> Note: Neither OpenTelemetry Operator nor Cert-Manager are required. It is possible to deploy a standalone OpenTelemetryCollector deployment. If running in resource constrained environment, a standalone collector deployment + service + configmap  would be a lighter solution. Also, with MicroShift the OpenTelemetry Operator does not require Cert-Manager, since the `service-ca` deployment handles TLS certificates. The default OpenTelemetry Operator manifests expect cert-manager and that is the only reason it is deployed here, out of ~laziness/not wanting to update otel manifests~ convenience.

```bash
# OpenTelemetry Operator manifests depend on cert-manager
# https://cert-manager.io/docs/installation/#default-static-install
oc apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.yaml

oc apply -f $(pwd)/manifests/opentelemetry-operator.yaml
```

#### Create OpenTelemetryCollector in kepler namespace

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

Hopefully, you'll see something like this!

![You might see something like this!](./images/kepler-microshift.png "MicroShift, Kepler, and OpenTelemetry")
