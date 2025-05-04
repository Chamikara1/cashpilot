import 'package:computing_group/bankpage.dart';
import 'package:computing_group/categorypage.dart';
import 'package:computing_group/debugpage.dart';
import 'package:computing_group/favoritepage.dart';
import 'package:computing_group/goalspage.dart';
import 'package:computing_group/profilepage.dart';
import 'package:computing_group/recurringpage.dart';
import 'package:computing_group/tipspage.dart';
import 'package:flutter/material.dart';
import 'transactionpage.dart';
import 'analyticspage.dart';
import 'dashboardpage.dart'; // <-- Make sure to import your dashboard page here

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('More'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildRoundedButton(Icons.dashboard, 'Dashboard', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DashboardPage()), // Navigate to Dashboard Page
              );
            }),
            _buildRoundedButton(Icons.person, 'Profile', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
              print('Profile tapped');
            }),
            _buildRoundedButton(Icons.repeat, 'Recurrings', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RecurringPaymentPage()),
              );
              print('Recurrings tapped');
            }),
            _buildRoundedButton(Icons.favorite, 'Favorites', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritePage()),
              );
              print('Favorites tapped');
            }),
            _buildRoundedButton(Icons.account_balance_wallet, 'Set Budgets', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GoalPage()),
              );
              print('Goals tapped');
            }),
            _buildRoundedButton(Icons.account_balance, 'Bank', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BankPage()),
              );
              print('Bank tapped');
            }),
            _buildRoundedButton(Icons.category, 'Categories', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CategoryPage()),
              );
              print('Bank tapped');
            }),
            _buildRoundedButton(Icons.tips_and_updates, 'Suggestions', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TipsPage()),
              );
              print('Tips! tapped');
            }),
            /*_buildRoundedButton(Icons.bug_report, 'Debug', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DebugPage()), // Navigate to Dashboard Page
              );
            }),*/
          ],
        ),
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
          currentIndex: 2,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Transactions'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AnalyticsPage()),
              );
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => TransactionPage()),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildRoundedButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF006FB9),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
