const express = require('express');
const router = express.Router();
const itemController = require('../controllers/itemController');
const authenticateToken = require('../middlewares/authMiddleware');

// All item routes require authentication
router.use(authenticateToken);

router.get('/', itemController.getItems); // supports ?q=search_term&tag=tag_name
router.post('/', itemController.createItem);
router.get('/:id', itemController.getItemById);
router.put('/:id', itemController.updateItem);
router.post('/:id/move', itemController.moveItem);
router.delete('/:id', itemController.deleteItem);

module.exports = router;

