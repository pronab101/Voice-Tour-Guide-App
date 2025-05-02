import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapScreen extends StatefulWidget {
  final String landmarkName;
  final String landmarkDetails;
  final LatLng location;

  GoogleMapScreen({
    required this.landmarkName,
    required this.landmarkDetails,
    required this.location,
  });

  @override
  _GoogleMapScreenState createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();
    print("🚀 Navigating to Google Map for: ${widget.landmarkName}");
    print("Details: ${widget.landmarkDetails}");
    print("Latitude: ${widget.location.latitude}, Longitude: ${widget.location.longitude}");

    if (widget.location.latitude == 0.0 && widget.location.longitude == 0.0) {
      print("⚠️ Invalid Coordinates for ${widget.landmarkName}");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;

    print("✅ Google Map Created for ${widget.landmarkName}");
    print("📍 Moving camera to: ${widget.location.latitude}, ${widget.location.longitude}");

    // Move camera to the correct location
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(widget.location, 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.landmarkName)),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.location,
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: MarkerId(widget.landmarkName),
            position: widget.location,
            infoWindow: InfoWindow(
              title: widget.landmarkName,
              snippet: widget.landmarkDetails,
            ),
          ),
        },
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
