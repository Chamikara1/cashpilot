import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecurringPayment {
  final String reference;
  final String category;
  final String term;
  final String amount;
  final DateTime startDate;
  final String? documentId;

  RecurringPayment({
    required this.reference,
    required this.category,
    required this.term,
    required this.amount,
    required this.startDate,
    this.documentId,
  });
}

class RecurringPaymentPage extends StatefulWidget {
  @override
  _RecurringPaymentPageState createState() => _RecurringPaymentPageState();
}

class _RecurringPaymentPageState extends State<RecurringPaymentPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RecurringPayment> recurringPayments = [];
  List<String> categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await _loadCategories();
    await _loadRecurringPayments();
    setState(() => _loading = false);
  }

  Future<void> _loadCategories() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('category').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      List<String> fetchedCategories = List<String>.from(doc.data()!['categories'] ?? []);

      if (!fetchedCategories.contains('Other')) {
        fetchedCategories.add('Other');
      }

      fetchedCategories.sort((a, b) {
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        return a.compareTo(b);
      });

      setState(() => categories = fetchedCategories);
    } else {
      setState(() => categories = ['Other']);
    }
  }

  Future<void> _loadRecurringPayments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final querySnapshot = await _firestore
        .collection('recurring')
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .get();

    final payments = querySnapshot.docs.map((doc) {
      final data = doc.data();
      return RecurringPayment(
        reference: data['description'] ?? '',
        category: data['category'] ?? '',
        term: data['term'] ?? '',
        amount: data['amount'] ?? '',
        startDate: (data['date'] as Timestamp).toDate(),
        documentId: doc.id,
      );
    }).toList();

    setState(() => recurringPayments = payments);
  }

  Future<void> _saveRecurringPaymentToFirestore(RecurringPayment payment) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('recurring').add({
        'amount': payment.amount,
        'category': payment.category,
        'date': Timestamp.fromDate(payment.startDate),
        'description': payment.reference,
        'term': payment.term,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadRecurringPayments(); // Refresh after adding
    } catch (e) {
      print('Error saving payment: $e');
      throw e;
    }
  }

  void _addRecurringPayment() {
    final TextEditingController referenceController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String selectedTerm = '01 month';
    String? selectedCategory;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Recurring Payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: referenceController,
                      decoration: InputDecoration(labelText: 'Description'),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedTerm,
                      items: ['30s (testing)', '01 month', '06 month', '12 months']
                          .map((term) => DropdownMenuItem(
                        value: term,
                        child: Text(term),
                      ))
                          .toList(),
                      onChanged: (String? value) {
                        setState(() => selectedTerm = value!);
                      },
                      decoration: InputDecoration(labelText: 'Term'),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: categories.map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      )).toList(),
                      onChanged: (String? value) {
                        setState(() => selectedCategory = value);
                      },
                      decoration: InputDecoration(
                        labelText: 'Category',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (referenceController.text.isEmpty ||
                        amountController.text.isEmpty ||
                        selectedCategory == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    try {
                      final newPayment = RecurringPayment(
                        reference: referenceController.text,
                        amount: amountController.text,
                        term: selectedTerm,
                        category: selectedCategory!,
                        startDate: DateTime.now(),
                      );

                      await _saveRecurringPaymentToFirestore(newPayment);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Payment added successfully')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add payment: $e')),
                      );
                    }
                  },
                  child: Text('ADD'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRecurringPayment(String documentId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestore.collection('recurring').doc(documentId).delete();
                Navigator.pop(context);
                await _loadRecurringPayments(); // Refresh after deleting
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment deleted successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete payment: $e')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  DateTime _calculateNextPayment(DateTime startDate, String term) {
    if (term == '30s (testing)') {
      return startDate.add(Duration(seconds: 30));
    }

    int monthsToAdd = 1;
    if (term == '06 month') monthsToAdd = 6;
    if (term == '12 months') monthsToAdd = 12;
    return DateTime(startDate.year, startDate.month + monthsToAdd, startDate.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recurring Payments'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _addRecurringPayment,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF006FB9),
                  ),
                  child: Text('ADD RECURRING PAYMENT'),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (_loading)
              Center(child: CircularProgressIndicator()),
            if (!_loading && recurringPayments.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Text(
                    'No recurring payments added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            if (!_loading)
              ...recurringPayments.map((payment) {
                return Card(
                  key: ValueKey(payment.documentId),
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment.reference,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  payment.category,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteRecurringPayment(payment.documentId!),
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Date',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  '${payment.startDate.toLocal().toString().split(' ')[0]}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Next Payment',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  '${_calculateNextPayment(payment.startDate, payment.term).toLocal().toString().split(' ')[0]}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Term',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              payment.term,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              'LKR ${payment.amount}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF006FB9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}