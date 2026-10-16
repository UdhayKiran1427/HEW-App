const express = require('express');
const router = express.Router();
const habitController = require('../controllers/habitController');
const authenticateToken = require('../middlewares/authMiddleware');

// All habit routes require authentication
router.use(authenticateToken);

router.get('/', habitController.getHabits);
router.post('/', habitController.createHabit);
router.get('/:id', habitController.getHabitDetails);
router.put('/:id', habitController.updateHabit);
router.delete('/:id', habitController.deleteHabit);

// One-tap check-in toggle
router.post('/:id/check-in', habitController.toggleCheckIn);

// Offline sync
router.post('/sync/batch', habitController.batchSyncHabitLogs);

module.exports = router;

