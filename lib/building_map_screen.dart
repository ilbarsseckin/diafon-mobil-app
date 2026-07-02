import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bir binanın konumunu haritada işaretli gösterir.
class BuildingMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String title;

  const BuildingMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(latitude, longitude);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: pos, zoom: 17),
        markers: {
          Marker(
            markerId: const MarkerId('building'),
            position: pos,
            infoWindow: InfoWindow(title: title),
          ),
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
      ),
    );
  }
}
