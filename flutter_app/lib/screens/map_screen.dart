import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search locations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map, size: 100, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Interactive map coming soon'),
                  const SizedBox(height: 24),
                  _buildLocationChip('Library'),
                  _buildLocationChip('Cafeteria'),
                  _buildLocationChip('Lecture Hall A'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationChip(String location) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Chip(
        label: Text(location),
        avatar: const Icon(Icons.location_on, size: 18),
      ),
    );
  }
}
