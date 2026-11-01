import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  Timer? locationTimer;

  LatLng? currentLocation;

  final List<LatLng> locationHistory = [];

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeLocation();
  }

  // Check location permission and initialize GPS
  Future<void> initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage('Please enable location services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showMessage('Location permission is required.');
        return;
      }

      await updateLocation();

      locationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => updateLocation(),
      );
    } catch (e) {
      showMessage('Location error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Fetch and update current location
  Future<void> updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      LatLng newLocation = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        currentLocation = newLocation;

        locationHistory.add(newLocation);

        markers = {
          Marker(
            markerId: const MarkerId('current_location'),
            position: newLocation,
            infoWindow: InfoWindow(
              title: 'My current location',
              snippet:
                  'Lat: ${newLocation.latitude}, '
                  'Lng: ${newLocation.longitude}',
            ),
          ),
        };

        polylines = {
          Polyline(
            polylineId: const PolylineId('tracking_route'),
            points: List<LatLng>.from(locationHistory),
            color: Colors.blue,
            width: 5,
          ),
        };
      });

      // Animate camera to current location
      mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
    } catch (e) {
      debugPrint('Location update error: $e');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps Tracking'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentLocation == null
          ? const Center(child: Text('Unable to get current location.'))
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: currentLocation!,
                zoom: 16,
              ),
              onMapCreated: (controller) {
                mapController = controller;

                mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(currentLocation!, 16),
                );
              },
              markers: markers,
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
    );
  }
}
