// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io';

// class AddPostScreen extends StatefulWidget {
//   @override
//   _AddPostScreenState createState() => _AddPostScreenState();
// }

// class _AddPostScreenState extends State<AddPostScreen> {
//   final TextEditingController titleController = TextEditingController();
//   final TextEditingController contentController = TextEditingController();
//   String? location;
//   File? image;
//   final picker = ImagePicker();

//   Future<void> pickImage() async {
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       setState(() {
//         image = File(pickedFile.path);
//       });
//     }
//   }

//   Future<void> submitPost() async {
//     if (titleController.text.isEmpty || contentController.text.isEmpty || location == null) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("All fields are required")));
//       return;
//     }

//     try {
//       await FirebaseFirestore.instance.collection('posts').add({
//         'title': titleController.text,
//         'content': contentController.text,
//         'location': location,
//         'dateCreated': DateTime.now().toIso8601String(),
//         'countComment': 0,
//         'media': image != null ? ['https://example.com/temp.jpg'] : [],
//       });

//       // Show confirmation dialog
//       showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: Text("Post Submitted"),
//             content: Text("Your post has been added successfully."),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(context); // Close dialog
//                   Navigator.pop(context); // Go back to post feed
//                 },
//                 child: Text("OK"),
//               ),
//             ],
//           );
//         },
//       );
//     } catch (error) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to add post: $error")));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Add Post"),
//         backgroundColor: Colors.red,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: titleController,
//               decoration: InputDecoration(labelText: "Title", border: OutlineInputBorder()),
//             ),
//             SizedBox(height: 10),
//             TextField(
//               controller: contentController,
//               maxLines: 4,
//               decoration: InputDecoration(labelText: "Content", border: OutlineInputBorder()),
//             ),
//             SizedBox(height: 10),
//             DropdownButtonFormField<String>(
//               value: location,
//               hint: Text("Select Location"),
//               items: ["Fatherwadi", "Vasai", "Mumbai"].map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   location = value;
//                 });
//               },
//               decoration: InputDecoration(border: OutlineInputBorder()),
//             ),
//             SizedBox(height: 10),
//             ElevatedButton.icon(
//               onPressed: pickImage,
//               icon: Icon(Icons.camera_alt),
//               label: Text("Attach Image"),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
//             ),
//             SizedBox(height: 10),
//             if (image != null)
//               Image.file(image!, height: 100, fit: BoxFit.cover),
//             SizedBox(height: 10),
//             ElevatedButton(
//               onPressed: submitPost,
//               child: Text("Submit Post"),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }






import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:crime_alert/services/cloudinary_service.dart';

class AddPostScreen extends StatefulWidget {
  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  String? location;
  dynamic image;
  String? username;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      username = doc.exists ? doc['firstName'] ?? "Unknown User" : "Unknown User";
      isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final Uint8List? imageBytes = await ImagePickerWeb.getImageAsBytes();
      setState(() => image = imageBytes);
    } else {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) setState(() => image = File(pickedFile.path));
    }
  }

  Future<void> _submitPost() async {
    if (titleController.text.isEmpty || contentController.text.isEmpty || location == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("All fields are required")));
      return;
    }

    try {
      String? imageUrl = image != null ? await CloudinaryService.uploadImage(image, "post_images") : null;
      await FirebaseFirestore.instance.collection('posts').add({
        'title': titleController.text,
        'content': contentController.text,
        'location': location,
        'media': imageUrl != null ? [imageUrl] : [],
        'firstName': username,
        'countComment': 0,
        'dateCreated': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });

      titleController.clear();
      contentController.clear();
      setState(() => {location = null, image = null});

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Post Submitted"),
          content: Text("Your post has been added successfully."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to submit post: $error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Post"), backgroundColor: Colors.red),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: titleController, decoration: InputDecoration(labelText: "Title", border: OutlineInputBorder())),
                    SizedBox(height: 10),
                    TextField(controller: contentController, maxLines: 4, decoration: InputDecoration(labelText: "Content", border: OutlineInputBorder())),
                    SizedBox(height: 10),
                    DropdownButtonFormField(
                      value: location,
                      hint: Text("Select Location"),
                      items: ["Fatherwadi", "Vasai", "Mumbai"].map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
                      onChanged: (value) => setState(() => location = value),
                      decoration: InputDecoration(border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.camera_alt),
                      label: Text("Attach Image"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    ),
                    if (image != null) SizedBox(height: 10),
                    if (image != null) kIsWeb ? Text("Image selected (Web)") : Image.file(image as File, height: 100, fit: BoxFit.cover),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _submitPost,
                      child: Text("Submit Post"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }
}







