const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const router = express.Router();

router.post('/signup', async (req, res) => {
    const { username, email, password } = req.body;
    try {
        const existingUser = await User.findByEmail(email);
        if (existingUser) {
            return res.status(400).json({ message: 'User already exists' });
        }

        const user = await User.create({ username, email, password });
        const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });

        res.status(201).json({ token, user });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

router.post('/login', async (req, res) => {
    const { email, password } = req.body;
    try {
        const user = await User.findByEmail(email);
        if (!user) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Invalid credentials' });
        }

        const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
        res.json({ token, user });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;

