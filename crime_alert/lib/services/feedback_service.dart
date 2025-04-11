import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FeedbackService {
  static Future<void> sendFeedback(String message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = doc.data();

    final name = "${userData?['firstName']} ${userData?['lastName']}";
    final email = userData?['email'];

    final response = await http.post(
      Uri.parse("https://api.emailjs.com/api/v1.0/email/send"),
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "service_id": "service_0dikxln",
        "template_id": "template_ui78g9w",
        "user_id": "r65siRarkKOk1Edhe",
        "template_params": {
          "to_email": "avanshetty196@gmail.com",
          "from_name": name,
          "reply_to": email,
          "message": message,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send feedback: ${response.body}');
    }
  }
}
