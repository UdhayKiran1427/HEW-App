const express = require('express');
const router = express.Router();
const renewalController = require('../controllers/renewalController');
const authenticateToken = require('../middlewares/authMiddleware');

// All renewal routes require authentication
router.use(authenticateToken);

router.get('/', renewalController.getRenewals);
router.post('/', renewalController.createRenewal);
router.put('/:id', renewalController.updateRenewal);
router.delete('/:id', renewalController.deleteRenewal);

module.exports = router;
