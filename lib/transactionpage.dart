import 'package:computing_group/analyticspage.dart';
import 'package:computing_group/morepage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'transaction_model.dart'; // Updated import
import 'transaction_service.dart';

class TransactionPage extends StatefulWidget {
  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  TextEditingController _startDateController = TextEditingController();
  TextEditingController _endDateController = TextEditingController();
  final TransactionService _transactionService = TransactionService();
  List<String> selectedCategories = [];

  @override
  void initState() {
    super.initState();
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _startDateController.text = formattedDate;
    _endDateController.text = formattedDate;
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

  void _applyFilter() {
    setState(() {});
  }

  void _showFilterDialog() async {
    List<String> categories = [
      'Income',
      'Expense',
      'Food',
      'Entertainment',
      'Transport'
    ];
    List<String> selectedTemp = List.from(selectedCategories);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Categories'),
          content: SingleChildScrollView(
            child: Column(
              children: categories.map((category) {
                return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return CheckboxListTile(
                      title: Text(category),
                      value: selectedTemp.contains(category),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedTemp.add(category);
                          } else {
                            selectedTemp.remove(category);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  selectedCategories = List.from(selectedTemp);
                });
                Navigator.of(context).pop();
                _applyFilter();
              },
              child: Text('Apply'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateFormat('yyyy-MM-dd').parse(_startDateController.text);
    DateTime endDate = DateFormat('yyyy-MM-dd').parse(_endDateController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextField(
                    controller: _startDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () => _selectDate(context, _startDateController),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _endDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () => _selectDate(context, _endDateController),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: CircleAvatar(
                    backgroundColor: Color(0xFF006FB9),
                    radius: 20,
                    child: Icon(
                      Icons.filter_list,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: _showFilterDialog,
                ),
              ],
            ),
            SizedBox(height: 10),
            StreamBuilder<List<FinancialTransaction>>(  // Updated type here
              stream: _transactionService.getTransactionsByDateRange(startDate, endDate),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data ?? [];
                final filteredTransactions = transactions.where((transaction) {
                  return selectedCategories.isEmpty ||
                      selectedCategories.contains(transaction.category);
                }).toList();

                if (filteredTransactions.isEmpty) {
                  return Center(child: Text('No transactions found'));
                }

                return Column(
                  children: filteredTransactions.map((transaction) {
                    return TransactionCard(
                      transaction.description,
                      'LKR ${transaction.amount.toStringAsFixed(2)}',
                      DateFormat('yyyy-MM-dd').format(transaction.date),
                      transaction.category,
                      transaction.type,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AnalyticsPage()),
            );
          } else if (index == 1) {
            // Already on Transactions page
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MorePage()),
            );
          }
        },
      ),
    );
  }
}

class TransactionCard extends StatelessWidget {
  final String description;
  final String amount;
  final String date;
  final String category;
  final String type;

  TransactionCard(
      this.description, this.amount, this.date, this.category, this.type);

  @override
  Widget build(BuildContext context) {
    bool isExpense = type == 'Expense';

    return Card(
      elevation: 4.0,
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.0),
        title: Text(
          date,
          style: TextStyle(fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (isExpense)
              Text(
                category,
                style: TextStyle(fontSize: 14),
              ),
          ],
        ),
        trailing: Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isExpense ? Colors.red : Colors.black,
          ),
        ),
      ),
    );
  }
}