import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'transactionpage.dart';
import 'package:computing_group/morepage.dart';
import 'package:firebase_auth/firebase_auth.dart';

// LKR Currency Formatter
String formatLKR(double amount) {
  // Handle null or invalid amounts
  if (amount == null || amount.isNaN) {
    return 'LKR 0.00';
  }

  // Format the number with commas as thousand separators
  final parts = amount.toStringAsFixed(2).split('.');
  final integerPart = parts[0];
  final decimalPart = parts.length > 1 ? parts[1] : '00';

  final formattedInteger = integerPart.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
  );

  return 'LKR $formattedInteger.$decimalPart';
}

class AnalyticsPage extends StatefulWidget {
  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  double income = 0;
  double expense = 0;
  Map<String, double> categoryExpensesMap = {};
  List<String> categories = [];
  List<double> categoryExpenses = [];
  List<Color> categoryColors = [];

  DateTime? _startDate;
  DateTime? _endDate;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  late AnimationController _controller;
  late Animation<double> _animation;
  late PageController _pageController;

  // Get current user ID
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize with default dates (current month)
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Check if user is logged in before fetching data
    if (currentUserId != null) {
      _fetchTransactionData();
    } else {
      setState(() {
        isLoading = false;
        errorMessage = "Please log in to view your analytics";
      });
    }
  }

  Future<void> _fetchTransactionData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Create base query for the current user's transactions only
      Query query = FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: currentUserId);

      // Add date range filter if dates are selected
      if (_startDate != null && _endDate != null) {
        // Create a timestamp for Firestore filtering
        final startTimestamp = Timestamp.fromDate(_startDate!);
        final endTimestamp = Timestamp.fromDate(_endDate!.add(Duration(days: 1)).subtract(Duration(milliseconds: 1)));

        query = query
            .where('date', isGreaterThanOrEqualTo: startTimestamp)
            .where('date', isLessThanOrEqualTo: endTimestamp);
      }

      final querySnapshot = await query.get();

      double totalIncome = 0;
      double totalExpense = 0;
      Map<String, double> tempCategoryExpenses = {};

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = data['amount']?.toDouble() ?? 0;
        final type = data['type'] as String? ?? '';
        final category = data['category'] as String? ?? 'Other';

        if (type.toLowerCase() == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
          tempCategoryExpenses[category] = (tempCategoryExpenses[category] ?? 0) + amount;
        }
      }

      var sortedEntries = tempCategoryExpenses.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        isLoading = false;
        income = totalIncome;
        expense = totalExpense;
        categoryExpensesMap = Map.fromEntries(sortedEntries);
        categories = categoryExpensesMap.keys.toList();
        categoryExpenses = categoryExpensesMap.values.toList();

        final random = Random();
        final Set<Color> usedColors = {};
        categoryColors = [];
        for (int i = 0; i < categories.length; i++) {
          Color newColor;
          do {
            newColor = Color.fromRGBO(
              random.nextInt(200) + 30,
              random.nextInt(200) + 30,
              random.nextInt(200) + 30,
              1,
            );
          } while (usedColors.contains(newColor));
          categoryColors.add(newColor);
          usedColors.add(newColor);
        }

        double progress = (income == 0) ? 0 : (expense / income);
        _animation = Tween<double>(begin: 0, end: progress).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        );
        _controller.forward(from: 0); // Reset animation before forward
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error fetching transactions: ${e.toString()}";
      });
      print('Error fetching transactions: $e');
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchTransactionData();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double expensePercentage = (income == 0) ? 0 : (expense / income) * 100;
    double balancePercentage = 100 - expensePercentage;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('My Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: currentUserId == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 70, color: Colors.grey),
            SizedBox(height: 20),
            Text('Please log in to view your analytics',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Navigate to login page
                // Replace with your actual login page route
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: Text('Go to Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF006FB9),
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ],
        ),
      )
          : isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: TextStyle(color: Colors.red)))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => _selectDateRange(context),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        _startDate != null ? _dateFormat.format(_startDate!) : 'Start Date',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                Text('to', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () => _selectDateRange(context),
                  child: Row(
                    children: [
                      Text(
                        _endDate != null ? _dateFormat.format(_endDate!) : 'End Date',
                        style: TextStyle(color: Colors.blue),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                            child: Column(
                              children: [
                                Text('My Income', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                SizedBox(height: 30),
                                SizedBox(
                                  height: 300,
                                  width: 300,
                                  child: AnimatedBuilder(
                                    animation: _animation,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: CircularProgressPainter(_animation.value),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                formatLKR(income),
                                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                              ),
                                              SizedBox(height: 10),
                                              Text(
                                                'Expense: ${formatLKR(expense)}',
                                                style: TextStyle(fontSize: 16, color: Colors.grey),
                                              ),
                                              SizedBox(height: 10),
                                              if (_startDate != null && _endDate != null)
                                                Text(
                                                  '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}',
                                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        DotIndicator(color: Color(0xFF006FB9), label: 'Expense', percent: expensePercentage),
                        SizedBox(height: 15),
                        DotIndicator(color: Color(0xFFD8D8D8), label: 'Balance', percent: balancePercentage),
                        SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),

                SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                            child: Column(
                              children: [
                                Text('My Categories', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                SizedBox(height: 30),
                                SizedBox(
                                  height: 300,
                                  width: 300,
                                  child: categoryExpenses.isEmpty
                                      ? Center(child: Text('No expense data'))
                                      : CustomPaint(
                                    painter: CategoryRingPainter(categoryExpenses, categoryColors),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            formatLKR(expense),
                                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            '${categories.length} categories',
                                            style: TextStyle(fontSize: 16, color: Colors.grey),
                                          ),
                                          if (_startDate != null && _endDate != null)
                                            Text(
                                              '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}',
                                              style: TextStyle(fontSize: 14, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        if (categoryExpenses.isNotEmpty)
                          ...categories.asMap().entries.map((entry) {
                            int index = entry.key;
                            String category = entry.value;
                            double percent = categoryExpenses[index] / expense * 100;
                            return DotIndicator(
                              color: categoryColors[index],
                              label: category,
                              percent: percent,
                              amount: categoryExpenses[index],
                            );
                          }).toList(),
                        if (categoryExpenses.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No expense categories found', style: TextStyle(fontSize: 16)),
                          ),
                        SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
          color: Colors.white,
        ),
        child: BottomNavigationBar(
          backgroundColor: Color(0xFF006FB9),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white,
          currentIndex: 0,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Transactions'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
          onTap: (index) {
            if (index == 1) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionPage()));
            } else if (index == 2) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MorePage()));
              print("More Clicked");
            }
          },
        ),
      ),
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  CircularProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    Paint base = Paint()
      ..color = Color(0xFFD8D8D8)
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke;

    Paint arc = Paint()
      ..color = Color(0xFF006FB9)
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(size.center(Offset.zero), size.width / 2, base);

    double angle = 2 * pi * progress;
    canvas.drawArc(Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2),
        -pi / 2, angle, false, arc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CategoryRingPainter extends CustomPainter {
  final List<double> expenses;
  final List<Color> colors;

  CategoryRingPainter(this.expenses, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = expenses.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    double startAngle = -pi / 2;
    final radius = size.width / 2;

    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.butt;

    for (int i = 0; i < expenses.length; i++) {
      final sweepAngle = (expenses[i] / total) * 2 * pi;
      paint.color = colors[i];
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class DotIndicator extends StatelessWidget {
  final Color color;
  final String label;
  final double percent;
  final double? amount;

  const DotIndicator({
    required this.color,
    required this.label,
    required this.percent,
    this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
      child: Row(
        children: [
          Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 12),
          Expanded(
            child: Text(label,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10),
          if (amount != null)
            Text(formatLKR(amount!),
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          SizedBox(width: 10),
          Text('${percent.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}