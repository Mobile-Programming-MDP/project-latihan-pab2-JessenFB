import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_to_gym/models/post.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;
  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _descController;
  LatLng? _pickedLocation;
  String _address = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.post.description);
    _address = widget.post.location;
    _pickedLocation = widget.post.lat != null && widget.post.lng != null
        ? LatLng(widget.post.lat!, widget.post.lng!)
        : null;
  }

  Future<void> _reverseGeocode(LatLng latlng) async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latlng.latitude}&lon=${latlng.longitude}');
    final response = await http.get(url, headers: {
      'User-Agent': 'go_to_gym_flutter_app/1.0'
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _pickedLocation = latlng;
        _address = data['display_name'] ?? '${latlng.latitude}, ${latlng.longitude}';
      });
    } else {
      setState(() {
        _pickedLocation = latlng;
        _address = '${latlng.latitude}, ${latlng.longitude}';
      });
    }

    setState(() => _isLoading = false);
  }

  void _pickLocationDialog() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (_) => const MapPickerDialog(),
    );

    if (result != null) {
      await _reverseGeocode(result);
    }
  }

  Future<void> _updatePost() async {
    if (_descController.text.isEmpty || _pickedLocation == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
        'description': _descController.text.trim(),
        'location': _address,
        'lat': _pickedLocation!.latitude,
        'lng': _pickedLocation!.longitude,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Edit Post', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Display image
            if (widget.post.imageBase64.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(widget.post.imageBase64),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _pickLocationDialog,
                  icon: const Icon(Icons.map, color: Colors.white),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (_pickedLocation != null)
              Text(_address, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _updatePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class MapPickerDialog extends StatefulWidget {
  const MapPickerDialog({super.key});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  LatLng? _picked;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Pick a Location", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        height: 300,
        width: double.maxFinite,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(-6.2, 106.8),
            initialZoom: 12,
            onTap: (tapPosition, latlng) {
              setState(() {
                _picked = latlng;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.go_to_gym',
            ),
            if (_picked != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 30),
                  )
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_picked != null) {
              Navigator.of(context).pop(_picked);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please tap to pick a location')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
          ),
          child: const Text("Confirm", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}