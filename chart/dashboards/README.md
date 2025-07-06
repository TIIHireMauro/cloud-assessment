# 📊 Grafana Dashboards

This directory contains JSON dashboards for Grafana that are automatically loaded via provisioning.

## 📁 Structure

```
dashboards/
├── README.md              # This file
└── iot-dashboard.json     # Main dashboard for IoT Data Collector
```

## 🔧 How It Works

The Helm Chart uses the `.Files.Get` function to include the JSON file content in the `grafana-dashboards` ConfigMap. This allows:

1. **Separation of concerns**: The dashboard JSON remains independent of Kubernetes configuration
2. **Easy maintenance**: Editing the dashboard doesn't require modifying YAML templates
3. **Reusability**: The same dashboard can be used in different environments
4. **Versioning**: Dashboard changes are tracked in Git

## 📝 How to Add New Dashboards

1. Create a new JSON file in the `dashboards/` directory
2. Add the reference in `chart/templates/grafana-dashboards.yaml`:

```yaml
data:
  dashboard.yml: |
    apiVersion: 1
    providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        updateIntervalSeconds: 10
        allowUiUpdates: true
        options:
          path: /etc/grafana/provisioning/dashboards
  iot-dashboard.json: |
{{ .Files.Get "dashboards/iot-dashboard.json" | indent 4 }}
  new-dashboard.json: |
{{ .Files.Get "dashboards/new-dashboard.json" | indent 4 }}
```

## 🎨 IoT Data Collector Dashboard

The `iot-dashboard.json` includes the following panels:

1. **MQTT Messages Rate** - MQTT messages per second rate
2. **Total MQTT Messages** - Total MQTT messages received
3. **Database Writes** - Database writes rate
4. **HTTP Requests** - HTTP requests rate
5. **MQTT Messages Over Time** - Temporal graph of MQTT messages

### Used Metrics

- `mqtt_messages_total` - Total MQTT messages counter
- `db_writes_total` - Total database writes counter
- `http_requests_total` - Total HTTP requests counter

## 🔍 Troubleshooting

If the dashboard doesn't load automatically:

1. Check if the JSON file is valid:
   ```bash
   cat chart/dashboards/iot-dashboard.json | jq .
   ```

2. Check if the ConfigMap was created:
   ```bash
   kubectl get configmap grafana-dashboards -o yaml
   ```

3. Check Grafana logs:
   ```bash
   kubectl logs -f deployment/grafana
   ```

4. Access Grafana and import manually if needed:
   - Go to + > Import
   - Paste the JSON file content
   - Configure the Prometheus datasource 