const mqtt = require('mqtt');
const { insertData } = require('./db');
const { incrementMqttMessages } = require('./metrics');
require('dotenv').config();

const brokerUrl = process.env.MQTT_BROKER_URL;
const topic = process.env.MQTT_TOPIC;

const client = mqtt.connect(brokerUrl);

client.on('connect', () => {
  console.log('Connected to MQTT broker');
  client.subscribe(topic, (err) => {
    if (err) {
      console.error('Failed to subscribe to topic:', topic, err);
    } else {
      console.log('Subscribed to topic:', topic);
    }
  });
});

client.on('message', async (topic, message) => {
  try {
    const payload = JSON.parse(message.toString());
    await insertData(payload);
    incrementMqttMessages();
    console.log('Inserted MQTT message on DB:', payload);
  } catch (err) {
    console.error('Error processing MQTT message:', err);
  }
});

client.on('error', (err) => {
  console.error('MQTT error:', err);
});

module.exports = client;