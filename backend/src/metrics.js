const client = require('prom-client');

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const mqttMessagesCounter = new client.Counter({
  name: 'mqtt_messages_total',
  help: 'Total MQTT messages received',
});
register.registerMetric(mqttMessagesCounter);

function incrementMqttMessages() {
  mqttMessagesCounter.inc();
}

// Example: Gauge for the temperature
const temperatureGauge = new client.Gauge({
  name: 'sensor_temperature',
  help: 'Current temperature reported by sensors'
});
register.registerMetric(temperatureGauge);

// Example: Gauge for the humidity
const humidityGauge = new client.Gauge({
  name: 'sensor_humidity',
  help: 'Current humidity reported by sensors'
});
register.registerMetric(humidityGauge);


module.exports = { register, incrementMqttMessages, temperatureGauge, humidityGauge };