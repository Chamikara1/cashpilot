import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SmsMessagesPage extends StatefulWidget {
  @override
  _SmsMessagesPageState createState() => _SmsMessagesPageState();
}

class _SmsMessagesPageState extends State<SmsMessagesPage> {
  final Telephony telephony = Telephony.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String allowedNumber = '+94776098865';
  List<SmsMessage> messages = [];
  bool isLoading = true;
  bool hasPermission = false;
  DateTime? bankAddedTime;
  bool hasBanks = false;

  @override
  void initState() {
    super.initState();
    _checkBankStatus().then((_) {
      if (hasBanks) {
        _requestPermissionAndLoadSms();
      } else {
        setState(() => isLoading = false);
      }
    });
  }

  Future<void> _checkBankStatus() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await _firestore.collection('bank')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final banks = data['banks'] as List<dynamic>? ?? [];

        setState(() {
          hasBanks = banks.isNotEmpty;
          // Use updatedAt if available, otherwise use createdAt
          bankAddedTime = (data['updatedAt'] as Timestamp?)?.toDate() ??
              (data['createdAt'] as Timestamp?)?.toDate();
        });
      }
    } catch (e) {
      debugPrint('Error checking bank status: $e');
    }
  }

  Future<void> _requestPermissionAndLoadSms() async {
    bool? permissionGranted = await telephony.requestPhoneAndSmsPermissions;

    if (permissionGranted ?? false) {
      setState(() => hasPermission = true);
      _loadSmsMessages();
    } else {
      setState(() {
        isLoading = false;
        hasPermission = false;
      });
    }
  }

  Future<void> _loadSmsMessages() async {
    try {
      if (!hasBanks || bankAddedTime == null) {
        setState(() => isLoading = false);
        return;
      }

      List<SmsMessage> allMessages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      final filteredMessages = allMessages.where((msg) {
        final isFromAllowedNumber = msg.address?.contains(allowedNumber) ?? false;
        final isAfterBankAdded = msg.date != null &&
            DateTime.fromMillisecondsSinceEpoch(msg.date!).isAfter(bankAddedTime!);
        return isFromAllowedNumber && isAfterBankAdded;
      }).toList();

      setState(() {
        messages = filteredMessages;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error loading SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bank SMS Messages'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSmsMessages,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('SMS permission required'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _requestPermissionAndLoadSms,
              child: Text('Grant Permission'),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (!hasBanks) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No banks added yet'),
            Text('Please add a bank to view messages',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No messages found'),
            Text('Messages must be received after ${DateFormat('MMM dd, yyyy').format(bankAddedTime!)}',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final date = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);

        return Card(
          margin: EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: CircleAvatar(child: Icon(Icons.sms)),
            title: Text('Commercial Bank',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(msg.body ?? 'No content'),
                SizedBox(height: 8),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(date),
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}