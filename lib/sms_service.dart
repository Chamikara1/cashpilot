import 'package:telephony/telephony.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmsService {
  final Telephony telephony = Telephony.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String allowedNumber = '+94776098865';

  Future<void> fetchAndStoreBankMessages() async {
    try {
      // First check if user has any banks added
      final hasBanks = await _checkBankStatus();
      if (!hasBanks) {
        print('No banks added - skipping SMS processing');
        return;
      }

      // Get the most recent bank timestamp (updatedAt or createdAt)
      final bankAddedTime = await _fetchBankAddedTime();
      if (bankAddedTime == null) {
        print('No valid bank timestamp found');
        return;
      }

      // Check SMS permissions
      bool? permissionGranted = await telephony.requestPhoneAndSmsPermissions;
      if (permissionGranted != true) return;

      // Get all messages
      List<SmsMessage> allMessages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      // Filter messages
      final filteredMessages = allMessages.where((msg) {
        final isFromAllowedNumber = msg.address?.contains(allowedNumber) ?? false;
        final isAfterBankAdded = msg.date != null &&
            DateTime.fromMillisecondsSinceEpoch(msg.date!).isAfter(bankAddedTime);
        return isFromAllowedNumber && isAfterBankAdded;
      }).toList();

      // Store filtered messages
      await _storeMessagesInFirestore(filteredMessages);
    } catch (e) {
      print('Error in SMS service: $e');
    }
  }

  Future<bool> _checkBankStatus() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final snapshot = await _firestore.collection('bank')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final banks = data['banks'] as List<dynamic>? ?? [];
        return banks.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Error checking bank status: $e');
      return false;
    }
  }

  Future<DateTime?> _fetchBankAddedTime() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final snapshot = await _firestore.collection('bank')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        // Use updatedAt if available, otherwise use createdAt
        return (data['updatedAt'] as Timestamp?)?.toDate() ??
            (data['createdAt'] as Timestamp?)?.toDate();
      }
      return null;
    } catch (e) {
      print('Error fetching bank time: $e');
      return null;
    }
  }

  Future<void> _storeMessagesInFirestore(List<SmsMessage> messages) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final batch = _firestore.batch();
      final bankTransCollectionRef = _firestore.collection('banktrans');
      final transactionsCollectionRef = _firestore.collection('transactions');

      final existingMessages = await bankTransCollectionRef
          .where('userId', isEqualTo: userId)
          .get()
          .then((snapshot) => snapshot.docs.map((doc) => doc.data()['msgId']).toList());

      for (final msg in messages) {
        final msgId = '${msg.address}_${msg.date}';
        if (!existingMessages.contains(msgId)) {
          final parsedData = _parseSmsContent(msg.body ?? '');
          final transactionDate = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);

          // Store in banktrans collection
          final bankTransDocRef = bankTransCollectionRef.doc();
          batch.set(bankTransDocRef, {
            'userId': userId,
            'msgId': msgId,
            'bank': 'Commercial Bank',
            'sender': msg.address,
            'originalBody': msg.body,
            'date': transactionDate,
            'createdAt': FieldValue.serverTimestamp(),
            'isProcessed': false,
            ...parsedData,
          });

          // Only store in transactions collection if it's a valid transaction (amount > 0)
          if (parsedData['amount'] > -1) {
            final transactionDocRef = transactionsCollectionRef.doc();
            batch.set(transactionDocRef, {
              'userId': userId,
              'amount': parsedData['amount'],
              'category': parsedData['category'],
              'date': transactionDate,
              'description': parsedData['description'],
              'type': parsedData['type'],
              'createdAt': FieldValue.serverTimestamp(),
              'source': 'SMS Auto-Import',
              'bank': 'Commercial Bank',
            });
          }
        }
      }

      await batch.commit();
      print('Stored ${messages.length} messages in Firestore');
    } catch (e) {
      print('Error storing messages: $e');
    }
  }

  Map<String, dynamic> _parseSmsContent(String smsBody) {
    try {
      Map<String, dynamic> result = {
        'amount': 0.0,
        'description': 'Unknown',
        'category': 'Other',
        'type': 'Expense',
      };

      final creditRegex = RegExp(
        r'Credit for Rs\.? ([0-9,]+(\.[0-9]{2})?) to',
        caseSensitive: false,
      );

      final debitRegex = RegExp(
        r'Purchase at (.+?) for LKR ([0-9,]+(\.[0-9]{2})?) on',
        caseSensitive: false,
      );

      if (creditRegex.hasMatch(smsBody)) {
        final match = creditRegex.firstMatch(smsBody);
        final amount = match?.group(1)?.replaceAll(',', '') ?? '0';
        result = {
          'amount': double.parse(amount),
          'description': 'Bank Credit',
          'category': 'Income',
          'type': 'Income',
        };
      }
      else if (debitRegex.hasMatch(smsBody)) {
        final match = debitRegex.firstMatch(smsBody);
        final amount = match?.group(2)?.replaceAll(',', '') ?? '0';
        final merchant = match?.group(1)?.trim() ?? 'Unknown Merchant';
        result = {
          'amount': double.parse(amount),
          'description': merchant,
          'category': _categorizeTransaction(merchant),
          'type': 'Expense',
        };
      }

      return result;
    } catch (e) {
      print('Error parsing SMS content: $e');
      return {
        'amount': 0.0,
        'description': 'Unknown',
        'category': 'Other',
        'type': 'Expense',
      };
    }
  }

  String _categorizeTransaction(String merchant) {
    final merchantLower = merchant.toLowerCase();

    if (merchantLower.contains('hospital') ||
        merchantLower.contains('medical') ||
        merchantLower.contains('pharmacy')) {
      return 'Healthcare';
    } else if (merchantLower.contains('super') ||
        merchantLower.contains('market') ||
        merchantLower.contains('food')) {
      return 'Groceries';
    } else if (merchantLower.contains('restaurant') ||
        merchantLower.contains('cafe') ||
        merchantLower.contains('dining')) {
      return 'Dining';
    } else if (merchantLower.contains('petrol') ||
        merchantLower.contains('fuel') ||
        merchantLower.contains('gas')) {
      return 'Transport';
    } else if (merchantLower.contains('hotel') ||
        merchantLower.contains('resort') ||
        merchantLower.contains('travel')) {
      return 'Travel';
    }

    return 'Other';
  }
}