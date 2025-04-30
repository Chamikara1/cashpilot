import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Transaction model remains unchanged
class Transaction {
  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final String userId;

  Transaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.userId,
  });

  static Transaction fromMap(String id, Map<String, dynamic> map) {
    print('Parsing transaction: $map');
    final date = map['date'] is Timestamp
        ? (map['date'] as Timestamp).toDate()
        : DateTime.now();
    print('Transaction date: $date');

    return Transaction(
      id: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? '',
      date: date,
      userId: map['userId'] as String? ?? '',
    );
  }
}

// TransactionService, CategoryService, Goal, GoalService classes remain unchanged
class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Transaction>> getTransactionsForGoal(Goal goal) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in when fetching transactions');
        return [];
      }

      print('Fetching transactions for goal: ${goal.name}, category: ${goal.category}');
      print('Date range: ${goal.createdAt} to ${goal.dueDate}');

      final querySnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .where('category', isEqualTo: goal.category)
          .get();

      print('Found ${querySnapshot.docs.length} transactions for category ${goal.category}');

      final filteredTransactions = querySnapshot.docs
          .map((doc) => Transaction.fromMap(doc.id, doc.data()))
          .where((transaction) {
        return transaction.date.isAfter(goal.createdAt) &&
            transaction.date.isBefore(goal.dueDate.add(Duration(days: 1)));
      })
          .toList();

      print('After date filtering: ${filteredTransactions.length} transactions within date range');
      filteredTransactions.forEach((t) => print('Transaction: ${t.amount} on ${t.date}'));

      return filteredTransactions;
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSpentDataForGoal(Goal goal) async {
    final transactions = await getTransactionsForGoal(goal);
    double totalSpent = 0;

    for (var transaction in transactions) {
      totalSpent += transaction.amount;
    }

    print('Total spent for ${goal.name}: $totalSpent');
    return {
      'totalSpent': totalSpent,
      'transactions': transactions,
    };
  }
}

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<String>> getCategories() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in when fetching categories');
        return [];
      }

      print('Fetching categories for user: ${user.uid}');
      final doc = await _firestore.collection('category').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        final categories = List<String>.from(doc.data()!['categories'] as List? ?? []);
        print('Found categories: $categories');
        return categories;
      }
      print('No categories found for user');
      return [];
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<void> addCategory(String categoryName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in when adding category');
        return;
      }

      print('Adding category "$categoryName" for user: ${user.uid}');
      final userDoc = _firestore.collection('category').doc(user.uid);

      await userDoc.set({
        'userId': user.uid,
        'categories': FieldValue.arrayUnion([categoryName]),
      }, SetOptions(merge: true));

      print('Category added successfully');
    } catch (e) {
      print('Error adding category: $e');
      throw e;
    }
  }
}

class Goal {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final String category;
  final DateTime createdAt;

  Goal({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
    };
  }

  static Goal fromMap(String id, Map<String, dynamic> map) {
    return Goal(
      id: id,
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      category: map['category'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class GoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Goal>> getGoals() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in when fetching goals');
        return [];
      }

      print('Fetching goals for user: ${user.uid}');
      final querySnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${querySnapshot.docs.length} goals');
      return querySnapshot.docs
          .map((doc) {
        print('Goal document: ${doc.data()}');
        return Goal.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      })
          .toList();
    } catch (e) {
      print('Error fetching goals: $e');
      return [];
    }
  }

  Future<void> addGoal(Goal goal) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in when adding goal');
        return;
      }

      print('Adding goal: ${goal.name}');
      final goalMap = goal.toMap();
      print('Goal data: $goalMap');

      await _firestore.collection('goals').add(goalMap);
      print('Goal added successfully');
    } catch (e) {
      print('Error adding goal: $e');
      throw e;
    }
  }

  Future<void> deleteGoal(String goalId) async {
    try {
      print('Deleting goal with ID: $goalId');
      await _firestore.collection('goals').doc(goalId).delete();
      print('Goal deleted successfully');
    } catch (e) {
      print('Error deleting goal: $e');
      throw e;
    }
  }
}

class GoalPage extends StatefulWidget {
  @override
  _GoalPageState createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  List<Goal> goals = [];
  final CategoryService _categoryService = CategoryService();
  final GoalService _goalService = GoalService();
  final TransactionService _transactionService = TransactionService();
  List<String> categories = [];
  String selectedCategory = '';
  bool isLoading = true;
  Map<String, double> goalProgress = {};
  Map<String, double> spentAmounts = {};

  @override
  void initState() {
    super.initState();
    print('Initializing GoalPage');
    _loadData();
  }

