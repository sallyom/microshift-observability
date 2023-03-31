#### Sample Application to generate OTLP metrics,traces,logs

```bash
cd /checkout/of/microshift-observability
oc create ns generate-data
```

Create OpenShift ca.crt and serviceaccount token configmaps. This assumes
the files `ca.crt`, `edge-token`, `thanos-receive-url`, and `ocp-otelcol-url`
have been scp'd to Microshift VM. For more on that, refer to
[openshift-observability-hub](../../openshift-observability-hub/README.md).

```bash
# may need 'oc delete cm/client-ca -n generate-data`, `oc delete cm/edge-token -n generate-data` first
oc create configmap -n generate-data client-ca --from-file ca.crt
oc create configmap -n generate-data edge-token --from-file edge-token
```

Edit generate-data-otelcol.yaml with urls

- copy contents of `~/ocp-otelcol-url` to `generate-data-otelcol.yaml` Line #35

```bash
oc apply -n generate-data -f deployment.yaml
oc apply -n generate-data -f generate-data-otelcol-config.yaml
oc get pods -n generate-data # look for running otelcollector pod
oc port-forward svc/generate-data 9999:8080 -n generate-data &
```

Exit VM and SSH port 8888 from rhel-edge VM to localhost:8888

```bash
ssh -L 8888:public-ip:8080 redhat@public-ip -N
```

Open `localhost:8888` from local browser to generate data. You should see "Hello World!"

You should now see traces from generate-data in the OpenShift cluster `-n thanos` and the `Jaeger` route.
