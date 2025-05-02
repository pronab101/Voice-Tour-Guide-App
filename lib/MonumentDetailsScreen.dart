import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:voicetourguide/ChatScreen.dart';
import 'package:voicetourguide/monument_suggestion.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class MonumentDetailsScreen extends StatefulWidget {
  final MonumentSuggestion monument;

  const MonumentDetailsScreen({Key? key, required this.monument})
      : super(key: key);

  @override
  _MonumentDetailsScreenState createState() => _MonumentDetailsScreenState();
}

class _MonumentDetailsScreenState extends State<MonumentDetailsScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  bool _isSpeaking = false;
  bool _isLoading = true;
  String _monumentDetails = 'Fetching details...';
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _fetchMonumentDetails();
    _getCurrentLocation();
  }

  Future<void> _fetchMonumentDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // API details
      const url = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3";
      const apiKey = "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"; // Replace with your Hugging Face API Key

      // Improved prompt to get a concise response without repeating the prompt
      final prompt = "Provide a detailed but concise description (2 sentences) of the monument '${widget.monument.name}'.";

      // Sending POST request to Hugging Face
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'inputs': prompt}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Extract "generated_text" field from API response
        if (responseData is List && responseData.isNotEmpty && responseData[0].containsKey("generated_text")) {
          String details = responseData[0]['generated_text'];

          // Remove the first sentence if it echoes the prompt
          List<String> sentences = details.split('. ');
          if (sentences.isNotEmpty && sentences[0].contains("Describe the monument")) {
            sentences.removeAt(0);
          }

          // Take the first 3 sentences to keep it short
          final filteredDetails = sentences.take(3).join('. ') + ".";

          setState(() {
            _monumentDetails = filteredDetails;
          });

          // Speak the details
          await _speak(filteredDetails);
        } else {
          setState(() {
            _monumentDetails = 'No details available.';
          });
        }
      } else {
        setState(() {
          _monumentDetails = 'Failed to fetch details. Please try again.';
        });
        debugPrint('Error: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _monumentDetails = 'Failed to fetch details. Please try again.';
      });
      debugPrint('Error fetching monument details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  void _launchGoogleMaps() async {
    final url =
        'https://www.google.com/maps/dir/?api=1&origin=${_currentLocation?.latitude},${_currentLocation?.longitude}&destination=${widget.monument.latitude},${widget.monument.longitude}&travelmode=driving';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) return;

    setState(() => _isSpeaking = true);
    await _flutterTts.speak(text);

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _pauseSpeech() async {
    await _flutterTts.pause();
  }

  Future<void> _stopSpeech() async {
    await _flutterTts.stop();
    setState(() => _isSpeaking = false);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Monument Details', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Google Maps Integration
          if (_currentLocation != null)

            SizedBox(
              height: 200,
              child: GoogleMap(

                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.monument.latitude, widget.monument.longitude),
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId(widget.monument.name),
                    position: LatLng(widget.monument.latitude, widget.monument.longitude),
                    infoWindow: InfoWindow(title: widget.monument.name),
                  ),
                },
              ),
            ),
          const SizedBox(height: 10),
          // Monument name
          Text(
            widget.monument.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // Audio controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                color: _isSpeaking ? Colors.grey : Colors.green,
                onPressed: _isSpeaking ? null : () => _speak(_monumentDetails),
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                color: Colors.orange,
                onPressed: _pauseSpeech,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                color: Colors.red,
                onPressed: _stopSpeech,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Monument details
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _monumentDetails,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _launchGoogleMaps,
            child: Text('Get Directions'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(monumentName: widget.monument.name),
            ),
          );
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}
