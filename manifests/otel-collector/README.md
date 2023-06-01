### Deploy OpenTelemetry Collector

This example deploys a central OpenTelemetry Collector to receive OTLP trace and metrics data. From the OpenTelemetry Collector, data can be exported
to remote backends, removing the need to run an expensive monitoring stack on MicroShift.


Edit [the OpenTelemetry Collector config file](02-otelcol-config.yaml) to configure the correct receivers, exporters, and pipelines.
In this example, the collector is configured to receive OTLP and Prometheus data. Logging and Jaeger exporters are also configured.
An opentelemetry collector deployment will be created in namespace `otelcol`. The Jaeger deployment in this example is running external to the VM
on the host machine. Refer to [the Jaeger deployment document](../jaeger/jaeger.md).

Deploy the OpenTelemetry Collector in MicroShift:

```bash
oc create ns otelcol
oc apply -n otelcol -k manifests/otel-collector/
```

An opentelemetry-collector pod should now be running in `-n otelcol`. View the logs of the opentelemetry collector pod
to ensure data is being received and exported as expected.
