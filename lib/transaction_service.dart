import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'transaction_model.dart'; // Updated import

class TransactionService {
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a new transaction
  Future<void> addTransaction(FinancialTransaction transaction) async {
    try {
      await _firestore.collection('transactions').add(transaction.toMap());
    } catch (e) {
      print('Error adding transaction: $e');
      rethrow;
    }
  }

  // Get all transactions for the current user
  Stream<List<FinancialTransaction>> getTransactions() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FinancialTransaction.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // Get transactions filtered by date range
  Stream<List<FinancialTransaction>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Create timestamps for the start and end of the day
    final startTimestamp = fs.Timestamp.fromDate(DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ));

    final endTimestamp = fs.Timestamp.fromDate(DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    ));

    try {
      return _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => FinancialTransaction.fromMap(doc.id, doc.data()))
            .toList();
      }).handleError((error) {
        print('Error fetching transactions: $error');
        if (error.toString().contains('failed-precondition')) {
          print('Please create the required index in Firebase Console');
        }
        return <FinancialTransaction>[];
      });
    } catch (e) {
      print('Error in getTransactionsByDateRange: $e');
      return Stream.value(<FinancialTransaction>[]);
    }
  }

  // Additional useful methods you might want to add:

  // Update a transaction
  Future<void> updateTransaction(FinancialTransaction transaction) async {
    try {
      await _firestore
          .collection('transactions')
          .doc(transaction.id)
          .update(transaction.toMap());
    } catch (e) {
      print('Error updating transaction: $e');
      rethrow;
    }
  }

  // Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).delete();
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }
}