import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:voicetourguide/MonumentDetailsScreen.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'package:voicetourguide/monument_suggestion.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraCaptureScreenState createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraScreen> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
    );

    try {
      await _cameraController.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print("Error during camera initialization: $e");
    }
  }

  Future<Position> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _captureAndDetect() async {
    if (!_cameraController.value.isInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile imageFile = await _cameraController.takePicture();

      if (!File(imageFile.path).existsSync()) {
        print("Error: Captured image file does not exist.");
        return;
      }

      final userLocation = await _getUserLocation();
      print("User Location: ${userLocation.latitude}, ${userLocation.longitude}");

      final label = await uploadImage(imageFile.path);
      if (label != null) {
        print("Predicted Landmark: $label");
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<String?> uploadImage(String imagePath) async {
    final url = Uri.parse("https://pronab102-voice-map.hf.space/classify");

    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          File(imagePath).readAsBytesSync(),
          filename: path.basename(imagePath),
        ),
      );
      request.fields['latitude'] = "51.5032255";
      request.fields['longitude'] = "-0.1158352";

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final responseJson = jsonDecode(responseBody) as Map<String, dynamic>;

        print("Response from API: $responseJson");

        final isLocationMatch = responseJson['Match'] == 1; // Check if the location matches
        final suggestions = responseJson['Predicted Landmark'];
        final M_Confidence = responseJson['Model Confidence'];
        final C_Confidence = responseJson['Combined Confidence'];
        final Latitude = responseJson['Landmark Latitude'] as double?; // Handle nullable
        final Longitude = responseJson['Landmark Longitude'] as double?; // Handle nullable
        if (isLocationMatch) {
          _showSuggestions(suggestions, M_Confidence, C_Confidence, Latitude, Longitude, isLocationMatch);
          return suggestions;
        } else {
          _showNoLandmarkDetected(context);
          return "Landmark Not Detected";
        }
      } else {
        print("Error: Received status code ${response.statusCode}");
      }
    } catch (e) {
      print("Error during image upload: $e");
    }

    return null;
  }

  /// Function to show AlertDialog when no landmark is detected
  void _showNoLandmarkDetected(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("No Landmark Detected"),
          content: const Text("No landmark was detected in the current location. Please try again."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showSuggestions(
      String suggestionName, String mc, String cc, double? latitude, double? longitude, bool isLocationMatch) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final matchText = isLocationMatch ? "Location is Match" : "No Match with Location";
        final latitudeText = latitude != null ? latitude.toString() : "Unknown";
        final longitudeText = longitude != null ? longitude.toString() : "Unknown";

        return ListView(
          children: [
            ListTile(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Landmark: $suggestionName'), // Main title

                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(matchText), // Subtitle
                  Text('Model Confidence: $mc'), // Second title
                  Text('Combined Confidence: $cc'), // Third title
                ],
              ),
              onTap: () {
                print("Latitude:"+latitudeText +"Longitude:"+ longitudeText);
                Navigator.pop(context); // Close the modal
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MonumentDetailsScreen(
                      monument: MonumentSuggestion(
                        name: suggestionName,
                        latitude: latitude ?? 0.0, // Provide a fallback value
                        longitude: longitude ?? 0.0, // Provide a fallback value

                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );

      },
    );
  }





  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        color: Colors.white,
        child: Column(
          children: [
            if (_isCameraInitialized)
              Expanded(
                child: CameraPreview(_cameraController),
              )
            else
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            Padding(
              padding: const EdgeInsets.all(1.0),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _captureAndDetect,
                child: const Text('Capture & Detect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
