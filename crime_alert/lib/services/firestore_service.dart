import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crime_alert/models/user_model.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches user data from Firestore
  /// Returns [UserModel] if found, null otherwise
  static Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap({
          ...doc.data() as Map<String, dynamic>,
          'uid': uid, // Ensure UID is included
        });
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Updates all user data in Firestore
  static Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      rethrow;
    }
  }

  /// Updates only the profile image URL in Firestore
  /// Also updates all posts by this user with the new profile image
  static Future<void> updateUserProfileImage(String uid, String imageUrl) async {
    try {
      // Update user document
      await _firestore.collection('users').doc(uid).update({
        'imageURL': imageUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update all posts by this user
      final posts = await _firestore
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in posts.docs) {
        batch.update(doc.reference, {'userImage': imageUrl});
      }
      await batch.commit();
    } catch (e) {
      print('Error updating profile image: $e');
      rethrow;
    }
  }

  /// Updates specific fields in user document
  static Future<void> updateUserFields({
    required String uid,
    required Map<String, dynamic> fields,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        ...fields,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a new user document if it doesn't exist
  static Future<void> createUserIfNotExists(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
            user.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      rethrow;
    }
  }

  /// Stream of user data for real-time updates
  static Stream<UserModel?> userDataStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return UserModel.fromMap({
          ...snapshot.data() as Map<String, dynamic>,
          'uid': snapshot.id,
        });
      }
      return null;
    });
  }
}