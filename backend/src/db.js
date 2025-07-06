const { Client } = require('pg');
require('dotenv').config();

const client = new Client({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: { rejectUnauthorized: false }
});

client.connect()
  .then(() => console.log('Connected to PostgreSQL database'))
  .catch((err) => {
    console.error('Failed to connect to PostgreSQL:', err);
    process.exit(1);
  });

// Ensure table exists
const initTable = async () => {
  await client.query(`
    CREATE TABLE IF NOT EXISTS iot_data (
      id SERIAL PRIMARY KEY,
      timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      payload JSONB
    );
  `);
};
initTable();

async function insertData(payload) {
  await client.query('INSERT INTO iot_data(payload) VALUES($1)', [payload]);
}

async function getData(limit = 100) {
  const res = await client.query('SELECT * FROM iot_data ORDER BY timestamp DESC LIMIT $1', [limit]);
  return res.rows;
}

module.exports = { insertData, getData };