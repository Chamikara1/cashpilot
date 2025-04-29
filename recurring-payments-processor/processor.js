require('dotenv').config();
const admin = require('firebase-admin');

// Initialize Firebase
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
  }),
  databaseURL: process.env.FIRESTORE_DATABASE_URL
});

const db = admin.firestore();
const paymentTimers = new Map();
const MAX_32BIT_INT = 2147483647; // Maximum 32-bit signed integer value

// Improved date calculation with proper month handling
function calculateNextDate(startDate, term) {
  const date = new Date(startDate);
  const originalDate = date.getDate();
  
  switch (term) {
    case '30s (testing)':
      return new Date(date.getTime() + 30 * 1000);
      
    case '01 month':
      date.setMonth(date.getMonth() + 1);
      break;
      
    case '06 month':
      date.setMonth(date.getMonth() + 6);
      break;
      
    case '12 months':
      date.setFullYear(date.getFullYear() + 1);
      break;
      
    default:
      throw new Error(`Unknown term: ${term}`);
  }

  // Handle month overflow (e.g., Jan 31 → Feb 28)
  if (date.getDate() !== originalDate) {
    date.setDate(0); // Last day of previous month
  }
  
  return date;
}

// Safe setTimeout that handles large durations
function safeSetTimeout(callback, delay) {
  if (delay <= MAX_32BIT_INT) {
    return setTimeout(callback, delay);
  } else {
    const remaining = delay - MAX_32BIT_INT;
    return setTimeout(() => {
      safeSetTimeout(callback, remaining);
    }, MAX_32BIT_INT);
  }
}

async function setupPayment(paymentDoc) {
  const payment = paymentDoc.data();
  
  // Clear any existing timer
  cleanupTimer(paymentDoc.id);

  // Use last processed date or creation date if not processed yet
  const baseDate = payment.lastProcessed 
    ? payment.lastProcessed.toDate() 
    : payment.date.toDate();
  
  // Calculate the next valid execution time
  let nextExecution = calculateNextDate(baseDate, payment.term);
  const now = new Date();

  // Ensure we don't schedule in the past
  if (nextExecution <= now) {
    nextExecution = calculateNextDate(now, payment.term);
  }

  const delay = nextExecution - now;

  console.log(`⏳ Scheduling ${payment.description} for ${nextExecution.toLocaleString()}`);

  // Schedule the payment execution
  const timer = {
    timeout: safeSetTimeout(async () => {
      await executePaymentCycle(paymentDoc);
    }, delay),
    nextExecution: nextExecution.getTime()
  };

  paymentTimers.set(paymentDoc.id, timer);
}

async function executePaymentCycle(paymentDoc) {
  const payment = paymentDoc.data();
  
  // Process the current payment
  await processPayment(paymentDoc);
  
  // Immediately schedule the next one
  if (payment.term !== '30s (testing)') {
    setupPayment(paymentDoc);
  } else {
    // For testing, set interval after first execution
    const timer = {
      interval: setInterval(async () => {
        await processPayment(paymentDoc);
      }, 30 * 1000),
      nextExecution: Date.now() + 30000
    };
    paymentTimers.set(paymentDoc.id, timer);
  }
}

async function processPayment(paymentDoc) {
  const payment = paymentDoc.data();
  const now = admin.firestore.Timestamp.now();

  try {
    // Verify the payment still exists
    const doc = await paymentDoc.ref.get();
    if (!doc.exists) {
      cleanupTimer(paymentDoc.id);
      return;
    }

    // Create transaction record
    await db.collection('transactions').add({
      amount: parseFloat(payment.amount),
      category: payment.category || 'Uncategorized',
      date: now,
      description: `Recurring: ${payment.description}`,
      type: 'Expense',
      userId: payment.userId
    });

    // Calculate next payment date
    const nextPaymentDate = calculateNextDate(now.toDate(), payment.term);

    // Update payment record
    await paymentDoc.ref.update({
      lastProcessed: now,
      nextPayment: admin.firestore.Timestamp.fromDate(nextPaymentDate),
      cyclesCompleted: (payment.cyclesCompleted || 0) + 1
    });

    console.log(`✅ Processed ${payment.description} at ${now.toDate().toLocaleString()}`);
  } catch (error) {
    console.error(`❗ Failed to process ${payment.description}:`, error.message);
    // Reschedule on error
    setTimeout(() => setupPayment(paymentDoc), 5000);
  }
}

function cleanupTimer(paymentId) {
  if (paymentTimers.has(paymentId)) {
    const timer = paymentTimers.get(paymentId);
    if (timer.timeout) clearTimeout(timer.timeout);
    if (timer.interval) clearInterval(timer.interval);
    paymentTimers.delete(paymentId);
  }
}

// Real-time listener for payment changes
function setupRealtimeListener() {
  db.collection('recurring').onSnapshot(snapshot => {
    snapshot.docChanges().forEach(change => {
      const payment = change.doc.data();
      
      if (change.type === 'added' || change.type === 'modified') {
        console.log(`🔄 ${change.type === 'added' ? 'New' : 'Updated'} payment: ${payment.description}`);
        setupPayment(change.doc);
      } else if (change.type === 'removed') {
        console.log(`🗑️ Removed payment: ${payment.description}`);
        cleanupTimer(change.doc.id);
      }
    });
  }, error => {
    console.error('Realtime listener error:', error);
  });
}

// Initialize existing payments
async function initializeExistingPayments() {
  console.log('🔥 Payment Processor Started');
  try {
    const paymentsSnapshot = await db.collection('recurring').get();
    
    paymentsSnapshot.forEach(doc => {
      console.log(`⏳ Initializing existing: ${doc.data().description}`);
      setupPayment(doc);
    });
  } catch (error) {
    console.error('Initialization error:', error);
  }
}

// Graceful shutdown
function shutdown() {
  console.log('🛑 Stopping payment processor...');
  paymentTimers.forEach((_, id) => cleanupTimer(id));
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// Start the service
initializeExistingPayments();
setupRealtimeListener();