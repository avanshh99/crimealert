import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditSOSScreen extends StatefulWidget {
  final String policePhoneNumber;

  const EditSOSScreen({Key? key, required this.policePhoneNumber})
      : super(key: key);

  @override
  _EditSOSScreenState createState() => _EditSOSScreenState();
}

class _EditSOSScreenState extends State<EditSOSScreen> {
  String _location = "Fetching location...";
  bool _isSending = false;
  final TextEditingController _messageController = TextEditingController(
    text: "",
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _location = "Location services disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _location = "Location permissions denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _location = "Location permissions permanently denied");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _location = "Lat: ${position.latitude}, Long: ${position.longitude}";
      });
    } catch (e) {
      setState(() => _location = "Error getting location: $e");
    }
  }

  Future<void> _sendEmergencySMS() async {
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      final message =
          "${_messageController.text}\n$_location\nSent via Crime Alert App";

      final response = await http.post(
        Uri.parse(
            'http://192.168.156.1:5000/send-sms'), // replace with real IP if on physical device
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': widget.policePhoneNumber,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS message sent to police!')),
        );
      } else {
        final error = jsonDecode(response.body)['error'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $error')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency SOS"),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.warning, size: 50, color: Colors.red),
                    const SizedBox(height: 10),
                    const Text(
                      "EMERGENCY ALERT",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "This will send your location to police",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: "Emergency Message",
                hintText: "Be calm! we are here to help you!",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 15),
            Text(
              "Your Location:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(_location),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isSending ? null : _sendEmergencySMS,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: const Icon(Icons.emergency),
              label: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "SEND EMERGENCY ALERT TO POLICE",
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
