### Deploy Jaeger to collect & visualize trace data

If you have an application running in MicroShift VM exporting OTLP trace spans, you can collect and visualize the traces by deploying a jaeger container on the host system via podman. 

#### Run jaeger in container on local system

```bash
# Run jaeger image on local system
podman run -d --name jaeger   -p 16686:16686   -p 14250:14250   jaegertracing/all-in-one:latest
```

#### Forward port 14250 on local system to MicroShift VM

```
ssh -R 14250:localhost:14250 redhat@<MicroShift VM IP> -N
```

#### If you don't have an application instrumented to export traces, you can configure CRI-O to export traces!

##### Enable CRI-O tracing by adding a crio.conf.d file

```bash
sudo su
mkdir /etc/crio/crio.conf.d
cat <<EOF > /etc/crio/crio.conf.d/otel.conf
[crio.tracing]
tracing_sampling_rate_per_million=999999
enable_tracing=true
EOF
```

#### Restart cri-o service

```bash
systemctl daemon-reload
systemctl restart crio # or systemctl enable crio --now
systemctl status crio # should be running
```

You might also deploy the [sample application](../sample-app/README.md). The sample application is instrumented to generate
OTLP trace data.
CRI-O and the sample-app are now exporting trace data to Jaeger running on the local machine.
You should now see spans in the jaeger dashboard at `localhost:16686`,
provided you have deployed and configured OpenTelemetry Collector to receive OTLP data from the application service (in this example I have also configured CRI-O to export trace data,
and OpenTelemetry Collector is running with `hostNetwork:true`) and provided the OpenTelemetry Collector is configured to export to Jaeger. 
