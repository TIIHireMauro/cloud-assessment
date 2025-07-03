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

module.exports = { register, incrementMqttMessages };