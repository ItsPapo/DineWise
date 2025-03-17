const mongoose = require('mongoose');

const logSchema = new mongoose.Schema({
    message: { type: String, required: true },
    level: { type: String, required: true },
    timestamp: { type: Date, default: Date.now }
});

const Log = mongoose.model('Log', logSchema); // ✅ Create a model from the schema

module.exports = Log;

