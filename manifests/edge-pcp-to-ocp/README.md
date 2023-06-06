## Send PCP metrics from RHEL machine to OpenShift

Performance Co-Pilot (PCP) data from any RHEL system can be directed to OpenShift (OCP) eliminating the need for prometheus at the edge.
Metrics are sent from OpenTelemetry Collector running in a podman container using the `prometheusremotewrite` exporter to `thanos receiver` in the OCP cluster.

### Hub OpenShift cluster

#### Deploy Thanos Receive in OpenShift

For this example, we will use Thanos. A `Thanos Operator` as well as the `Observability Operator` are available in OperatorHub with
any OpenShift installation. However, for this example,
refer to [OpenShift with Thanos-Receive](../openshift-thanos-receive.md) to enable a simple Prometheus remote-write
endpoint with `thanos-receive`.

You can substitute `thanos-receive` for any endpoint where it's possible to send OTLP and/or Prometheus data.
What's required is a `prometheusremotewrite` endpoint or an `OTLP` receiver endpoint.
 
#### Ensure OpenShift CA and token are on the edge system

```bash
# scp'd files from OpenShift are expected to be in $HOME on the edge system.

ssh redhat@<RHEL_VM>
ls ~/ca.crt ~/edge-token ~/thanos-receive-url
```

### RHEL machine

#### Update OpenTelemetry Collector config with OCP URLs, tokens

```bash
wget https://raw.githubusercontent.com/sallyom/microshift-observability/main/manifests/edge-pcp-to-ocp/otelcol-config.yaml
```

Now copy contents of `thanos-receive-url` to [otelcol-config.yaml](./otelcol-config.yaml) Line #24

#### Run OpenTelemetry Collector with podman

```bash
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
  -v $(pwd)/otelcol-config.yaml:/etc/otelcol-contrib/config.yaml:z\
  -v $(pwd)/otc:/otc:z  \
  --net=host \
  quay.io/sallyom/ubi8-otelcolcontrib:latest --config=file:/etc/otelcol-contrib/config.yaml
```

#### Deploy Grafana and the Prometheus DataSource with PCP Prometheus Host Overview Dashboard

You can query metrics from your application in OpenShift, `-n thanos` with the `thanos-querier route`.
However, you might prefer to view the prometheus metrics in Grafana.

Run this against the **OpenShift hub cluster**

```bash
cd microshift-observability/manifests/edge-pcp-to-ocp/thanos-receiver/dashboard-pcp-prometheus
./deploy-grafana.sh
```

You should now be able to access Grafana with `username: rhel` and `password:rhel` from the grafana route.

* Navigate to Dashboards -> to find the PCP Prometheus Host Overview dashboard.
* Navigate to Explore -> to find the Prometheus data source to query metrics from.

Here is a screenshot of PCP Prometheus Host Overview Grafana dashboard

![pcp-in-ocp.png](../../images/PCP.png)
