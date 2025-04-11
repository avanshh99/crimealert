import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // Added for File

class CloudinaryService {
  static const String cloudinaryCloudName = "dvgxyoprg";
  static const String cloudinaryUploadPreset =
      "crime_alert"; // Match your preset name

  /// Uploads an image to Cloudinary and returns the URL.
  /// Returns null if the upload fails, and logs the error.
  static Future<String?> uploadImage(
      dynamic imageFile, String folderName) async {
    try {
      var uri = Uri.parse(
          "https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload");
      var request = http.MultipartRequest("POST", uri)
        ..fields['upload_preset'] = cloudinaryUploadPreset
        ..fields['folder'] = folderName;

      if (imageFile is File) {
        // For Mobile (Flutter iOS/Android)
        request.files
            .add(await http.MultipartFile.fromPath("file", imageFile.path));
      } else if (imageFile is Uint8List) {
        // For Web
        // Generate a unique filename using timestamp
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        request.files.add(http.MultipartFile.fromBytes(
          "file",
          imageFile,
          filename: "upload_$timestamp.png",
        ));
      } else {
        throw Exception("Invalid image format: Expected File or Uint8List");
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url']; // Cloudinary image URL
      } else {
        // Log the specific error from Cloudinary
        String errorMessage =
            jsonResponse['error']?['message'] ?? 'Unknown error';
        print(
            "Cloudinary upload failed: $errorMessage (Status: ${response.statusCode})");
        return null;
      }
    } catch (e) {
      print("Error uploading image to Cloudinary: $e");
      return null;
    }
  }
}
