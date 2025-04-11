import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class CrimeAlertsScreen extends StatefulWidget {
  const CrimeAlertsScreen({Key? key}) : super(key: key);

  @override
  State<CrimeAlertsScreen> createState() => _CrimeAlertsScreenState();
}

class _CrimeAlertsScreenState extends State<CrimeAlertsScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchSuggestions = [];
  Set<Marker> _markers = {};
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<QuerySnapshot>? _reportsSubscription;
  bool _isSearching = false;
  bool _locationServicesEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupReportsStream(); // Ensures crime reports are always up-to-date
  }

  Future<void> _initializeApp() async {
    await _checkLocationServicesAndInit();
    _loadCrimeReports();
    _setupReportsStream();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _reportsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

void _setupReportsStream() {
  print("🔄 Setting up Firestore reports stream...");
  _reportsSubscription?.cancel(); // Cancel old subscription if any
  print("✅ Old Firestore subscription canceled (if any)");

  _reportsSubscription = FirebaseFirestore.instance
      .collection('crime_reports')
      .snapshots()
      .listen((snapshot) {
    if (!mounted) {
      print("⚠ Widget is not mounted, skipping update.");
      return;
    }

    print("📥 Received Firestore snapshot with ${snapshot.docs.length} documents");

    setState(() {
      print("🗑 Removing old crime markers...");
      _markers.removeWhere((marker) => marker.markerId.value.startsWith('crime_'));
      _isLoading = false;
    });

    for (var doc in snapshot.docs) {
      final data = doc.data();
      print("📝 Processing crime report: ${doc.id}, Data: $data");

      if (data['latitude'] != null && data['longitude'] != null) {
        try {
          final double latitude = data['latitude'].toDouble();
          final double longitude = data['longitude'].toDouble();
          final String crimeType = data['crimeType'] ?? 'Crime Report';
          final String time = data['time'] ?? 'Unknown time';
          final String description = data['description'] ?? '';

          print("📍 Creating marker at ($latitude, $longitude) for crime: $crimeType");

          final marker = Marker(
            markerId: MarkerId('crime_${doc.id}'),
            position: LatLng(latitude, longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: crimeType,
              snippet: "$time - $description",
            ),
          );

          if (mounted) {
            setState(() {
              _markers.add(marker);
            });
            print("✅ Marker added: ${marker.markerId.value}");
            print("📌 Total markers added: ${_markers.length}");
          }
        } catch (e) {
          print("❌ Error parsing crime report (${doc.id}): $e");
        }
      } else {
        print("⚠ Skipping report ${doc.id} due to missing latitude/longitude");
      }
    }
  }, onError: (error) {
    print("❌ Error loading crime reports from Firestore: $error");
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading crime reports")),
      );
    }
  });
}


  Future<void> _loadCrimeReports() async {
    FirebaseFirestore.instance
        .collection('crime_reports')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _markers.removeWhere(
            (marker) => marker.markerId.value.startsWith('crime_'));
      });

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['latitude'] != null && data['longitude'] != null) {
          final marker = Marker(
            markerId: MarkerId('crime_${doc.id}'),
            position: LatLng(data['latitude'], data['longitude']),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: data['crimeType'] ?? 'Crime Report',
              snippet:
                  '${data['time'] ?? 'Unknown time'} - ${data['description'] ?? ''}',
            ),
          );
          setState(() {
            _markers.add(marker);
          });
        }
      }
    });
  }

  Future<void> _checkLocationServicesAndInit() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationServicesEnabled = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enable location services")),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _locationServicesEnabled = true;
        });
      }

      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location permission denied")),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Location permissions permanently denied")),
          );
        }
        return;
      }

      await _getCurrentPosition();
    } catch (e) {
      print("Location service error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error initializing location: $e")),
        );
      }
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      if (mounted) {
        _updateCurrentLocation(initialPosition);
      }

      _positionStreamSubscription?.cancel(); // Cancel old stream if exists
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        if (mounted) {
          _updateCurrentLocation(position);
        }
      });
    } catch (e) {
      print("Error getting current position: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting precise location: $e")),
        );
      }
    }
  }

  void _updateCurrentLocation(Position position) async {
    if (!mounted) return; // Avoid updating state if widget is disposed

    final String address =
        await _getAddressFromLatLng(position.latitude, position.longitude);

    if (mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers.removeWhere((marker) => marker.markerId.value == "MyLocation");

        _markers.add(
          Marker(
            markerId: const MarkerId("MyLocation"),
            position: _currentLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(title: "My Location", snippet: address),
          ),
        );
      });
    }

    // Move the camera only if _currentLocation is not null
    if (_currentLocation != null) {
      try {
        final GoogleMapController controller = await _controller.future;
        controller
            .animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 15));
      } catch (e) {
        print("Error moving camera: $e");
      }
    } else {
      print("Skipping camera movement due to null location");
    }
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final apiKey =
          "AIzaSyBZFVz_dHpmtiJbjIyipcJgiCQ173xYylE"; // Replace with your API Key
      final url = Uri.parse(
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return data['results'][0]['formatted_address'] ?? "Unknown location";
        }
      }
      return "Unknown location";
    } catch (e) {
      print("Error fetching address: $e");
      return "Error fetching address";
    }
  }

  void _addMockCrimes() {
    List<LatLng> crimeLocations = [
      LatLng(19.0760, 72.8777),
      LatLng(19.0800, 72.8800),
      LatLng(19.0730, 72.8750),
      LatLng(19.0780, 72.8820),
    ];

    List<String> crimeTypes = [
      "Robbery",
      "Assault",
      "Burglary",
      "Theft",
    ];

    List<String> crimeTimes = [
      "10:30 PM",
      "8:45 PM",
      "2:15 AM",
      "6:30 PM",
    ];

    for (int i = 0; i < crimeLocations.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId("crime_$i"),
          position: crimeLocations[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          // Just show the crime type as the title and time as the snippet
          infoWindow:
              InfoWindow(title: crimeTypes[i], snippet: "at ${crimeTimes[i]}"),
        ),
      );
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Using OpenStreetMap Nominatim search API (free)
      final url = Uri.parse(
          "https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&addressdetails=1");

      final response = await http.get(
        url,
        headers: {"User-Agent": "CrimeAlerts_App"}, // Required by Nominatim
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        List<Map<String, dynamic>> suggestions = [];

        for (var place in data) {
          suggestions.add({
            'display_name': place['display_name'],
            'lat': double.parse(place['lat']),
            'lon': double.parse(place['lon']),
          });
        }

        if (mounted) {
          setState(() {
            _searchSuggestions = suggestions;
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      print("Error searching location: $e");
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _goToSelectedPlace(double lat, double lon) async {
    try {
      final LatLng latLng = LatLng(lat, lon);

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));

      if (mounted) {
        setState(() {
          _searchSuggestions = [];
        });
      }
    } catch (e) {
      print("Error going to location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crime Alerts")),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(19.0760, 72.8777),
              zoom: 15.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _controller.complete(controller);
            },
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search location",
                      suffixIcon: _isSearching
                          ? CircularProgressIndicator()
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                if (_searchController.text.isNotEmpty) {
                                  _searchLocation(_searchController.text);
                                }
                              },
                            ),
                      prefixIcon: Icon(Icons.location_on_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      Future.delayed(Duration(milliseconds: 500), () {
                        if (value == _searchController.text &&
                            value.isNotEmpty) {
                          _searchLocation(value);
                        }
                      });
                    },
                  ),
                ),
                if (_searchSuggestions.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchSuggestions.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = _searchSuggestions[index];
                        return InkWell(
                          onTap: () {
                            _searchController.text = suggestion['display_name'];
                            _goToSelectedPlace(
                                suggestion['lat'], suggestion['lon']);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(
                              suggestion['display_name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "zoomIn",
            onPressed: () async {
              final controller = await _controller.future;
              controller.animateCamera(CameraUpdate.zoomIn());
            },
            child: const Icon(Icons.add),
          ),
          SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoomOut",
            onPressed: () async {
              final controller = await _controller.future;
              controller.animateCamera(CameraUpdate.zoomOut());
            },
            child: const Icon(Icons.remove),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "myLocation",
            onPressed: () async {
              if (!_locationServicesEnabled) {
                await _checkLocationServicesAndInit();
                return;
              }
              try {
                Position position = await Geolocator.getCurrentPosition();
                _updateCurrentLocation(position);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error fetching location: $e")),
                );
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
