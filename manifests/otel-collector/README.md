#### Deploy OpenTelemetry Collector

This example deploys a central OpenTelemetry Collector to receive OTLP trace and metrics data. From the OpenTelemetry Collector, data can be exported
to remote backends, removing the need to run an expensive monitoring stack on MicroShift.

Edit `manifests/otel-collector/02-otelcol-config.yaml` to configure the correct receivers, exporters, and pipelines.
In this example, the collector is configured to receive OTLP and Prometheus data. Logging and Jaeger exporters are also configured.
An opentelemetry collector deployment will be created in namespace `otelcol`. The Jaeger deployment in this example is running external to the VM
on the host machine. Refer to [the Jaeger deployment document](../jaeger/jaeger.md).

Deploy the OpenTelemetry Collector:

```bash
oc create ns otelcol
oc apply -n otelcol -k manifests/otel-collector/
```

An opentelemetry-collector pod should now be running in `-n otelcol`. View the logs of the opentelemetry collector pod
to ensure data is being received and exported as expected.

##### Configure NetworkPolicies to allow connection to OpenTelemetry Collector

A networkpolicy created in application namespace will allow opentelemetry collector to communicate with the application
For any application, create a networkpolicy to allow OpenTelemetryCollector access to its namespace & services.
You can view an example networkpolicy manifest at manifests/otel-collector/nwpolicy-kepler-example.yaml

#### Send Metrics to remote Prometheus and Grafana

This example configures a `prometheusremotewrite` exporter to send data to GrafanaCloud.
View [this Grafana Engineering post](https://grafana.com/blog/2022/05/10/how-to-collect-prometheus-metrics-with-the-opentelemetry-collector-and-grafana/) for more details.
With the correct API tokens, serviceaccounts, and services, it will be possible to send metrics to Prometheus & Grafana running in OpenShift. Configuration for this will be included
in the near future.

For exporting traces to a remote backend there are two examples, Jaeger and Grafana Agent.

#### Sending OTLP trace data to Jaeger from OpenTelemetry Collector

For this Jaeger is running on the local system external to the virtual machine. With the correct API tokens and serviceaccounts, it will be possible to
send trace data from MicroShift to Jaeger running in OpenShift. Configuration for that scenario will be included in the near future. For this example,
refer to [the Jaeger deployment document](../jaeger/jaeger.md).
