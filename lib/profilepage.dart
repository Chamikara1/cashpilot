import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';

class ProfilePage extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _handleLogout(BuildContext context) async {
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

  void _showFeatureUnderDevelopmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Coming Soon'),
          content: Text('Sorry; this feature is currently under development. :(\n\nFor inquiries, please contact cashpilotdevs@gmail.com.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'User';
    final userEmail = user?.email ?? 'No email';
    final userPhotoUrl = user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 30),
            CircleAvatar(
              radius: 60,
              backgroundImage: userPhotoUrl != null
                  ? NetworkImage(userPhotoUrl)
                  : AssetImage('assets/default_profile.png') as ImageProvider,
              backgroundColor: Colors.grey[200],
            ),
            SizedBox(height: 20),
            Text(
              userName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              userEmail,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 40),
            ListTile(
              leading: Icon(Icons.person, color: Color(0xFF006FB9)),
              title: Text('Edit Profile'),
              onTap: () {
                _showFeatureUnderDevelopmentDialog(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.settings, color: Color(0xFF006FB9)),
              title: Text('Settings'),
              onTap: () {
                _showFeatureUnderDevelopmentDialog(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.help, color: Color(0xFF006FB9)),
              title: Text('Help & Support'),
              onTap: () {
                _showFeatureUnderDevelopmentDialog(context);
              },
            ),
            Divider(),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _handleLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}