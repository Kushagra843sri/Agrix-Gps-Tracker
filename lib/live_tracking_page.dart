import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LiveTrackingPage extends StatefulWidget {
  final String Function(String) translate;

  LiveTrackingPage({required this.translate});

  @override
  _LiveTrackingPageState createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  late GoogleMapController mapController;
  LatLng _currentPosition = LatLng(0, 0); // Default position

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  void initState() {
    super.initState();
    _fetchMachineLocations();
  }

  Future<void> _fetchMachineLocations() async {
    try {
      final response = await http.get(Uri.parse(
          'https://agrix-staging-v1.azurewebsites.net/machines/locations'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final machineLocations = jsonResponse['data'];

        setState(() {
          _currentPosition = LatLng(
            machineLocations['latitude'],
            machineLocations['longitude'],
          );

          mapController.animateCamera(
            CameraUpdate.newLatLng(_currentPosition),
          );
        });
      } else {
        throw Exception('Failed to load machine locations');
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.translate('Live Tracking'))),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 14.0,
        ),
        markers: {
          Marker(
            markerId: MarkerId('machine_location'),
            position: _currentPosition,
            infoWindow: InfoWindow(title: 'Machine Location'),
          ),
        },
      ),
    );
  }
}
