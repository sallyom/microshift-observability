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

#### Create OpenTelemetry Collector configmaps

Edit `manifests/otel-collector/otelcol-config.yaml` to configure the correct receivers, exporters, and pipelines.
Then apply the configmap yaml files.
This example configures a `prometheusremotewrite` exporter to send data to GrafanaCloud.
View [this Grafana Engineering post](https://grafana.com/blog/2022/05/10/how-to-collect-prometheus-metrics-with-the-opentelemetry-collector-and-grafana/) for more details.

```bash
oc apply -f manifests/otel-collector/cabundle-cm.yaml -n kepler
oc apply -f manifests/otel-collector/otelcol-config.yaml -n kepler
```

#### Patch kepler-exporter service to add otel-collector ports

```bash
oc patch service/kepler-exporter -n kepler --patch-file manifests/otel-collector/kepler-svc-patch.yaml
```

#### Patch kepler-exporter daemonset to add otel-collector container

```bash
oc patch daemonset/kepler-exporter -n kepler --patch-file manifests/otel-collector/kepler-ds-patch.yaml
```

An opentelemetry-collector container should now be running with kepler-exporter daemonset. View the logs of the kepler-exporter pod to
ensure the pod is collecting metrics from the kepler-exporter and sending to opentelemetrycollector.

### Import and view grafana dashboard

Follow the Grafana documentation to import the Kepler-Exporter dashboard.

[Kepler dashboard to import](https://github.com/sustainable-computing-io/kepler/blob/main/grafana-dashboards/Kepler-Exporter.json)

Hopefully, you'll see something like this!

![You might see something like this!](./images/kepler-microshift.png "MicroShift, Kepler, and OpenTelemetry")
