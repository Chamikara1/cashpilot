import 'package:computing_group/favoritepage.dart';
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
        title: Text('Hello! User'),
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
              print('Profile tapped');
            }),
            _buildRoundedButton(Icons.repeat, 'Recurrings', () {
              print('Recurrings tapped');
            }),
            _buildRoundedButton(Icons.favorite, 'Favorites', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritePage()), // Navigate to Dashboard Page
              );
              print('Favorites tapped');
            }),
            _buildRoundedButton(Icons.flag, 'Goals', () {
              print('Goals tapped');
            }),
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
