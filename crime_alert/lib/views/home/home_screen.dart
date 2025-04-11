import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crime_alerts_screen.dart';
import 'crime_report_screen.dart';
import 'post_feed_screen.dart';
import 'account_screen.dart';
import 'package:crime_alert/login.dart';

class Dashboard extends StatefulWidget {
  @override
  _Dashboard createState() => _Dashboard();
}

class _Dashboard extends State<Dashboard> {
  int _selectedIndex = 0; // Index of the selected tab

  final List<Widget> _pages = [
    CrimeAlertsScreen(), // Alerts (Accessible to All)
    CrimeReportScreen(),
    PostFeedScreen(),
    AccountScreen(),
  ];

  void _onItemTapped(int index) {
    if (index != 0 && FirebaseAuth.instance.currentUser == null) {
      _showLoginDialog();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: const Text('You need to log in to access this feature.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // Prevents screen rebuild when switching tabs
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
