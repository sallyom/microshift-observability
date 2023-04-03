## Setting up Performance Co-Pilot in RHEL Device Edge

### Screenshots

Data from RHEL Device Edge and [Performance Co-Pilot](https://pcp.io/) (PCP)

![PCP Redis: Host Overview Dashboard](../images/PCP.png)

![PCP Vector: Host Overview](../images/PCP-vector.png)


### Performance Co-Pilot in RHEL Device Edge

To launch a RHEL edge machine [this blog](https://cloud.redhat.com/blog/meet-red-hat-device-edge-with-microshift) was followed.
The [rhde-microshift.toml](./rhde-microshift.toml) includes the packages required to run
[Performance Co-Pilot with graphical representation](https://github.com/performancecopilot/grafana-pcp).
The [Red Hat Customer Portal](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/setting-up-graphical-representation-of-pcp-metrics_monitoring-and-managing-system-status-and-performance) documentation was used to deploy PCP
and grafana.

Grafana is running in a podman container rather than systemd service. This podman command was used to deploy grafana.

```bash
sudo podman run -d \
  -e GF_INSTALL_PLUGINS="https://github.com/performancecopilot/grafana-pcp/releases/download/v5.0.0/performancecopilot-pcp-app-5.0.0.zip;performancecopilot-pcp-app" \
  -p 3000:3000 \
  docker.io/grafana/grafana
```

Redis and PMProxy are run as systemd services. These services are included in the RHEL device edge machine image.
