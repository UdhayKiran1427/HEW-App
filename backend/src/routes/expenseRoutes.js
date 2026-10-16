const express = require('express');
const router = express.Router();
const expenseController = require('../controllers/expenseController');
const authenticateToken = require('../middlewares/authMiddleware');

// All expense routes require authentication
router.use(authenticateToken);

// Category routes
router.get('/categories', expenseController.getCategories);
router.post('/categories', expenseController.createCategory);

// Summary & Report routes (Must be defined before /:id)
router.get('/reports/summary', expenseController.getSummaryReports);

// Offline sync route
router.post('/sync/batch', expenseController.batchSyncExpenses);

// Expense CRUD
router.get('/', expenseController.getExpenses);
router.post('/', expenseController.createExpense);
router.put('/:id', expenseController.updateExpense);
router.delete('/:id', expenseController.deleteExpense);

module.exports = router;

