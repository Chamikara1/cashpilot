import 'package:computing_group/morepage.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'transactionpage.dart';

class AnalyticsPage extends StatefulWidget {
  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  double income = 5000;
  double expense = 3000;

  late AnimationController _controller;
  late Animation<double> _animation;

  final List<String> categories = ['Food', 'Transport', 'Entertainment', 'Bills', 'Other'];
  final List<double> categoryExpenses = [1200, 800, 400, 500, 100];

  late PageController _pageController;
  final List<Color> categoryColors = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Generate consistent, distinct colors for each category
    final random = Random();
    final Set<Color> usedColors = {};
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

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _animation = Tween<double>(begin: 0, end: progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
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
        title: Text('Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        children: [
          // Income Page
          SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: 20),
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
                          Text('Income', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                                    child: Text(
                                      '\$${income.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

          // Categories Page (Ring inside Card)
          SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: 20),
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
                          Text('Categories', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 30),
                          SizedBox(
                            height: 300,
                            width: 300,
                            child: CustomPaint(
                              painter: CategoryRingPainter(categoryExpenses, categoryColors),
                              child: Center(
                                child: Text(
                                  '\$${expense.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  ...categories.asMap().entries.map((entry) {
                    int index = entry.key;
                    String category = entry.value;
                    double percent = categoryExpenses[index] / expense * 100;
                    return DotIndicator(
                      color: categoryColors[index],
                      label: category,
                      percent: percent,
                    );
                  }).toList(),
                  SizedBox(height: 50),
                ],
              ),
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

// Painter for overall income ring
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

// Painter for categories ring
class CategoryRingPainter extends CustomPainter {
  final List<double> expenses;
  final List<Color> colors;

  CategoryRingPainter(this.expenses, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = expenses.fold(0.0, (a, b) => a + b);
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

// Reusable Dot Indicator
class DotIndicator extends StatelessWidget {
  final Color color;
  final String label;
  final double percent;

  const DotIndicator({
    required this.color,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 75, vertical: 5),
      child: Row(
        children: [
          Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Spacer(),
          Text('${percent.toStringAsFixed(0)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
