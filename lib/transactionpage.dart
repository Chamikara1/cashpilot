import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:computing_group/analyticspage.dart';
import 'package:computing_group/morepage.dart';
import 'transaction_model.dart';
import 'transaction_service.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> getCategories() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final doc = await _firestore.collection('category').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['categories'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }
}

class TransactionPage extends StatefulWidget {
  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  TextEditingController _startDateController = TextEditingController();
  TextEditingController _endDateController = TextEditingController();
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
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
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<String>>(
          future: _categoryService.getCategories(),
          builder: (context, snapshot) {
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                title: Text('Loading...'),
                content: Center(child: CircularProgressIndicator()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                ],
              );
            }

            // Error state
            if (snapshot.hasError) {
              return AlertDialog(
                title: Text('Error'),
                content: Text('Failed to load categories'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('OK'),
                  ),
                ],
              );
            }

            // Success state - organize categories
            List<String> allCategories = snapshot.data ?? [];

            // Ensure required categories exist
            const List<String> topCategories = ['Income', 'Expense'];
            const String bottomCategory = 'Other';

            for (var category in topCategories) {
              if (!allCategories.contains(category)) {
                allCategories.add(category);
              }
            }
            if (!allCategories.contains(bottomCategory)) {
              allCategories.add(bottomCategory);
            }

            // Separate and sort middle categories
            List<String> middleCategories = allCategories
                .where((category) => !topCategories.contains(category) && category != bottomCategory)
                .toList()
              ..sort((a, b) => a.compareTo(b));

            // Combine in final order
            List<String> orderedCategories = [
              ...topCategories,
              ...middleCategories,
              bottomCategory,
            ];

            List<String> selectedTemp = List.from(selectedCategories);

            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AlertDialog(
                  title: Text('Select Categories'),
                  content: SingleChildScrollView(
                    child: Column(
                      children: orderedCategories.map((category) {
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
                      }).toList(),
                    ),
                  ),
                  actions: [
                    // Cancel button (now first)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    // Apply button (now second)
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
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showEditTransactionDialog(FinancialTransaction transaction) {
    TextEditingController dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(transaction.date),
    );
    TextEditingController descriptionController = TextEditingController(
      text: transaction.description,
    );
    TextEditingController amountController = TextEditingController(
      text: transaction.amount.toStringAsFixed(2),
    );
    TextEditingController categoryController = TextEditingController(
      text: transaction.category,
    );

    bool isIncome = transaction.type == 'Income';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: transaction.date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          dateController.text =
                              DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                  ),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Reference'),
                ),
                if (!isIncome)
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(labelText: 'Category'),
                  ),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 16),
                // Action buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        FinancialTransaction updatedTransaction = FinancialTransaction(
                          id: transaction.id,
                          userId: transaction.userId,
                          description: descriptionController.text,
                          amount: double.parse(amountController.text),
                          date: DateFormat('yyyy-MM-dd').parse(dateController.text),
                          category: isIncome ? 'Income' : categoryController.text,
                          type: transaction.type,
                        );

                        await _transactionService.updateTransaction(updatedTransaction);
                        Navigator.of(context).pop();
                        setState(() {});
                      },
                      child: Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Full-width delete button at bottom
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () async {
                  bool confirm = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Confirm Delete'),
                      content: Text('Are you sure you want to delete this transaction?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _transactionService.deleteTransaction(transaction.id);
                    Navigator.of(context).pop();
                    setState(() {});
                  }
                },
                child: Text('DELETE TRANSACTION', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate =
    DateFormat('yyyy-MM-dd').parse(_startDateController.text);
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
                        onPressed: () =>
                            _selectDate(context, _startDateController),
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
                        onPressed: () =>
                            _selectDate(context, _endDateController),
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
            StreamBuilder<List<FinancialTransaction>>(
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
                  if (selectedCategories.isEmpty) return true;

                  // Check if either the category matches or the type matches (for Income/Expense)
                  return selectedCategories.any((selected) =>
                  transaction.category == selected ||
                      transaction.type == selected);
                }).toList();

                if (filteredTransactions.isEmpty) {
                  return Center(child: Text('No transactions found'));
                }

                return Column(
                  children: filteredTransactions.map((transaction) {
                    return GestureDetector(
                      onLongPress: () {
                        _showEditTransactionDialog(transaction);
                      },
                      child: TransactionCard(
                        transaction.description,
                        'LKR ${transaction.amount.toStringAsFixed(2)}',
                        DateFormat('yyyy-MM-dd').format(transaction.date),
                        transaction.category,
                        transaction.type,
                      ),
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