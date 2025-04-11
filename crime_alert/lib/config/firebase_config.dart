import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static final FirebaseOptions firebaseOptions = FirebaseOptions(
      apiKey: 'AIzaSyCSsiwDOtCacBnkLxhGaqtMcHmoTQM1wtQ',
      appId: '1:50633934192:web:9f767143ef1d937a697bb5',
      messagingSenderId: '50633934192',
      projectId: 'crimealert-d0a3f',
      databaseURL: "https://crimealert-d0a3f-default-rtdb.firebaseio.com/",
      storageBucket: 'crimealert-d0a3f.firebasestorage.app');

  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: firebaseOptions,
      );
      if (kDebugMode) {
        print('Firebase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase: $e');
      }
      rethrow;
    }
  }
}
