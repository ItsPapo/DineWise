require('dotenv').config();
const mongoose = require('mongoose');

if (!process.env.MONGO_URI) {
    console.error('❌ MONGO_URI is not defined in .env');
} else {
    mongoose.connect(process.env.MONGO_URI)
        .then(() => console.log('✅ Connected to MongoDB'))
        .catch((err) => console.error('❌ MongoDB connection error:', err));
}

