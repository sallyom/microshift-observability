### Hub OpenShift cluster

Deploy Thanos receiver outlined below.

#### Deploy Thanos Receive

Refer to [federated prometheus blog](https://cloud.redhat.com/blog/federated-prometheus-with-thanos-receive)
and also [thanos-receive OpenShift demo](https://github.com/rhthsa/openshift-demo/blob/main/thanos-receive.md)

For this example, thanos-store-gateway is not deployed. Refer to the blogs above to configure thanos storage for HA.

```bash
cd thanos-receiver
oc create ns thanos
oc apply -f thanos-scc.yaml

# If adding thanos-store-gateway run below command
#oc -n thanos create secret generic store-s3-credentials --from-file=store-s3-secret.yaml
#oc -n thanos create thanos-store-gateway-sa.yaml
#oc -n thanos adm policy add-scc-to-user anyuid -z thanos-store-gateway

# create thanos-receive, edge, and thanos-querier serviceaccounts and policies
oc -n thanos create -f sa.yaml
oc -n thanos adm policy add-cluster-role-to-user system:auth-delegator -z thanos-receive
oc -n thanos annotate serviceaccount thanos-receive serviceaccounts.openshift.io/oauth-redirectreference.thanos-receive='{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"thanos-receive"}}'
oc -n thanos annotate serviceaccount thanos-querier serviceaccounts.openshift.io/oauth-redirectreference.thanos-querier='{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"thanos-querier"}}'

# create serviceaccount tokens
oc -n thanos create -f thanos-sa-token-secrets.yaml 

# If adding thanos-store-gateway run below commands
# create thanos store gateway
# oc -n thanos create -f store-gateway.yaml
# oc -n thanos get pods -l "app=thanos-store-gateway"

# create thanos receiver
oc -n thanos create secret generic thanos-receive-proxy --from-literal=session_secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c43)
oc -n thanos apply -f thanos-receive.yaml
oc -n thanos create route reencrypt thanos-receive --service=thanos-receive --port=web-proxy --insecure-policy=Redirect

# create thanos querier
oc -n thanos create secret generic thanos-querier-proxy --from-literal=session_secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c43)
oc -n thanos create -f thanos-querier-thanos-receive.yaml
oc -n thanos create route reencrypt thanos-querier --service=thanos-querier --port=web-proxy --insecure-policy=Redirect

# scp thanos-receive serviceaccount token to RHEL machine
oc -n thanos create token thanos-receive --duration 999999h > edge-token
scp edge-token user@<RHEL_MACHINE>:

```

#### Find Thanos Receive URL, scp to RHEL machine for prometheusremotewrite exporter

```
oc -n thanos get route thanos-receive -o jsonpath='{.status.ingress[*].host}' > thanos-receive-url
scp thanos-receive-url user@<RHEL_VM>:
```
#### Extract root CA and SCP to RHEL machine

```bash
oc extract cm/kube-root-ca.crt -n openshift-config
scp ca.crt  user@<RHEL_VM>:
```

**OpenShift is now ready to receive metrics from anywhere that can remote-write Prometheus metrics**

