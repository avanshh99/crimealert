import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crime_alert/views/home/home_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:crime_alert/services/cloudinary_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'dart:typed_data';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class CrimeReportScreen extends StatefulWidget {
  @override
  _CrimeReportScreenState createState() => _CrimeReportScreenState();
}

class _CrimeReportScreenState extends State<CrimeReportScreen> {
  // Controllers and state variables
  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String? selectedCrimeType;
  String? identitySelection;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool agreedToTerms = false;
  dynamic evidenceImage;
  final picker = ImagePicker();
  List<Map<String, dynamic>> locationSuggestions = [];
  bool _isSearching = false;
  bool _isSubmitting = false;
  Timer? _debounceTimer;

  Future<void> pickImage() async {
    try {
      if (kIsWeb) {
        final Uint8List? imageBytes = await ImagePickerWeb.getImageAsBytes();
        if (imageBytes != null) {
          setState(() => evidenceImage = imageBytes);
        }
      } else {
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          setState(() => evidenceImage = File(pickedFile.path));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: ${e.toString()}")),
      );
    }
  }

  // Optimized method to compress images before upload with better performance
  Future<dynamic> compressImage(dynamic originalImage) async {
    try {
      if (kIsWeb) {
        // For web, compression options are limited
        // Return the original image for web for now
        return originalImage;
      } else {
        // For mobile platforms
        if (originalImage is File) {
          final dir = await getTemporaryDirectory();
          final targetPath =
              '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

          // Use more aggressive compression for faster uploads
          final result = await FlutterImageCompress.compressAndGetFile(
            originalImage.path,
            targetPath,
            quality: 60, // Lower quality for faster upload
            minWidth: 800, // Reduced dimensions for faster processing
            minHeight: 800,
            rotate: 0, // No rotation to save processing time
          );

          return result; // This is a File
        }
      }
      return originalImage;
    } catch (e) {
      print("Error compressing image: $e");
      return originalImage; // Fallback to original if compression fails
    }
  }

  // Single progress dialog that updates its message instead of creating new dialogs
  bool _isDialogShowing = false;
  
