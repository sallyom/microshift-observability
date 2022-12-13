#### Sample Application to generate OTLP trace data

This simple webserver serves /hello and /count
Because Jaeger is running on the host network to also collect from CRI-O, this sample-app must also have access
to the host network, in order to export to Jaeger.

```bash
oc create ns sample-app
oc apply -f manifests/sample-instrumented-applications/sample-tracing-app/scc.yaml
oc apply -n sample-app -f manifests/sample-instrumented-applications/sample-tracing-app/sample-app.yaml
```

Exit the VM and forward port 8080 from sample-app to localhost:8888 on host machine.

```bash
ssh -L 8888:<MicroShift VM IP>:8080 redhat@<MicroShift VM IP>
```

Then generate spans by visiting `https://localhost:8888/hello`, `https://localhost:8888/count`.


To view the traces, deploy an [OpenTelemetry Collector](../../otel-collector/README.md) and either a [Grafana Agent](../../grafana-agent/README.md)
or [Jaeger](../../jaeger/jaeger.md).
