const express = require('express');
const { getData } = require('./db');

const router = express.Router();

// This is to bring the last 100 messages from the DB
router.get('/data', async (req, res) => {
  try {
    const rows = await getData(100);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch data' });
  }
});

// Health check to verify if the service is running
router.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = router;