  Future<void> _loadData() async {
    print('Loading data...');
    setState(() {
      isLoading = true;
    });

    try {
      final results = await Future.wait([
        _categoryService.getCategories(),
        _goalService.getGoals(),
      ]);

      final loadedCategories = results[0] as List<String>;
      final loadedGoals = results[1] as List<Goal>;

      print('Data loaded - Categories: ${loadedCategories.length}, Goals: ${loadedGoals.length}');

      // Calculate progress for each goal with better logging
      Map<String, double> progress = {};
      Map<String, double> spentAmounts = {};
      for (var goal in loadedGoals) {
        print('Calculating progress for goal: ${goal.name}');
        print('Category: ${goal.category}, Date range: ${goal.createdAt} to ${goal.dueDate}');

        final spentData = await _transactionService.getSpentDataForGoal(goal);
        final spent = spentData['totalSpent'] as double;
        spentAmounts[goal.id] = spent;

        // Calculate progress as a percentage, without clamping the upper limit
        // This allows percentages above 100%
        double progressPercent = spent / goal.amount;
        progress[goal.id] = progressPercent;
        print('Progress percentage: ${(progressPercent * 100).toStringAsFixed(1)}%');
      }

      setState(() {
        categories = loadedCategories;
        if (categories.isNotEmpty) {
          selectedCategory = categories.first;
        } else {
          selectedCategory = '';
        }
        goals = loadedGoals;
        goalProgress = progress;
        this.spentAmounts = spentAmounts;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  void _addGoal() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Set New Budget'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Budget Name'),
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Amount'),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          selectedDate == null
                              ? 'Track Until'
                              : 'Due: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}',
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.calendar_today),
                          onPressed: () async {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              setDialogState(() {
                                selectedDate = pickedDate;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    isLoading
                        ? CircularProgressIndicator()
                        : DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCategory.isNotEmpty ? selectedCategory : null,
                      hint: Text('Select Category'),
                      onChanged: (String? newValue) {
                        if (newValue == 'Create New') {
                          _showCreateCategoryDialog(setDialogState);
                        } else if (newValue != null) {
                          setDialogState(() {
                            selectedCategory = newValue;
                          });
                        }
                      },
                      items: [
                        ...categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        DropdownMenuItem<String>(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Create New',
                          child: Text('Create New Category'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a Budget name')),
                      );
                      return;
                    }

                    if (amountController.text.isEmpty || double.tryParse(amountController.text) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }

                    if (selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a due date')),
                      );
                      return;
                    }

                    if (selectedCategory.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a category')),
                      );
                      return;
                    }

                    try {
                      print('Attempting to add new Budget...');
                      final newGoal = Goal(
                        id: '',
                        name: nameController.text,
                        amount: double.parse(amountController.text),
                        dueDate: selectedDate!,
                        category: selectedCategory,
                        createdAt: DateTime.now(),
                      );

                      await _goalService.addGoal(newGoal);
                      Navigator.of(context).pop();
                      await _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Budget added successfully!')),
                      );
                    } catch (e) {
                      print('Error adding goal: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add budget: $e')),
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

  void _showCreateCategoryDialog(StateSetter setDialogState) {
    final TextEditingController categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create New Category'),
          content: TextField(
            controller: categoryController,
            decoration: InputDecoration(
              labelText: 'Category Name',
              hintText: 'Enter new category name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (categoryController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a category name')),
                  );
                  return;
                }

                try {
                  print('Creating new category: ${categoryController.text}');
                  await _categoryService.addCategory(categoryController.text);
                  setDialogState(() {
                    selectedCategory = categoryController.text;
                    if (!categories.contains(selectedCategory)) {
                      categories.add(selectedCategory);
                    }
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Category created successfully!')),
                  );
                } catch (e) {
                  print('Error creating category: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create category: $e')),
                  );
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _deleteGoal(String goalId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this budget?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _goalService.deleteGoal(goalId);
                  Navigator.of(context).pop();
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Budget deleted successfully!')),
                  );
                } catch (e) {
                  print('Error deleting goal: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete budget: $e')),
                  );
                }
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building GoalPage with ${goals.length} goals');
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Budgets'),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _addGoal,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Color(0xFF006FB9),
                    ),
                    child: Text('ADD'),
                  ),
                ],
              ),
              SizedBox(height: 10),
              if (goals.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'No budgets added yet',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ...goals.map((goal) {
                return GoalCard(
                  goal: goal,
                  progress: goalProgress[goal.id] ?? 0.0,
                  spentAmount: spentAmounts[goal.id] ?? 0.0,
                  onDelete: () => _deleteGoal(goal.id),
                  onViewDetails: () => _showTransactionDetails(goal),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(Goal goal) async {
    setState(() {
      isLoading = true;
    });

    try {
      final transactions = await _transactionService.getTransactionsForGoal(goal);
      setState(() {
        isLoading = false;
      });

      if (transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No transactions found for this budget')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Transactions for ${goal.name}'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return ListTile(
                    title: Text('LKR ${transaction.amount.toStringAsFixed(2)}'),
                    subtitle: Text('${DateFormat('yyyy-MM-dd').format(transaction.date)}'),
                    trailing: Text(transaction.category),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    }
  }
}

class GoalCard extends StatelessWidget {
  final Goal goal;
  final double progress;
  final double spentAmount;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  GoalCard({
    required this.goal,
    required this.progress,
    required this.spentAmount,
    required this.onDelete,
    required this.onViewDetails,
  });

  int getDaysRemaining() {
    return goal.dueDate.difference(DateTime.now()).inDays;
  }

  double getAmountLeft() {
    return (goal.amount - spentAmount).clamp(0, goal.amount);
  }

  Color getProgressColor(BuildContext context) {
    if (progress >= 1.0) {
      return Colors.red;
    } else if (progress >= 0.75) {
      return Colors.orange;
    } else {
      return Color(0xFF006FB9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysRemaining = getDaysRemaining();
    final amountLeft = getAmountLeft();

    // For display purposes, we'll clamp the progress bar value to 1.0 max
    // but still show the actual percentage in text
    final displayProgress = progress.clamp(0.0, 1.0);

    return Card(
      elevation: 4.0,
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$daysRemaining days left',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
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
                  'Category: ${goal.category}',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  'LKR ${goal.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16),
                SizedBox(width: 4),
                Text(
                  'Track Until: ${DateFormat('yyyy-MM-dd').format(goal.dueDate)}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: displayProgress, // Clamp for visual display only
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            getProgressColor(context)
                        ),
                        minHeight: 8,
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Spent: LKR ${spentAmount.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Remaining: LKR ${amountLeft.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%', // This will show values above 100%
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: progress >= 1.0 ? Colors.red : null, // Highlight if over budget
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text('Details', style: TextStyle(fontSize: 12)),
                  onPressed: onViewDetails,
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}