const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const dotenv = require('dotenv');

dotenv.config();

// Middlewares
const { apiLimiter } = require('./middlewares/rateLimiter');
const errorHandler = require('./middlewares/errorHandler');

// Route Imports
const authRoutes = require('./routes/authRoutes');
const habitRoutes = require('./routes/habitRoutes');
const expenseRoutes = require('./routes/expenseRoutes');
const itemRoutes = require('./routes/itemRoutes');
const renewalRoutes = require('./routes/renewalRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// Standard Middlewares
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// Apply General Rate Limiter to all API routes
app.use('/api', apiLimiter);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    app: 'DailyKit REST API',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// Route Mounting
app.use('/api/auth', authRoutes);
app.use('/api/habits', habitRoutes);
app.use('/api/expenses', expenseRoutes);
app.use('/api/items', itemRoutes);
app.use('/api/renewals', renewalRoutes);

// 404 Route Handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: `API endpoint ${req.originalUrl} not found.`
  });
});

// Central Error Handler
app.use(errorHandler);

// Start Server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`===============================================`);
  console.log(`🚀 DailyKit REST API running on port ${PORT}`);
  console.log(`🔗 Local: http://localhost:${PORT}/api/health`);
  console.log(`📱 Android Emulator URL: http://10.0.2.2:${PORT}/api/health`);
  console.log(`===============================================`);
});

module.exports = app;

