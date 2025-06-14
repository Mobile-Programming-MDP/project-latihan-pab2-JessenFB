import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _descController = TextEditingController();
  LatLng? _pickedLocation;
  String _address = '';
  bool _isLoading = false;

  File? _pickedImage;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      final file = File(picked.path);
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 25,
        format: CompressFormat.jpeg,
      );

      if (compressed != null) {
        setState(() {
          _pickedImage = file;
          _base64Image = base64Encode(compressed);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image compression failed')),
        );
      }
    }
  }

  Future<void> _reverseGeocode(LatLng latlng) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latlng.latitude}&lon=${latlng.longitude}',
    );
    final resp = await http.get(
      url,
      headers: {'User-Agent': 'go_to_gym_flutter_app/1.0'},
    );
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      setState(() {
        _pickedLocation = latlng;
        _address =
            data['display_name'] ?? '${latlng.latitude}, ${latlng.longitude}';
      });
    } else {
      setState(() {
        _pickedLocation = latlng;
        _address = '${latlng.latitude}, ${latlng.longitude}';
      });
    }
  }

  void _pickLocationDialog() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (_) => const MapPickerDialog(),
    );
    if (result != null) await _reverseGeocode(result);
  }

  Future<void> _submitPost() async {
    if (_descController.text.isEmpty ||
        _pickedLocation == null ||
        _base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add description, pick location and image'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final username = userDoc.data()?['username'] ?? 'Anonymous';

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': uid,
        'username': username,
        'description': _descController.text.trim(),
        'image': _base64Image,
        'location': _address,
        'lat': _pickedLocation!.latitude,
        'lng': _pickedLocation!.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('🚨 Error creating post: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to submit post')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black,
            size: 26,
          ),
          onPressed: () => Navigator.pop(context),
          splashRadius: 24,
          tooltip: 'Close',
        ),
        title: Text(
          'Create Post',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePicker(),
            const SizedBox(height: 16),
            _buildInputCard(
              label: 'Description',
              controller: _descController,
              hintText: 'Write something inspiring...',
            ),
            const SizedBox(height: 24),
            Text(
              'Location',
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.9) : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickLocationDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _pickedLocation != null
                              ? _address
                              : 'Tap to select location',
                          key: ValueKey(_address),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _submitPost,
                        label: const Text(
                          'Post',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String label,
    required TextEditingController controller,
    required String hintText,
  }) {
    final borderColor = isDark
        ? Colors.white24
        : Colors.grey.shade400; // Border yang konsisten

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          minLines: 3,
          maxLines: null, // Tak terbatas, akan mengikuti isi teks
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade600),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: _pickedImage == null
            ? Center(
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 48,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_pickedImage!, fit: BoxFit.cover),
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
  final _mapController = MapController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  Future<void> _moveToCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final latlng = LatLng(pos.latitude, pos.longitude);
    _mapController.move(latlng, 15);
    setState(() => _picked = latlng);
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 3) return;
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5',
    );
    final resp = await http.get(
      url,
      headers: {'User-Agent': 'go_to_gym_flutter_app/1.0'},
    );
    if (resp.statusCode == 200) {
      final List data = json.decode(resp.body);
      setState(() {
        _searchResults = data.cast<Map<String, dynamic>>();
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = double.parse(item['lat']);
    final lon = double.parse(item['lon']);
    final latlng = LatLng(lat, lon);
    _mapController.move(latlng, 15);
    setState(() {
      _picked = latlng;
      _searchResults.clear();
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text("📍 Pick a Location", style: TextStyle(color: textColor)),
      content: SizedBox(
        height: 450,
        width: double.maxFinite,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search place...',
                  hintStyle: TextStyle(color: textColor),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade600),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey.shade700,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: cardColor.withOpacity(0.7),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: textColor.withOpacity(0.7)),
                    onPressed: () => _searchLocation(_searchController.text),
                  ),
                ),
                onSubmitted: _searchLocation,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(-6.2, 106.8),
                        initialZoom: 13,
                        onTap: (tap, latlng) {
                          setState(() => _picked = latlng);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.go_to_gym',
                        ),
                        if (_picked != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _picked!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (_searchResults.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: cardColor,
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (c, i) {
                              final item = _searchResults[i];
                              return ListTile(
                                title: Text(
                                  item['display_name'],
                                  style: TextStyle(color: textColor),
                                ),
                                onTap: () => _selectSearchResult(item),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _moveToCurrentLocation,
          child: const Text(
            "📍 Use My Location",
            style: TextStyle(color: Colors.blueAccent),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text("Confirm", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
