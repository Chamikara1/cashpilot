const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase with proper error handling
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://your-project-id.firebaseio.com',
  ignoreUndefinedProperties: true
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

// Enhanced logging
const log = {
  info: (...args) => console.log('[INFO]', new Date().toISOString(), ...args),
  success: (...args) => console.log('[SUCCESS]', new Date().toISOString(), ...args),
  warn: (...args) => console.log('[WARNING]', new Date().toISOString(), ...args),
  error: (...args) => console.log('[ERROR]', new Date().toISOString(), ...args),
  debug: (...args) => console.log('[DEBUG]', new Date().toISOString(), ...args)
};

// Notification thresholds
const Threshold = {
  REACHED_75: '75',
  REACHED_100: '100',
  ABOVE_100: '101',  // New threshold for significantly exceeding budget
  UNDER_75: 'u75',
  UNDER_100: 'u100'
};

// Store last notification timestamps to prevent duplicates
const lastNotifications = new Map(); // format: 'goalId:threshold' -> timestamp

// Process transaction with complete validation
async function processTransaction(transaction, changeType, docId) {
  const txnId = docId || transaction.id;
  if (!txnId) {
    log.error('Missing transaction ID');
    return;
  }

  try {
    // Validate required fields
    if (!transaction.userId || !transaction.category || !transaction.amount || !transaction.date) {
      log.warn('Invalid transaction format', { 
        id: txnId,
        userId: transaction.userId,
        category: transaction.category,
        amount: transaction.amount,
        date: transaction.date
      });
      return;
    }

    log.info(`Processing ${changeType} transaction: ${txnId}`, {
      amount: transaction.amount,
      date: transaction.date.toDate().toISOString(),
      category: transaction.category
    });

    // Find matching goals
    const goalsSnapshot = await db.collection('goals')
      .where('userId', '==', transaction.userId)
      .where('category', '==', transaction.category)
      .get();

    const txnDate = transaction.date.toDate();
    log.debug(`Found ${goalsSnapshot.size} matching goals for transaction ${txnId}`);

    for (const goalDoc of goalsSnapshot.docs) {
      const goal = goalDoc.data();
      
      // Validate goal data including Timestamp objects
      if (!goalDoc.id || !goal.createdAt || !goal.dueDate || 
          !(goal.createdAt instanceof admin.firestore.Timestamp) || 
          !(goal.dueDate instanceof admin.firestore.Timestamp)) {
        log.warn('Invalid goal format', { id: goalDoc.id, ...goal });
        continue;
      }

      const goalStart = goal.createdAt.toDate();
      const goalEnd = goal.dueDate.toDate();

      log.debug(`Checking goal period for ${goal.name || 'Unnamed Goal'} (${goalDoc.id}): 
        Goal Period: ${goalStart.toISOString()} to ${goalEnd.toISOString()}
        Transaction Date: ${txnDate.toISOString()}`);

      // Check if transaction falls within goal period
      if (txnDate >= goalStart && txnDate <= goalEnd) {
        log.info(`Transaction ${txnId} falls within goal period for ${goal.name || 'Unnamed Goal'}`);
        await evaluateGoalProgress(goalDoc, changeType);
      } else {
        log.debug(`Transaction ${txnId} outside goal period for ${goal.name || 'Unnamed Goal'}`);
      }
    }
  } catch (error) {
    log.error(`Error processing transaction ${txnId}:`, error.message, error.stack);
  }
}