  void showProgressDialog(String message) {
    if (!mounted) return;
    
    if (!_isDialogShowing) {
      _isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text("Processing"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(message, key: ValueKey('progress_message')),
                ],
              );
            },
          ),
        ),
      );
    } else {
      // Find the dialog and update its message instead of creating a new one
      final context = this.context;
      if (context.mounted) {
        final OverlayState? overlay = Overlay.of(context);
        if (overlay != null) {
          overlay.setState(() {});
        }
      }
    }
  }
  
  void hideProgressDialog() {
    if (mounted && _isDialogShowing) {
      Navigator.of(context, rootNavigator: true).pop();
      _isDialogShowing = false;
    }
  }

  Future<void> fetchLocationSuggestions(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => locationSuggestions = []);
      return;
    }

    // Cancel any existing timer before starting a new one
    _debounceTimer?.cancel();

    // Increased debounce time to reduce API calls
    _debounceTimer = Timer(Duration(milliseconds: 800), () async {
      if (mounted) setState(() => _isSearching = true);

      try {
        final url = Uri.parse(
            "https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&addressdetails=0"); // Reduced data with addressdetails=0

        final response = await http.get(
          url,
          headers: {
            "User-Agent": "CrimeAlertApp",
            "Accept": "application/json", // Explicit accept header
          },
        ).timeout(Duration(seconds: 8)); // Reduced timeout

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (mounted) {
            setState(() {
              locationSuggestions = data.map((result) {
                return {
                  'display_name': result['display_name'],
                  'lat': double.parse(result['lat']),
                  'lon': double.parse(result['lon']),
                };
              }).toList();
            });
          }
        }
      } catch (e) {
        print("Error fetching location suggestions: $e");
        // Only show error for non-timeout errors to reduce UI noise
        if (mounted && e is! TimeoutException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Error fetching locations: ${e.toString()}")),
          );
        }
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<Position?> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  // Fully optimized version with better parallelization and reduced UI updates
  Future<void> submitReport() async {
    if (!agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You must agree to the Terms & Conditions")),
      );
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    showProgressDialog("Preparing to submit report...");

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        hideProgressDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You must be logged in to submit a report")),
        );
        return;
      }

      // Start all operations in parallel immediately
      showProgressDialog("Processing your report...");
      
      // 1. Start location request immediately
      final Future<Position?> positionFuture = _getUserLocation();
      
      // 2. Start image processing immediately if we have an image
      Future<String?> imageUrlFuture;
      if (evidenceImage != null) {
        // Process image compression in a compute isolate if not on web
        final compressedImageFuture = !kIsWeb && evidenceImage is File
            ? compute(_isolateCompress, evidenceImage)
            : compressImage(evidenceImage);
            
        // Chain the upload to happen after compression
        imageUrlFuture = compressedImageFuture.then((compressedImage) {
          return CloudinaryService.uploadImage(compressedImage, "crime_reports");
        });
      } else {
        imageUrlFuture = Future.value(null);
      }

      // 3. Prepare report data that doesn't depend on async operations
      final Map<String, dynamic> reportData = {
        'userId': user.uid,
        'description': descriptionController.text,
        'crimeType': selectedCrimeType,
        'identity': identitySelection,
        'date': selectedDate?.toIso8601String(),
        'time': selectedTime?.format(context),
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      // 4. Wait for position and then immediately start address lookup
      final position = await positionFuture;
      if (position == null) {
        hideProgressDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not determine your location")),
        );
        return;
      }
      
      // Add position data to report
      reportData['latitude'] = position.latitude;
      reportData['longitude'] = position.longitude;
      
      // 5. Start address lookup now that we have position
      final Future<String> addressFuture = 
          _getAddressFromLatLng(position.latitude, position.longitude);
      
      // 6. Wait for remaining async operations to complete
      final results = await Future.wait([
        addressFuture,
        imageUrlFuture,
      ]);

      final String address = results[0] as String;
      final String? imageUrl = results[1] as String?;
      
      // Add the remaining data
      reportData['location'] = locationController.text.isNotEmpty
          ? locationController.text
          : address;
      reportData['address'] = address;
      reportData['imageUrl'] = imageUrl;

      // 7. Save to Firestore
      await FirebaseFirestore.instance
          .collection('crime_reports')
          .add(reportData);

      hideProgressDialog();

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Report Submitted"),
            content: Text("Your crime report has been successfully submitted."),
            actions: [
              TextButton(
                onPressed: () {
                  // Clear navigation stack and go directly to Dashboard
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => Dashboard()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    } catch (error) {
      hideProgressDialog();
      print("Error submitting report: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit report: ${error.toString()}")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
  
  // Static method for isolate computation
  static Future<dynamic> _isolateCompress(dynamic originalImage) async {
    if (originalImage is File) {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        originalImage.path,
        targetPath,
        quality: 60,
        minWidth: 800,
        minHeight: 800,
        rotate: 0,
      );

      return result;
    }
    return originalImage;
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
            "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=0"), // Reduced data with addressdetails=0
        headers: {
          "User-Agent": "CrimeAlertApp",
          "Accept": "application/json", // Explicit accept header
        },
      ).timeout(Duration(seconds: 5)); // Reduced timeout for faster fallback

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ??
            "Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}";
      }
      return "Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}";
    } catch (e) {
      print("Error fetching address: $e");
      return "Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}";
    }
  }

  @override
  void dispose() {
    locationController.dispose();
    descriptionController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crime Report'),
        backgroundColor: Colors.red,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => Dashboard()),
              (route) => false, // Removes all previous screens
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search and location input
            TextField(
              controller: searchController,
              onChanged: fetchLocationSuggestions,
              decoration: InputDecoration(
                labelText: 'Search Location',
                prefixIcon: Icon(Icons.search, color: Colors.red),
                border: OutlineInputBorder(),
                suffixIcon: _isSearching
                    ? Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),
            if (locationSuggestions.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: locationSuggestions
                      .map((location) => ListTile(
                            title: Text(location['display_name']),
                            onTap: () {
                              setState(() {
                                locationController.text =
                                    location['display_name'];
                                locationSuggestions.clear();
                              });
                            },
                          ))
                      .toList(),
                ),
              ),
            SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: 'Enter the Location of the incident',
                prefixIcon: Icon(Icons.location_on, color: Colors.red),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.calendar_today),
                    label: Text(
                      selectedDate == null
                          ? 'Select Date'
                          : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.access_time),
                    label: Text(
                      selectedTime == null
                          ? 'Select Time'
                          : selectedTime!.format(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedTime = picked);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCrimeType,
              hint: Text('Select Type of Crime'),
              items: [
                'Theft',
                'Assault',
                'Vandalism',
                'Fraud',
                'Kidnapping',
                'Harassment',
                'Cyber Crime',
                'Homicide',
                'Drug Offense',
                'Arson',
                'Other'
              ]
                  .map((crime) => DropdownMenuItem(
                        value: crime,
                        child: Text(crime),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => selectedCrimeType = value);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Enter the description of the incident',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: Icon(Icons.camera_alt),
              label: Text('Add Evidence Media / Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (evidenceImage != null) ...[
              SizedBox(height: 8),
              Text(
                'Evidence attached',
                style: TextStyle(color: Colors.green),
              ),
            ],
            SizedBox(height: 16),
            Text("Please Select, I am the:"),
            Column(
              children: [
                RadioListTile(
                  title: Text("Victim"),
                  value: "Victim",
                  groupValue: identitySelection,
                  onChanged: (value) {
                    setState(() => identitySelection = value as String?);
                  },
                ),
                RadioListTile(
                  title: Text("Witness"),
                  value: "Witness",
                  groupValue: identitySelection,
                  onChanged: (value) {
                    setState(() => identitySelection = value as String?);
                  },
                ),
                RadioListTile(
                  title: Text("Anonymous"),
                  value: "Anonymous",
                  groupValue: identitySelection,
                  onChanged: (value) {
                    setState(() => identitySelection = value as String?);
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: agreedToTerms,
                  onChanged: (value) {
                    setState(() => agreedToTerms = value!);
                  },
                ),
                Expanded(
                  child: Text(
                    "By submitting this form I acknowledge that the information is true and I agree to the Terms and Conditions.",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : submitReport,
              child: _isSubmitting
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Submit Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
