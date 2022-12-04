#### Create Grafana Agent traces exporter

A grafana agent can be deployed to send trace data to Grafana Cloud.
Edit `manifests/grafana-agent/grafana-agent-config.yaml` to configure a grafana agent.
Then create a namespace to deploy the grafana agent apply the yaml files.
This example configures a grafana agent to send trace data to GrafanaCloud Tempo Data Source.
View [Grafana Agent in K8s documentation](https://grafana.com/docs/grafana-cloud/kubernetes-monitoring/how-to/k8s-agent/k8s-agent-traces/) for more details.

```bash
oc create namespace grafana
oc apply -f manifests/grafana-agent/grafana-agent-config.yaml

# manifest from [grafana agent repository](https://raw.githubusercontent.com/grafana/agent/v0.27.0/production/kubernetes/agent-traces.yaml) has been modified
# to run in MicroShift hostNetwork
oc apply -f manifests/grafana-agent/scc.yaml
oc apply -f manifests/grafana-agent/clusterrole.yaml
oc apply -f manifests/grafana-agent/deployment.yaml
```