// Evaluate goal progress with complete error handling
async function evaluateGoalProgress(goalDoc, changeType) {
  const goal = goalDoc.data();
  const goalId = goalDoc.id;

  try {
    log.info(`Evaluating goal: ${goal.name || 'Unnamed Goal'} (${goalId})`);

    // Calculate current spending
    const spent = await calculateSpentForGoal(goalDoc);
    const currentProgress = spent / goal.amount; // Don't cap at 1.0 to detect amounts above budget

    log.info(`Goal progress calculated: 
      Spent: ${spent}, 
      Budget: ${goal.amount}, 
      Progress: ${(currentProgress * 100).toFixed(2)}%`);

    // Get previous progress from Firestore
    const goalRef = db.collection('goals').doc(goalId);
    const goalSnapshot = await goalRef.get();
    
    if (!goalSnapshot.exists) {
      log.error(`Goal document missing: ${goalId}`);
      return;
    }

    const previousProgress = goalSnapshot.data().lastProgress || 0;
    log.info(`Previous progress: ${(previousProgress * 100).toFixed(2)}%`);

    // Skip if no significant change (only for modifications)
    if (changeType === 'modified' && Math.abs(currentProgress - previousProgress) < 0.01) {
      log.info('Progress change too small, skipping update');
      return;
    }

    // Update goal progress
    await goalRef.update({
      lastProgress: currentProgress,
      currentSpent: spent,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    log.success(`Updated goal progress for ${goalId} to ${(currentProgress * 100).toFixed(2)}%`);

    // Check for threshold crossings
    const thresholdCrossed = detectThresholdCrossing(previousProgress, currentProgress);
    if (thresholdCrossed) {
      log.info(`Threshold crossed: ${thresholdCrossed}`);
      await createNotification({
        ...goal,
        id: goalId
      }, thresholdCrossed, spent, currentProgress);
    } else {
      log.info('No threshold crossed');
    }
  } catch (error) {
    log.error(`Error evaluating goal ${goalId}:`, error.message, error.stack);
  }
}

// Create notification with complete validation
async function createNotification(goal, threshold, spent, currentProgress) {
  try {
    // Validate goal data
    if (!goal.id || !goal.userId || !goal.name || goal.amount === undefined) {
      log.error('Invalid goal data for notification', goal);
      return;
    }

    // Check for duplicate notifications (prevent sending the same notification within 1 hour)
    const notificationKey = `${goal.id}:${threshold}`;
    const now = Date.now();
    const lastNotified = lastNotifications.get(notificationKey) || 0;
    const ONE_HOUR = 60 * 60 * 1000; // 1 hour in milliseconds
    
    if (now - lastNotified < ONE_HOUR) {
      log.info(`Skipping duplicate notification for goal ${goal.id} and threshold ${threshold} (last sent ${Math.floor((now - lastNotified) / 1000)} seconds ago)`);
      return;
    }
    
    // Update the last notification timestamp
    lastNotifications.set(notificationKey, now);

    const amountLeft = Math.max(goal.amount - spent, 0);
    const amountExceeded = Math.max(spent - goal.amount, 0);
    const percentage = (currentProgress * 100).toFixed(0);

    // Create appropriate message
    let message;
    switch (threshold) {
      case Threshold.REACHED_75:
        message = `You've reached 75% of your ${goal.name} budget (LKR ${spent.toFixed(2)} spent). Only LKR ${amountLeft.toFixed(2)} left.`;
        break;
      case Threshold.REACHED_100:
        message = `Budget reached for ${goal.name}! You've spent LKR ${spent.toFixed(2)} of your LKR ${goal.amount.toFixed(2)} budget.`;
        break;
      case Threshold.ABOVE_100:
        message = `Warning! You've significantly exceeded your ${goal.name} budget by LKR ${amountExceeded.toFixed(2)}. You've spent LKR ${spent.toFixed(2)}, which is ${percentage}% of your LKR ${goal.amount.toFixed(2)} budget.`;
        break;
      case Threshold.UNDER_75:
        message = `Your ${goal.name} budget is now under 75% usage. You have ${(100 - percentage)}% left (LKR ${amountLeft.toFixed(2)}).`;
        break;
      case Threshold.UNDER_100:
        message = `Your ${goal.name} budget is now under 100% usage. You have LKR ${amountLeft.toFixed(2)} left.`;
        break;
      default:
        log.error('Unknown threshold:', threshold);
        return;
    }

    // Create notification document
    const notificationData = {
      message,
      date: admin.firestore.FieldValue.serverTimestamp(),
      userId: goal.userId,
      goalId: goal.id,
      goalName: goal.name,
      progress: currentProgress,
      amountSpent: spent,
      budgetAmount: goal.amount,
      isRead: false,
      type: 'budget-alert',
      thresholdReached: threshold
    };

    // Store notification
    await db.collection('notifications').add(notificationData);
    log.success(`Notification stored for goal ${goal.id}: ${message}`);

  } catch (error) {
    log.error('Failed to store notification:', error.message, error.stack);
  }
}

// Calculate total spent for a goal with error handling
async function calculateSpentForGoal(goalDoc) {
  try {
    const goal = goalDoc.data();
    const transactions = await db.collection('transactions')
      .where('userId', '==', goal.userId)
      .where('category', '==', goal.category)
      .get();

    let total = 0;
    const goalStart = goal.createdAt.toDate();
    const goalEnd = goal.dueDate.toDate();

    transactions.forEach(doc => {
      const txn = doc.data();
      if (txn.date && txn.amount) {
        const txnDate = txn.date.toDate();
        if (txnDate >= goalStart && txnDate <= goalEnd) {
          total += parseFloat(txn.amount) || 0;
        }
      }
    });

    log.debug(`Calculated total spent for goal ${goalDoc.id}: ${total}`);
    return total;
  } catch (error) {
    log.error('Error calculating spent amount:', error.message, error.stack);
    return 0;
  }
}

// Detect threshold crossings
function detectThresholdCrossing(previous, current) {
  if (previous < 0.75 && current >= 0.75 && current < 1.0) return Threshold.REACHED_75;
  if (previous < 1.0 && current >= 1.0 && current < 1.01) return Threshold.REACHED_100;
  if (previous < 1.01 && current >= 1.01) return Threshold.ABOVE_100;
  if (previous >= 0.75 && current < 0.75) return Threshold.UNDER_75;
  if (previous >= 1.0 && current < 1.0) return Threshold.UNDER_100;
  return null;
}

// Initialize real-time listeners with error handling
function startMonitoring() {
  log.info('Starting transaction monitoring...');

  const unsubscribe = db.collection('transactions').onSnapshot(snapshot => {
    snapshot.docChanges().forEach(change => {
      try {
        const txn = change.doc.data();
        log.info(`Detected ${change.type} transaction: ${change.doc.id}`);

        if (change.type === 'added' || change.type === 'modified') {
          processTransaction(txn, change.type, change.doc.id);
        } else if (change.type === 'removed') {
          processTransaction(txn, 'deleted', change.doc.id);
        }
      } catch (error) {
        log.error('Error handling transaction change:', error.message, error.stack);
      }
    });
  }, error => {
    log.error('Listener error:', error.message, error.stack);
    // Reconnect after delay
    setTimeout(startMonitoring, 5000);
  });

  // Clean up on exit
  process.on('SIGINT', () => {
    log.info('Shutting down gracefully...');
    unsubscribe();
    process.exit();
  });
}

// Start the monitoring
startMonitoring();

// Keep process alive
setInterval(() => {}, 1000);