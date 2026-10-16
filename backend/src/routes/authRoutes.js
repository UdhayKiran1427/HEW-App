const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authenticateToken = require('../middlewares/authMiddleware');
const { authLimiter } = require('../middlewares/rateLimiter');

// Public routes (Rate limited to prevent brute force)
router.post('/register', authLimiter, authController.register);
router.post('/login', authLimiter, authController.login);

// Protected routes
router.get('/profile', authenticateToken, authController.getProfile);
router.put('/currency', authenticateToken, authController.updateCurrency);

module.exports = router;

