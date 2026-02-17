import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController _mapController = MapController();

  // Default campus location (you can change this to your campus coordinates)
  static const LatLng _campusCenter =
      LatLng(37.7749, -122.4194); // San Francisco example

  final List<Marker> _markers = [];
  final List<Map<String, dynamic>> _campusLocations = [
    {
      'name': 'Library',
      'icon': Icons.local_library,
      'color': Colors.blue,
      'lat': 37.7749,
      'lng': -122.4194,
    },
    {
      'name': 'Cafeteria',
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'lat': 37.7759,
      'lng': -122.4184,
    },
    {
      'name': 'Gym',
      'icon': Icons.fitness_center,
      'color': Colors.red,
      'lat': 37.7739,
      'lng': -122.4204,
    },
    {
      'name': 'Admin Building',
      'icon': Icons.business,
      'color': Colors.purple,
      'lat': 37.7769,
      'lng': -122.4174,
    },
    {
      'name': 'Student Center',
      'icon': Icons.people,
      'color': Colors.green,
      'lat': 37.7729,
      'lng': -122.4214,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  void _initializeMarkers() {
    for (var location in _campusLocations) {
      _markers.add(
        Marker(
          point: LatLng(location['lat'], location['lng']),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showLocationInfo(location),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: location['color'],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    location['icon'],
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    location['name'],
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showLocationInfo(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: location['color'],
                  child: Icon(location['icon'], color: Colors.white),
                ),
                const SizedBox(width: 16),
                Text(
                  location['name'],
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Location Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Coordinates: ${location['lat']}, ${location['lng']}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _mapController.move(
                        LatLng(location['lat'], location['lng']),
                        16,
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _mapController.move(_campusCenter, 15);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _campusCenter,
              initialZoom: 15,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.stuchat',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Legend
          Positioned(
            bottom: 20,
            left: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Campus Locations',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._campusLocations.map((loc) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(loc['icon'], size: 16, color: loc['color']),
                              const SizedBox(width: 8),
                              Text(loc['name'],
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
