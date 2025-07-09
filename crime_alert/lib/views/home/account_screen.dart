import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:crime_alert/views/home/edit_profile_screen.dart';
import 'package:crime_alert/views/home/edit_sos_screen.dart';
import 'package:crime_alert/services/cloudinary_service.dart';
import 'package:crime_alert/services/feedback_service.dart';
import 'package:crime_alert/views/home/home_screen.dart';

class AccountScreen extends StatefulWidget {
  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  String? imageURL;
  bool sosEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final User? authUser = _auth.currentUser;
      if (authUser == null) throw Exception('No authenticated user');

      final doc = await _firestore.collection('users').doc(authUser.uid).get();
      if (!doc.exists) throw Exception('User document not found');

      setState(() {
        userData = doc.data();
        imageURL = userData?['imageURL'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateProfileImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final imageUrl = await CloudinaryService.uploadImage(
          File(pickedFile.path), "profiles/${_auth.currentUser?.uid}");

      if (imageUrl != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .update({
          'imageURL': imageUrl,
        });
        setState(() => imageURL = imageUrl);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile image')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<QueryDocumentSnapshot>> _getUserCrimeReports() async {
    try {
      final userId = _auth.currentUser?.uid;
      print('Current user UID: $userId');

      final querySnapshot = await _firestore
          .collection('crime_reports')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      print('Found ${querySnapshot.docs.length} reports');
      return querySnapshot.docs;
    } catch (e) {
      print('Query error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading reports. Try again.')),
      );
      return [];
    }
  }

  Future<void> _sendFeedback(String message) async {
    try {
      await FeedbackService.sendFeedback(message);
      _showThankYouDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send feedback.")),
      );
    }
  }


  void _showLogoutConfirmation(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Confirm Logout"),
        content: Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
            },
          ),
          TextButton(
            child: Text("Logout"),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _logout(); // Call actual logout
            },
          ),
        ],
      );
    },
  );
}


  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    // Clear user-specific screen state if needed

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => Dashboard()),
      (Route<dynamic> route) => false,
    );
  }

  void _showThankYouDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("We appreciate your feedback!"),
        content: Text("Thank you for helping us improve."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _openFeedbackForm() {
    final TextEditingController _feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Feedback'),
        content: TextField(
          controller: _feedbackController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Write your feedback here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close form
              await _sendFeedback(_feedbackController.text);
            },
            child: Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showCrimeReportsDialog(List<QueryDocumentSnapshot> reports) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Your Crime Reports'),
        content: reports.isEmpty
            ? Text('No crime reports found')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report =
                        reports[index].data() as Map<String, dynamic>;
                    final date = (report['timestamp'] as Timestamp).toDate();

                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['crimeType'] ?? 'Unknown Crime',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 8),
                            _buildReportDetail(
                                '📍 Location:', report['location']),
                            _buildReportDetail('📅 Date:',
                                DateFormat('dd MMM yyyy').format(date)),
                            _buildReportDetail('🕒 Time:', report['time']),
                            if (report['description'] != null)
                              _buildReportDetail(
                                  '📝 Description:', report['description']),
                            if (report['identity'] != null)
                              _buildReportDetail(
                                  '👤 Your Role:', report['identity']),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetail(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value ?? 'Not specified'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
      title: Text('Account'),
      backgroundColor: Colors.red,
    ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_auth.currentUser == null || userData == null) {
      return Scaffold(
        appBar: AppBar(
           backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Profile data not available'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadUserData,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Account'),
        backgroundColor: Colors.red,
        actions: [
        IconButton(
          icon: Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () => _showLogoutConfirmation(context),
        ),
      ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(),
              _buildSectionHeader('General'),
              _buildListTile(Icons.help_outline, 'Help Center', () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Help Center'),
                    content: SingleChildScrollView(
                      child: ListBody(
                        children: [
                          Text(
                              "• Tap 'Your Crime Reports' to view your submissions."),
                          Text(
                              "• Use 'SOS Message' to manage emergency contacts."),
                          Text("• Update profile photo by tapping your image."),
                          Text("• Contact support via 'Send Feedback'."),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child:
                            Text('Close', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }),
              _buildListTile(Icons.feed, 'Your Post Feed', () {}),
              _buildListTile(Icons.report, 'Your Crime Reports', () async {
                final reports = await _getUserCrimeReports();
                _showCrimeReportsDialog(reports);
              }),
              _buildListTile(
                  Icons.feedback, 'Send Feedback', _openFeedbackForm),
              _buildSectionHeader('SOS Message'),
              _buildSOSSettings(),
              _buildSectionHeader('Emergency Contacts'),
              _buildListTile(Icons.contacts, 'Add Emergency Contacts', () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _updateProfileImage,
            child: CircleAvatar(
              radius: 40,
              backgroundImage: _getProfileImage(),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${userData?['firstName'] ?? 'First'} ${userData?['lastName'] ?? 'Last'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _auth.currentUser?.email ?? 'No email',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 8),
                _buildEditProfileButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _getProfileImage() {
    if (imageURL != null && imageURL!.isNotEmpty) {
      return NetworkImage(imageURL!);
    }
    return AssetImage('assets/images/default_avatar.png');
  }

  Widget _buildEditProfileButton() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditProfileScreen(userId: _auth.currentUser!.uid),
        ),
      ).then((_) => _loadUserData()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      width: double.infinity,
      color: Colors.grey[200],
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black54),
      title: Text(title),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSOSSettings() {
    return Column(
      children: [
        SwitchListTile(
          title: Text('Enable SOS Menu Bar'),
          value: sosEnabled,
          onChanged: (value) => setState(() => sosEnabled = value),
        ),
        _buildListTile(
          Icons.send,
          'Send SOS Message',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditSOSScreen(
                policePhoneNumber: "+918369079412",
              ),
            ),
          ),
        ),
        _buildListTile(Icons.settings, 'Additional SOS Settings', () {}),
      ],
    );
  }
}
