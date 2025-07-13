require('dotenv').config();
const express = require('express');
const routes = require('./routes');
const { register } = require('./metrics');

// Starts MQTT client and DB ingestion
try {
  console.log('Starting MQTT client...');
  require('./mqttClient');
  console.log('MQTT client started successfully');
} catch (error) {
  console.error('Error starting MQTT client:', error);
}

// Starts the server
const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());
app.use('/api', routes);

// Prometheus metrics endpoint ("* Metrics exposed via `/metrics` endpoint. (suggest and use available services that can export this data)")
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics());
});

app.listen(port, () => {
  console.log(`Backend listening on port ${port}`);
});

if (process.env.CONSUME_SQS === 'true') {
  const { pollSQS } = require('./sqsConsumer');
  pollSQS();
}