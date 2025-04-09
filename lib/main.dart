import 'package:flutter/material.dart';
import 'login_page_new.dart';
import 'signuppage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login/Sign In',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(450.0), // AppBar height
        child: ClipPath(
          clipper: BottomCurveClipper(),
          child: AppBar(
            backgroundColor: Color(0xFF006FB9),
            flexibleSpace: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Moves text down
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 50.0), // Adjust spacing
                  child: Text(
                    'Welcome.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
        ),
      ),
      backgroundColor: Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 200, // Set button width
              height: 60, // Set button height
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  ); // Perform login action
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF006FB9), // Button background color
                  foregroundColor: Colors.white, // Button text color
                ),
                child: Text(
                  'Log In',
                  style: TextStyle(fontSize: 30),
                ),
              ),
            ),
            SizedBox(height: 20), // Add spacing between buttons
            SizedBox(
              width: 200, // Set button width
              height: 60, // Set button height
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpPage()),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFF006FB9), // Button background color
                  foregroundColor: Colors.white, // Button text color
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, 0);
    path.lineTo(0, size.height - 80); // Extend the curve downward
    path.quadraticBezierTo(size.width / 2, size.height + 40, size.width,
        size.height - 80); // Increased curve height
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}
