import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:computing_group/analyticspage.dart';
import 'package:computing_group/morepage.dart';
import 'package:computing_group/transactionpage.dart';
import 'package:computing_group/sms.dart'; // Make sure this import is correct

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(home: BankPage()));
}

class BankPage extends StatefulWidget {
  @override
  _BankPageState createState() => _BankPageState();
}

class _BankPageState extends State<BankPage> {
  final List<String> popularBanks = [
    'Commercial Bank',
    'People\'s Bank',
    'Bank of Ceylon',
    'Hatton National Bank',
    'Sampath Bank',
    'DFCC Bank',
    'Seylan Bank',
    'NDB Bank',
  ];

  bool isCommercialAdded = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkBankStatus();
  }

  Future<void> _checkBankStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";
    final snapshot = await _firestore
        .collection('bank')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final banks = snapshot.docs.first.data()['banks'] as List<dynamic>? ?? [];
      setState(() {
        isCommercialAdded = banks.contains('Commercial Bank');
      });
    }
  }

  void _onBankTap(String bankName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";

    if (bankName == 'Commercial Bank') {
      if (isCommercialAdded) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove Bank'),
            content: Text('Do you want to remove $bankName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final userBankDoc = await _firestore
                      .collection('bank')
                      .where('userId', isEqualTo: userId)
                      .limit(1)
                      .get();

                  if (userBankDoc.docs.isNotEmpty) {
                    await userBankDoc.docs.first.reference.update({
                      'banks': FieldValue.arrayRemove([bankName]),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }

                  setState(() {
                    isCommercialAdded = false;
                  });

                  Navigator.pop(context);
                },
                child: Text('Remove'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Add Bank'),
            content: Text('Do you want to add $bankName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  setState(() {
                    isCommercialAdded = true;
                  });

                  Navigator.pop(context);

                  try {
                    final userBankDoc = await _firestore
                        .collection('bank')
                        .where('userId', isEqualTo: userId)
                        .limit(1)
                        .get();

                    if (userBankDoc.docs.isEmpty) {
                      await _firestore.collection('bank').add({
                        'userId': userId,
                        'banks': [bankName],
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await userBankDoc.docs.first.reference.update({
                        'banks': FieldValue.arrayUnion([bankName]),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }
                  } catch (e) {
                    debugPrint('Error adding bank: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding bank: $e')),
                    );
                  }
                },
                child: Text('Add'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bank'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SmsMessagesPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: popularBanks.length,
          itemBuilder: (context, index) {
            final bank = popularBanks[index];
            return GestureDetector(
              onTap: () => _onBankTap(bank),
              child: Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Icon(Icons.account_balance, color: Colors.blue),
                  title: Text(
                    bank,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  trailing: (bank == 'Commercial Bank' && isCommercialAdded)
                      ? Icon(Icons.check, color: Colors.green)
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}