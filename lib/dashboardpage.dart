import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:computing_group/analyticspage.dart';
import 'package:computing_group/favoritepage.dart';
import 'package:computing_group/morepage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'transactionpage.dart';
import 'notificationspage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'transaction_model.dart';
import 'transaction_service.dart';
import 'sms_service.dart';
import 'package:badges/badges.dart' as badges;
import 'dart:async';
import 'main.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _incomeDateController = TextEditingController();
  final TextEditingController _incomeReferenceController =
  TextEditingController();
  final TextEditingController _incomeAmountController = TextEditingController();

  final TextEditingController _expenseDateController = TextEditingController();
  final TextEditingController _expenseReferenceController =
  TextEditingController();
  final TextEditingController _expenseAmountController =
  TextEditingController();

  final TransactionService _transactionService = TransactionService();
  final SmsService _smsService = SmsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCategory;
  List<String> _userCategories = [];
  bool _loadingCategories = true;
  bool _hasNotifications = false;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _incomeDateController.text = formattedDate;
    _expenseDateController.text = formattedDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _smsService.fetchAndStoreBankMessages();
    });

    _loadUserCategories();
    _setupNotificationsListener();
  }

  void _setupNotificationsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationsSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _hasNotifications = snapshot.docs.isNotEmpty;
      });
    });
  }

  Future<void> _loadUserCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingCategories = false);
      return;
    }

    try {
      final doc = await _firestore.collection('category').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _userCategories = List<String>.from(doc.data()!['categories'] ?? []);
          _loadingCategories = false;
        });
      } else {
        setState(() {
          _userCategories = [];
          _loadingCategories = false;
        });
      }
    } catch (e) {
      setState(() => _loadingCategories = false);
      print('Error loading categories: $e');
    }
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _addIncome() async {
    if (_incomeReferenceController.text.isEmpty ||
        _incomeAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final transaction = FinancialTransaction(
        id: '',
        description: _incomeReferenceController.text,
        amount: double.parse(_incomeAmountController.text),
        date: DateFormat('yyyy-MM-dd').parse(_incomeDateController.text),
        category: 'Income',
        type: 'Income',
        userId: userId,
      );

      await _transactionService.addTransaction(transaction);

      _incomeReferenceController.clear();
      _incomeAmountController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Income added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding income: $e')),
      );
    }
  }

  Future<void> _addExpense() async {
    if (_expenseReferenceController.text.isEmpty ||
        _expenseAmountController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final transaction = FinancialTransaction(
        id: '',
        description: _expenseReferenceController.text,
        amount: double.parse(_expenseAmountController.text),
        date: DateFormat('yyyy-MM-dd').parse(_expenseDateController.text),
        category: _selectedCategory!,
        type: 'Expense',
        userId: userId,
      );

      await _transactionService.addTransaction(transaction);

      _expenseReferenceController.clear();
      _expenseAmountController.clear();
      setState(() => _selectedCategory = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expense added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding expense: $e')),
      );
    }
  }

  Future<String?> _promptForNewCategory(BuildContext context) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Category'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Category Name',
            hintText: 'Enter a name for your new category',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      // Sign out from Google if signed in with Google
      await _googleSignIn.signOut();

      // Sign out from Firebase
      await _auth.signOut();

      // Navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'User';

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hello! $userName',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF006FB9),
                        ),
                      ),
                      IconButton(
                        icon: _hasNotifications
                            ? badges.Badge(
                          badgeStyle: badges.BadgeStyle(
                            badgeColor: Colors.red,
                          ),
                          position: badges.BadgePosition.topEnd(
                              top: -5, end: -5),
                          child: Icon(Icons.notifications,
                              color: Color(0xFF006FB9)),
                        )
                            : Icon(Icons.notifications,
                            color: Color(0xFF006FB9)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => NotificationsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 75),

                  // Income Section
                  Center(
                    child: Text(
                      'Add Income',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _incomeDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () =>
                            _selectDate(context, _incomeDateController),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _incomeReferenceController,
                    decoration: InputDecoration(labelText: 'Reference'),
                  ),
                  TextField(
                    controller: _incomeAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Amount'),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: _addIncome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF006FB9),
                      ),
                      child: Text('ADD', style: TextStyle(color: Colors.white)),
                    ),
                  ),

                  SizedBox(height: 50),

                  // Expense Section
                  Center(
                    child: Text(
                      'Add Expenses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _expenseDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () =>
                            _selectDate(context, _expenseDateController),
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: [
                      ..._userCategories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      )),
                      DropdownMenuItem(
                        value: 'Other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: _loadingCategories
                          ? 'Loading categories...'
                          : 'Select a category',
                    ),
                  ),
                  TextField(
                    controller: _expenseReferenceController,
                    decoration: InputDecoration(labelText: 'Reference'),
                  ),
                  TextField(
                    controller: _expenseAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Amount'),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: ElevatedButton(
                      onPressed: _addExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF006FB9),
                      ),
                      child: Text('ADD', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Navigation
          Container(
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1)),
              color: Colors.white,
            ),
            child: BottomNavigationBar(
              backgroundColor: Color(0xFF006FB9),
              elevation: 10,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_outlined),
                  label: 'Analytics',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.monetization_on),
                  label: 'Transactions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
              onTap: (index) {
                if (index == 0) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => AnalyticsPage()));
                } else if (index == 1) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TransactionPage()));
                } else if (index == 2) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => MorePage()));
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
            bottom: 60.0), // Adjust this value to position above bottom bar
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FavoritePage()),
            );
            // Add your favorite button action here
          },
          backgroundColor: Color(0xFF006FB9),
          child: Icon(Icons.favorite, color: Colors.white),
          elevation: 4.0,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _incomeDateController.dispose();
    _incomeReferenceController.dispose();
    _incomeAmountController.dispose();
    _expenseDateController.dispose();
    _expenseReferenceController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }
}