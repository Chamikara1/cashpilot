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
let allowedUsers = [];

// Check if user is allowed
async function isUserAllowed(userId) {
  return allowedUsers.includes(userId);
}

// Real-time transaction listener
function setupRealtimeListener() {
  console.log('🔍 Starting real-time transaction monitor');
  
  db.collection('transactions')
    .where('type', '==', 'Expense')
    .onSnapshot(async (snapshot) => {
      const changedUsers = new Set();
      
      snapshot.docChanges().forEach(change => {
        const userId = change.doc.data().userId;
        changedUsers.add(userId);
        console.log(`🔄 Detected ${change.type} for user ${userId}`);
      });

      for (const userId of changedUsers) {
        try {
          if (await isUserAllowed(userId)) {
            await refreshUserData(userId);
          } else {
            console.log(`🚫 User ${userId} not allowed for tips - skipping`);
            await cleanUserData(userId);
          }
        } catch (error) {
          console.error(`Error processing ${userId}:`, error);
        }
      }
    }, (error) => {
      console.error('Transaction listener error:', error);
      setTimeout(setupRealtimeListener, 5000);
    });
}

// Setup listener for allowed users changes
function setupAllowedUsersListener() {
  console.log('👥 Starting allowed users monitor');
  
  db.collection('allowtips').doc('tipsusers')
    .onSnapshot(async (doc) => {
      if (doc.exists) {
        const newAllowedUsers = doc.data().users || [];
        allowedUsers = newAllowedUsers;
        console.log(`🔄 Updated allowed users list (${allowedUsers.length} users)`);
        
        // Clean up data for users who are no longer allowed
        await cleanUpDisallowedUsers(newAllowedUsers);
      }
    }, (error) => {
      console.error('Allowed users listener error:', error);
      setTimeout(setupAllowedUsersListener, 5000);
    });
}

// Clean up data for users who are no longer allowed
async function cleanUpDisallowedUsers(currentAllowedUsers) {
  const allowedSet = new Set(currentAllowedUsers);
  const foraiRef = db.collection('forai');
  const snapshot = await foraiRef.get();
  
  const cleanupPromises = [];
  const seenUsers = new Set();
  
  snapshot.forEach(doc => {
    const userId = doc.id.split('_')[0];
    if (!allowedSet.has(userId) && !seenUsers.has(userId)) {
      seenUsers.add(userId);
      cleanupPromises.push(cleanUserData(userId));
    }
  });
  
  if (cleanupPromises.length > 0) {
    await Promise.all(cleanupPromises);
    console.log(`🧹 Cleaned up data for ${cleanupPromises.length} disallowed users`);
  }
}

// Clean up user data from forai collection
async function cleanUserData(userId) {
  const now = new Date();
  const currentMonth = now.getMonth() + 1;
  const currentYear = now.getFullYear();
  const prev1 = getPreviousMonth(currentMonth, currentYear);
  const prev2 = getPreviousMonth(prev1.month, prev1.year);

  const monthFormats = [
    formatMonthYear(currentMonth, currentYear),
    formatMonthYear(prev1.month, prev1.year),
    formatMonthYear(prev2.month, prev2.year)
  ];

  const foraiRef = db.collection('forai');
  const deletePromises = monthFormats.map(month => 
    foraiRef.doc(`${userId}_${month}`).delete().catch(() => {})
  );
  
  await Promise.all(deletePromises);
  console.log(`🧹 Cleaned up data for user ${userId}`);
}

// Full refresh for a single user
async function refreshUserData(userId) {
  const now = new Date();
  const currentMonth = now.getMonth() + 1;
  const currentYear = now.getFullYear();
  
  const prev1 = getPreviousMonth(currentMonth, currentYear);
  const prev2 = getPreviousMonth(prev1.month, prev1.year);

  const currentMonthStr = formatMonthYear(currentMonth, currentYear);
  const prevMonthStr = formatMonthYear(prev1.month, prev1.year);
  const twoMonthsAgoStr = formatMonthYear(prev2.month, prev2.year);

  // Get all transactions for the user
  const snapshot = await db.collection('transactions')
    .where('userId', '==', userId)
    .where('type', '==', 'Expense')
    .get();

  // Recalculate from scratch with userId included
  const currentData = { userId };
  const previousData = { userId };
  
  let hasCurrentMonthData = false;
  let hasPreviousMonthData = false;

  snapshot.forEach(doc => {
    const transaction = doc.data();
    const transDate = transaction.date.toDate();
    const transMonth = transDate.getMonth() + 1;
    const transYear = transDate.getFullYear();
    const category = transaction.category || 'uncategorized';
    const amount = parseFloat(transaction.amount) || 0;

    if (transMonth === currentMonth && transYear === currentYear) {
      currentData[category] = (currentData[category] || 0) + amount;
      hasCurrentMonthData = true;
    } 
    else if (transMonth === prev1.month && transYear === prev1.year) {
      previousData[category] = (previousData[category] || 0) + amount;
      hasPreviousMonthData = true;
    }
  });

  // Only update Firestore if user has data for both months
  if (hasCurrentMonthData && hasPreviousMonthData) {
    const batch = db.batch();
    const foraiRef = db.collection('forai');

    batch.set(foraiRef.doc(`${userId}_${currentMonthStr}`), currentData);
    batch.set(foraiRef.doc(`${userId}_${prevMonthStr}`), previousData);
    
    await batch.commit();
    console.log(`♻️ Refreshed ${userId} (${snapshot.size} transactions)`);
  } else {
    console.log(`⏩ Skipping ${userId} - no data for both months`);
    
    // Clean up existing data if they no longer qualify
    const foraiRef = db.collection('forai');
    await foraiRef.doc(`${userId}_${currentMonthStr}`).delete().catch(() => {});
    await foraiRef.doc(`${userId}_${prevMonthStr}`).delete().catch(() => {});
  }

  // Cleanup old data regardless
  await db.collection('forai').doc(`${userId}_${twoMonthsAgoStr}`).delete().catch(() => {});
}

// Initialize with current active users
async function initializeUsers() {
  try {
    const doc = await db.collection('allowtips').doc('tipsusers').get();
    if (doc.exists) {
      allowedUsers = doc.data().users || [];
      console.log(`👥 Tracking ${allowedUsers.length} allowed users`);
    }
  } catch (error) {
    console.error('Error initializing allowed users:', error);
  }
}

// Helper functions
function getPreviousMonth(month, year) {
  let prevMonth = month - 1;
  let prevYear = year;
  if (prevMonth === 0) {
    prevMonth = 12;
    prevYear = year - 1;
  }
  return { month: prevMonth, year: prevYear };
}

function formatMonthYear(month, year) {
  return `${new Date(year, month - 1, 1).toLocaleString('default', { month: 'long' })}${year}`.toLowerCase();
}

// Start service
async function startService() {
  await initializeUsers();
  setupRealtimeListener();
  setupAllowedUsersListener();
  
  process.on('SIGINT', () => {
    console.log('🛑 Stopping service');
    process.exit(0);
  });
}

startService().catch(console.error);