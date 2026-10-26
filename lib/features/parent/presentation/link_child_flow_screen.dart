import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../bloc/parent_tracking_bloc.dart';

class LinkChildFlowScreen extends StatefulWidget {
  const LinkChildFlowScreen({super.key});

  @override
  State<LinkChildFlowScreen> createState() => _LinkChildFlowScreenState();
}

class _LinkChildFlowScreenState extends State<LinkChildFlowScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController(
    text: 'Mon domicile',
  );
  final TextEditingController _codeController = TextEditingController();

  int _currentStep = 1; // 1: Pin Map, 2: Enter Code
  LatLng _pinnedLocation = const LatLng(36.7525, 3.0420); // Alger default
  bool _isLoading = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _codeController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _determineInitialPosition() async {
    setState(() => _isLocating = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _pinnedLocation = LatLng(pos.latitude, pos.longitude);
          _isLocating = false;
        });
        _mapController.move(_pinnedLocation, 16.0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _verifyAndProceed() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length < 4) {
      _showInvalidCodeDialog(
        'Veuillez saisir un code élève valide (ex: RID-8X2K).',
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiClient = context.read<ApiClient>();

    try {
      final response = await apiClient.dio.post(
        '/parent/children/verify-code',
        data: {'link_code': code},
      );

      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() => _isLoading = false);
        _showConfirmationBottomSheet(data, code);
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final apiException = ApiException.fromDioError(e);
        _showInvalidCodeDialog(apiException.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showInvalidCodeDialog(
          'Code élève introuvable ou incorrect. Veuillez vérifier le document remis par l\'école.',
        );
      }
    }
  }

  void _showInvalidCodeDialog(String message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade700,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Code Élève Invalide',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Réessayer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmationBottomSheet(
    Map<String, dynamic> data,
    String linkCode,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Demander l’accès au suivi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'L’école vérifiera votre identité et votre lien avec l’élève. Les informations de transport seront disponibles après approbation.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _confirmClaim(linkCode, ctx),
                child: const Text('Soumettre la demande'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClaim(String linkCode, BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    setState(() => _isLoading = true);

    final apiClient = context.read<ApiClient>();
    try {
      await apiClient.dio.post(
        '/parent/children/claim',
        data: {
          'link_code': linkCode,
          'latitude': _pinnedLocation.latitude,
          'longitude': _pinnedLocation.longitude,
          'address_label': _addressController.text.trim(),
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
        context.read<ParentTrackingBloc>().add(LoadParentTrips());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Demande transmise. L’école doit vérifier votre identité avant d’autoriser le suivi.',
            ),
            backgroundColor: Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final apiException = ApiException.fromDioError(e);
        _showInvalidCodeDialog(apiException.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showInvalidCodeDialog(
          'Une erreur est survenue lors de l\'enregistrement. Veuillez réessayer.',
        );
      }
    }
  }

  void _openQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: 450,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scanner le Badge QR de l\'Élève',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      final scanned = barcode.rawValue!.trim().toUpperCase();
                      Navigator.of(ctx).pop();
                      setState(() {
                        _codeController.text = scanned;
                      });
                      _verifyAndProceed();
                      break;
                    }
                  }
                },
              ),
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
        title: Text(
          _currentStep == 1 ? '1. Épingler le Domicile' : '2. Code Élève',
        ),
      ),
      body: Stack(
        children: [
          if (_currentStep == 1) ...[
            // STEP 1: Interactive Leaflet / OSM Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pinnedLocation,
                initialZoom: 16.0,
                onPositionChanged: (camera, hasGesture) {
                  _pinnedLocation = camera.center;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'dz.raystate.ridin',
                ),
              ],
            ),

            // Center Pin Marker
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_pin, size: 52, color: Colors.red),
              ),
            ),

            // Locate Me FAB
            Positioned(
              right: 16,
              bottom: 170,
              child: FloatingActionButton.small(
                heroTag: 'locate_me_btn',
                onPressed: _determineInitialPosition,
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                child: _isLocating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),

            // Step 1 Bottom Card
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                bottom: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 16),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Déplacez la carte sous le repère rouge',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          hintText: 'ex: Résidence Les Pins, Entrée A',
                          prefixIcon: const Icon(Icons.home_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => setState(() => _currentStep = 2),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Continuer vers le Code Élève',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // STEP 2: Enter Code & QR Scan
            SafeArea(
              bottom: true,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Code Élève ou Badge QR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Saisissez le code à 6 caractères ou scannez le badge remis par l\'école de votre enfant',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Code Input Field
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'RID-XXXX',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_2_rounded, size: 28),
                            onPressed: _openQrScanner,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: _openQrScanner,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Scanner le Badge QR'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _verifyAndProceed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Vérifier et Prévisualiser le Circuit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),

                      TextButton.icon(
                        onPressed: () => setState(() => _currentStep = 1),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text(
                          'Retour à la carte pour ajuster l\'arrêt',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
