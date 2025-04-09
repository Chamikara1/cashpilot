import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final String type;
  final String userId;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    // Ensure date is set to start of day for consistent querying
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return {
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(normalizedDate),
      'category': category,
      'type': type,
      'userId': userId,
    };
  }

  factory Transaction.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['date'] as Timestamp;
    final date = timestamp.toDate();
    // Normalize the date to start of day
    final normalizedDate = DateTime(date.year, date.month, date.day);

    return Transaction(
      id: id,
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: normalizedDate,
      category: map['category'] ?? '',
      type: map['type'] ?? '',
      userId: map['userId'] ?? '',
    );
  }
}
