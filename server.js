require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');
require('./mongo');

const authRoutes = require('./routes/authRoutes');
const Log = require('./models/Log');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
    res.send('Server is working!');
});

app.use('/auth', authRoutes);

app.get('/restaurants', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM restaurants');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/log', async (req, res) => {
    const { message, level } = req.body;

    if (!message || !level) {
        return res.status(400).json({ error: 'Message and level are required' });
    }

    try {
        const log = new Log({ message, level });
        await log.save();
        res.json(log);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});


app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});

