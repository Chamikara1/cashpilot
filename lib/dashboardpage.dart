import 'package:computing_group/analyticspage.dart';
import 'package:computing_group/morepage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'transactionpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'transaction_model.dart';
import 'transaction_service.dart';
import 'sms_service.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _incomeDateController = TextEditingController();
  final TextEditingController _incomeReferenceController = TextEditingController();
  final TextEditingController _incomeAmountController = TextEditingController();

  final TextEditingController _expenseDateController = TextEditingController();
  final TextEditingController _expenseReferenceController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();

  final TransactionService _transactionService = TransactionService();
  final SmsService _smsService = SmsService();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Auto-fill the current date when the page loads
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _incomeDateController.text = formattedDate;
    _expenseDateController.text = formattedDate;

    // Fetch and store SMS messages after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _smsService.fetchAndStoreBankMessages();
    });
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
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
    if (_incomeReferenceController.text.isEmpty || _incomeAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final transaction = Transaction(
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

      final transaction = Transaction(
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

  @override
  Widget build(BuildContext context) {
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
                  Center(
                    child: Text(
                      'Hello! User',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006FB9),
                      ),
                    ),
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
                        onPressed: () => _selectDate(context, _incomeDateController),
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
                        onPressed: () => _selectDate(context, _expenseDateController),
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: ['Food', 'Transport', 'Bills', 'Shopping'].map((String category) {
                      return DropdownMenuItem(value: category, child: Text(category));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value),
                    decoration: InputDecoration(labelText: 'Category'),
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
              border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
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
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyticsPage()));
                } else if (index == 1) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionPage()));
                } else if (index == 2) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MorePage()));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _incomeDateController.dispose();
    _incomeReferenceController.dispose();
    _incomeAmountController.dispose();
    _expenseDateController.dispose();
    _expenseReferenceController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }
}