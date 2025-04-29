const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.processRecurringPayments = functions.pubsub
    .schedule("every 1 minutes")
    .timeZone("Asia/Colombo")
    .onRun(async (context) => {
      const now = admin.firestore.Timestamp.now();
      const recurringPayments = await admin.firestore()
          .collection("recurring")
          .where("nextPaymentDate", "<=", now)
          .get();

      const batch = admin.firestore().batch();

      recurringPayments.forEach((doc) => {
        const data = doc.data();

        // Add transaction
        const transactionRef = admin.firestore()
            .collection("transactions").doc();
        batch.set(transactionRef, {
          amount: parseFloat(data.amount),
          category: data.category,
          date: now,
          description: `Recurring: ${data.description}`,
          type: "Expense",
          userId: data.userId,
        });

        // Calculate and update next payment date
        const nextDate = calculateNextPayment(now.toDate(), data.term);
        batch.update(doc.ref, {
          lastPaymentDate: now,
          nextPaymentDate: admin.firestore.Timestamp.fromDate(nextDate),
        });
      });

      await batch.commit();
      console.log(`Processed ${recurringPayments.size} recurring payments`);
      return null;
    });

/**
 * Calculates next payment date
 * @param {Date} lastDate
 * @param {string} term
 * @return {Date}
 */
function calculateNextPayment(lastDate, term) {
  if (term === "30s (testing)") return new Date(lastDate.getTime() + 30000);
  if (term === "06 month") {
    return new Date(
        lastDate.getFullYear(),
        lastDate.getMonth() + 6,
        lastDate.getDate(),
    );
  }
  if (term === "12 months") {
    return new Date(
        lastDate.getFullYear(),
        lastDate.getMonth() + 12,
        lastDate.getDate(),
    );
  }
  return new Date(
      lastDate.getFullYear(),
      lastDate.getMonth() + 1,
      lastDate.getDate(),
  );
}
