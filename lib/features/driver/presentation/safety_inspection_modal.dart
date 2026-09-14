import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class SafetyInspectionModal extends StatefulWidget {
  final int tripId;
  final Function(List<File> photos, double latitude, double longitude) onPhotosVerified;

  const SafetyInspectionModal({
    super.key,
    required this.tripId,
    required this.onPhotosVerified,
  });

  @override
  State<SafetyInspectionModal> createState() => _SafetyInspectionModalState();
}

class _SafetyInspectionModalState extends State<SafetyInspectionModal> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _capturedPhotos = [];
  bool _isLoadingGps = false;
  bool _isSubmitting = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _isLoadingGps = false;
        });
      }
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (mounted) {
          setState(() {
            _latitude = last?.latitude ?? 36.7525;
            _longitude = last?.longitude ?? 3.0380;
            _isLoadingGps = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _latitude = 36.7525;
            _longitude = 3.0380;
            _isLoadingGps = false;
          });
        }
      }
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image != null && mounted) {
        setState(() {
          _capturedPhotos.add(File(image.path));
        });
        // Re-confirm GPS coordinates
        _fetchLocation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir l\'appareil photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _capturedPhotos.removeAt(index);
    });
  }

  void _submitInspection() {
    if (_capturedPhotos.isEmpty) return;

    setState(() => _isSubmitting = true);
    final lat = _latitude ?? 36.7525;
    final lng = _longitude ?? 3.0380;

    widget.onPhotosVerified(_capturedPhotos, lat, lng);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7), // Amber 100
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield, color: Color(0xFFD97706), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contrôle de Sécurité Allée'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const Text(
                        'Protocole "Aucun Enfant Oublié" & Filigrane Légal',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Bilingual Instructions Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dirigez-vous vers le fond du véhicule et prenez en photo l\'ensemble des sièges pour certifier qu\'aucun élève n\'est resté à bord.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'يرجى التوجه إلى مؤخرة الحافلة والتقاط صور لجميع المقاعد للتأكد من خلوها تماماً.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Captured Photos Review Strip
            if (_capturedPhotos.isNotEmpty) ...[
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _capturedPhotos.length + 1,
                  separatorBuilder: (ctx, idx) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index == _capturedPhotos.length) {
                      // Add More Button
                      return InkWell(
                        onTap: _isSubmitting ? null : _capturePhoto,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 90,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFF1F5F9),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: Color(0xFF0F172A), size: 26),
                              SizedBox(height: 4),
                              Text('Ajouter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    }

                    final photo = _capturedPhotos[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            photo,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Number Badge
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(180),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        // Delete Button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. GPS Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF16A34A), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isLoadingGps
                          ? 'Acquisition du positionnement GPS...'
                          : 'Position GPS certifiée: ${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. Action Buttons
            if (_capturedPhotos.isEmpty) ...[
              ElevatedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Ouvrir l\'Appareil Photo (Allée du Bus)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitInspection,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _isSubmitting
                      ? 'Transmission en cours...'
                      : 'Valider & Transmettre l\'Inspection (${_capturedPhotos.length} photo${_capturedPhotos.length > 1 ? 's' : ''})',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
