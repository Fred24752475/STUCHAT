import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class LocationSharingScreen extends StatefulWidget {
  final String userId;

  const LocationSharingScreen({super.key, required this.userId});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  Map<String, dynamic>? _currentLocation;
  List<Map<String, dynamic>> _friendsLocations = [];
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadFriendsLocations();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadFriendsLocations() async {
    try {
      final locations = await ApiService.getFriendsLocations(widget.userId);

      if (mounted) {
        setState(() {
          _friendsLocations = locations.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error loading friends locations: $e');
    }
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${location['friendName'] ?? 'Friend'} Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '📍 ${location['latitude']?.toStringAsFixed(4) ?? '?'}, ${location['longitude']?.toStringAsFixed(4) ?? '?'}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (location['address'] != null && location['address'] != 'Unknown')
                Text('📋 ${location['address']}'),
              const SizedBox(height: 12),
              if (location['timestamp'] != null)
                Text(
                  'Shared: ${location['timestamp']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 Location Sharing'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // My location section
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.my_location,
                          color: Colors.green,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentLocation != null
                                    ? 'Lat: ${_currentLocation!['latitude']?.toStringAsFixed(4) ?? '?'}, Lng: ${_currentLocation!['longitude']?.toStringAsFixed(4) ?? '?'}'
                                    : 'Not sharing',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _toggleLocationSharing,
                                icon: Icon(
                                  _isSharing ? Icons.stop : Icons.location_on,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  _isSharing ? 'Stop Sharing' : 'Start Sharing',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isSharing ? Colors.red : Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Friends' locations section
            if (_friendsLocations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Friends' Locations",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      _friendsLocations.length,
                      (index) {
                        final location = _friendsLocations[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassCard(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                location['friendName'] ?? 'Friend',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '📍 ${location['latitude']?.toStringAsFixed(4) ?? '?'}, ${location['longitude']?.toStringAsFixed(4) ?? '?'}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.info_outline),
                                onPressed: () =>
                                    _showLocationDetails(location),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.location_off,
                        color: Colors.grey, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'No friends sharing location yet',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLocationSharing() async {
    if (!_isSharing) {
      final hasPermission = await _requestLocationPermission();
      if (hasPermission) {
        setState(() => _isSharing = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location sharing started'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      setState(() => _isSharing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location sharing stopped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<bool> _requestLocationPermission() async {
    final status = await Permission.location.request();

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }
    return true;
  }
}
