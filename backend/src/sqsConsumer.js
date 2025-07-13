const { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } = require('@aws-sdk/client-sqs');
const { insertData, incrementMqttMessages, temperatureGauge, humidityGauge } = require('./metrics');

const sqsUrl = process.env.AWS_SQS_URL;
const region = process.env.AWS_REGION || 'eu-west-1';
const client = new SQSClient({ region });

async function pollSQS() {
  while (true) {
    const command = new ReceiveMessageCommand({
      QueueUrl: sqsUrl,
      MaxNumberOfMessages: 10,
      WaitTimeSeconds: 20 // long polling
    });
    try {
      const data = await client.send(command);
      if (data.Messages) {
        for (const msg of data.Messages) {
          const payload = JSON.parse(msg.Body);
          // Processa a mensagem normalmente
          await insertData(payload);
          incrementMqttMessages();
          temperatureGauge.set(Number(payload.temperature));
          humidityGauge.set(Number(payload.humidity));
          // Remove da fila
          await client.send(new DeleteMessageCommand({
            QueueUrl: sqsUrl,
            ReceiptHandle: msg.ReceiptHandle
          }));
        }
      }
    } catch (err) {
      console.error('Error consuming SQS:', err);
    }
  }
}

module.exports = { pollSQS };
