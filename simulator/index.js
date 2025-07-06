require('dotenv').config();
const mqtt = require('mqtt');

const brokerUrl = process.env.MQTT_BROKER_URL || "mqtt://localhost";
const topic = process.env.MQTT_TOPIC || "iot/data";
const interval = parseInt(process.env.PUBLISH_INTERVAL_MS, 10) || 2000;

// Connect to MQTT broker
const client = mqtt.connect(brokerUrl);

client.on('connect', () => {
  console.log(`Connected to MQTT broker at ${brokerUrl}`);
setInterval(() => {
  // Generate random data
  const payload = {
  deviceId: "sensor-local",
    temperature: (20 + Math.random() * 10).toFixed(2),
    humidity: (40 + Math.random() * 20).toFixed(2),
    timestamp: new Date().toISOString()
  };
  // Publish to topic
  client.publish(topic, JSON.stringify(payload), { qos: 0 }, (err) => {
    if (err) {
      console.error('Simulator has failed to publish:', err);
    } else {
      console.log('Simulator has published:', payload);
  }
      });
}, interval);
});

client.on('error', (err) => {
  console.error('Error connecting to MQTT:', err);
});