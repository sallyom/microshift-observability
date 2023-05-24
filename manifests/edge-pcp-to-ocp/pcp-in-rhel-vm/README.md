## Setting up Performance Co-Pilot in RHEL Device Edge

### Performance Co-Pilot in RHEL Device Edge

To launch a RHEL edge machine [this blog](https://cloud.redhat.com/blog/meet-red-hat-device-edge-with-microshift) was followed.
The [rhde-microshift.toml](./rhde-microshift.toml) includes the packages required to run
[Performance Co-Pilot with graphical representation](https://github.com/performancecopilot/grafana-pcp).
The [Red Hat Customer Portal](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/setting-up-graphical-representation-of-pcp-metrics_monitoring-and-managing-system-status-and-performance) documentation was used to deploy PCP. PCP data is visualized with Grafana running in OpenShift. An OpenTelemetry Collector pod enables the collection. 

PMCD, PMLogger, and PMProxy are run as systemd services. These services are included in the RHEL device edge machine image.
Below is the output of the services running.

```bash
sudo systemctl --type=service --state=running
----
pmcd.service             loaded active running Performance Metrics Collector Daemon
pmie.service             loaded active running Performance Metrics Inference Engine
pmie_farm.service        loaded active running pmie farm service
pmlogger.service         loaded active running Performance Metrics Archive Logger
pmlogger_farm.service    loaded active running pmlogger farm service
pmproxy.service          loaded active running Proxy for Performance Metrics Collector Daemon
---
```

On the edge device, an OpenTelemetryCollector pod can scrape PCP metrics and push the data to OpenShift.

Refer to [PCP to OpenShift document](../README.md) for the OpenShift and OpenTelemetry Collector configuration.
