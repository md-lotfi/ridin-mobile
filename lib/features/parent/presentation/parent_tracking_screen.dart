import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_drawer.dart';
import '../bloc/parent_tracking_bloc.dart';
import 'children_management_screen.dart';
import 'link_child_flow_screen.dart';

class ParentTrackingScreen extends StatefulWidget {
  const ParentTrackingScreen({super.key});

  @override
  State<ParentTrackingScreen> createState() => _ParentTrackingScreenState();
}

class _ParentTrackingScreenState extends State<ParentTrackingScreen> {
  final MapController _mapController = MapController();
  bool _isUserPanning = false;
  bool _isMapReady = false;

  double _computeMinDistanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return 0.0;
    const Distance distance = Distance();
    double minMeters = double.infinity;
    for (final p in polyline) {
      final d = distance.as(LengthUnit.Meter, point, p);
      if (d < minMeters) {
        minMeters = d;
      }
    }
    return minMeters;
  }

  @override
  void initState() {
    super.initState();
    context.read<ParentTrackingBloc>().add(LoadParentTrips());
  }

  void _confirmReportAbsence(BuildContext context, int tripStopId, String childName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'parent.report_absence_confirm_title'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text('parent.report_absence_confirm_msg'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ParentTrackingBloc>().add(
                ReportAbsenceRequested(tripStopId: tripStopId),
              );
            },
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: Text('parent.report_absence'.tr()),
          ),
        ],
      ),
    );
  }

  void _showBusDetailsSheet(BuildContext context, Map<String, dynamic> trip) {
    final vehicle = trip['vehicle'] as Map<String, dynamic>?;
    final stops = (trip['stops'] as List<dynamic>? ?? []);
    final myStop = stops.isNotEmpty ? (stops.first as Map<String, dynamic>) : null;
    final driverName = vehicle?['driver_name'] ?? 'Chauffeur assigné';
    final driverPhone = vehicle?['driver_phone'];
    final vehicleName = vehicle?['name'] ?? 'Bus Scolaire';
    final plateNumber = vehicle?['plate_number'] ?? '';
    final isTripActive = trip['is_active'] as bool? ?? (trip['status'] == 'in_progress');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.blue.shade50,
                    child: const Icon(Icons.directions_bus, color: Color(0xFF0284C7), size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'Matricule : $plateNumber',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isTripActive ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isTripActive ? Colors.green.shade200 : Colors.blue.shade200,
                      ),
                    ),
                    child: Text(
                      isTripActive ? 'En route' : 'Programmé',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isTripActive ? Colors.green.shade800 : Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Color(0xFF475569)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (driverPhone != null)
                          Text(
                            driverPhone,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  if (driverPhone != null)
                    IconButton.filledTonal(
                      onPressed: () async {
                        final uri = Uri.parse('tel:$driverPhone');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      icon: const Icon(Icons.phone),
                    ),
                ],
              ),
              if (myStop?['address_label'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.pin_drop_outlined, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Point de ramassage : ${myStop!['address_label']}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text('parent.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Gérer mes élèves',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChildrenManagementScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ParentTrackingBloc>().add(LoadParentTrips()),
          ),
        ],
      ),
      body: BlocConsumer<ParentTrackingBloc, ParentTrackingState>(
        listener: (context, state) {
          if (state is ParentTrackingActive) {
            if (state.activeAlert != null) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.activeAlert!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF0F172A),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ),
              );
            }

            // Auto-follow moving bus if map is rendered and user is not manually panning
            final activeIndex = state.selectedTripIndex < state.trips.length ? state.selectedTripIndex : 0;
            if (_isMapReady && !_isUserPanning && state.trips.isNotEmpty) {
              final tripId = state.trips[activeIndex]['id'] as int;
              final liveLoc = state.liveBusPositions[tripId];
              if (liveLoc != null && liveLoc['latitude'] != null) {
                final lat = (liveLoc['latitude'] as num).toDouble();
                final lng = (liveLoc['longitude'] as num).toDouble();
                try {
                  _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
                } catch (_) {}
              }
            }
          }
        },
        builder: (context, state) {
          if (state is ParentTrackingLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 1. EMPTY ONBOARDING HUB
          if (state is ParentTrackingEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_bus_filled_rounded, size: 44, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Bienvenue sur Ridin',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Associez le code remis par l\'école pour activer le suivi en temps réel du bus scolaire.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LinkChildFlowScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(260, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Associer un Élève (Code / QR)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChildrenManagementScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(260, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Gérer mes élèves'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => context.read<ParentTrackingBloc>().add(LoadParentTrips()),
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Actualiser'),
                    ),
                  ],
                ),
              ),
            );
          }

          // 2. HOLD FOR SCHOOL APPROVAL STATUS CARD
          if (state is ParentTrackingPendingApproval) {
            final firstPending = state.pendingStops.first;
            final childName = firstPending['child_name'] ?? 'Votre enfant';
            final schoolName = firstPending['school_name'] ?? 'Établissement';
            final vehicleName = firstPending['vehicle_name'] ?? 'Bus scolaire';
            final driverName = firstPending['driver_name'];
            final driverPhone = firstPending['driver_phone'];
            final address = firstPending['address_label'] ?? 'Repère sélectionné';

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.hourglass_top_rounded, size: 36, color: Colors.amber.shade800),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Arrêt en cours d\'examen par l\'école',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Votre demande de transport a bien été reçue. L\'administration examine l\'accessibilité du minibus avant de déverrouiller la carte en direct.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.amber.shade100,
                                child: Text(
                                  childName[0],
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      childName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      schoolName,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'En attente',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.directions_bus_outlined, size: 18, color: Color(0xFF475569)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$vehicleName ${driverName != null ? '• Chauffeur: $driverName' : ''}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (driverPhone != null)
                                IconButton.filledTonal(
                                  iconSize: 18,
                                  onPressed: () async {
                                    final uri = Uri.parse('tel:$driverPhone');
                                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                                  },
                                  icon: const Icon(Icons.phone),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Repère de ramassage : $address',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: () => context.read<ParentTrackingBloc>().add(LoadParentTrips()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.sync),
                      label: const Text('Vérifier la validation de l\'arrêt', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChildrenManagementScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Gérer mes élèves / Demandes'),
                    ),
                  ],
                ),
              ),
            );
          }

          // 2.5 STANDBY CARD (Enrolled pupils with approved stops, waiting for next circuit run)
          if (state is ParentTrackingStandby) {
            final children = state.registeredChildren;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Icon(Icons.verified_rounded, size: 38, color: Color(0xFF059669)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Circuit Scolaire Prêt',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'L\'arrêt de ramassage est validé par l\'école. Le suivi en direct s\'activera dès que le chauffeur démarrera sa tournée.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),

                      // Children Cards
                      ...children.map((child) {
                        final childName = child['full_name'] ?? child['first_name'] ?? 'Votre enfant';
                        final grade = child['school_grade'] ?? 'Élève';
                        final school = child['school_name'] ?? 'Établissement scolaire';
                        final vehicle = child['vehicle'] as Map<String, dynamic>?;
                        final driver = child['driver'] as Map<String, dynamic>?;
                        final stop = child['approved_stop'] as Map<String, dynamic>?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFFEF3C7),
                                    child: Text(
                                      childName.isNotEmpty ? childName[0].toUpperCase() : 'E',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          childName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          '$grade • $school',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Validé',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              if (vehicle != null) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.directions_bus_rounded, size: 18, color: Color(0xFF475569)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${vehicle['name']} (${vehicle['plate_number']})',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (driver != null) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.person_pin_rounded, size: 18, color: Color(0xFF475569)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Chauffeur: ${driver['name']}',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                      ),
                                    ),
                                    if (driver['phone'] != null)
                                      IconButton.filledTonal(
                                        iconSize: 18,
                                        onPressed: () async {
                                          final uri = Uri.parse('tel:${driver['phone']}');
                                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                                        },
                                        icon: const Icon(Icons.phone),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (stop != null) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.pin_drop_rounded, size: 18, color: Color(0xFFEF4444)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Arrêt : ${stop['address_label'] ?? 'Position GPS validée'}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.read<ParentTrackingBloc>().add(LoadParentTrips()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.sync),
                        label: const Text('Actualiser le statut', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChildrenManagementScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Gérer mes élèves'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // 3. ACTIVE RADAR MAP
          if (state is ParentTrackingActive) {
            final activeIndex = (state.selectedTripIndex >= 0 && state.selectedTripIndex < state.trips.length)
                ? state.selectedTripIndex
                : 0;
            final firstTrip = state.trips[activeIndex];
            final tripId = firstTrip['id'] as int;
            final isTripActive = firstTrip['is_active'] as bool? ?? (firstTrip['status'] == 'in_progress');
            final vehicle = firstTrip['vehicle'] as Map<String, dynamic>?;
            final stops = (firstTrip['stops'] as List<dynamic>? ?? []);
            final myStop = stops.isNotEmpty ? (stops.first as Map<String, dynamic>) : null;

            final liveLoc = state.liveBusPositions[tripId];
            final initialBusPos = firstTrip['initial_bus_position'] as Map<String, dynamic>?;

            final busLat = (liveLoc?['latitude'] as num?)?.toDouble()
                ?? (!isTripActive ? (initialBusPos?['latitude'] as num?)?.toDouble() : null)
                ?? (myStop?['latitude'] as num?)?.toDouble()
                ?? 36.7538;
            final busLng = (liveLoc?['longitude'] as num?)?.toDouble()
                ?? (!isTripActive ? (initialBusPos?['longitude'] as num?)?.toDouble() : null)
                ?? (myStop?['longitude'] as num?)?.toDouble()
                ?? 3.0588;
            final busSpeed = (liveLoc?['speed'] as num?)?.toDouble() ?? 0.0;
            final busPosition = LatLng(busLat, busLng);

            LatLng? stopPosition;
            if (myStop != null && myStop['latitude'] != null) {
              stopPosition = LatLng(
                (myStop['latitude'] as num).toDouble(),
                (myStop['longitude'] as num).toDouble(),
              );
            }

            final isStopPending = myStop != null && myStop['completion_status'] == 'pending';
            final isApproaching = state.isApproaching ||
                (isStopPending && myStop['alert_outer_sent_at'] != null);

            final childName = myStop?['child_name'] as String? ?? 'Votre enfant';
            final tripStopId = myStop?['trip_stop_id'] as int?;
            final tripSettings = firstTrip['settings'] as Map<String, dynamic>?;
            final allowDelay = tripSettings?['allow_delay_2m'] as bool? ?? true;
            final allowAbsence = tripSettings?['allow_absence_reporting'] as bool? ?? true;
            final traveledPath = state.traveledPaths[tripId] ?? [busPosition];
            final roadPathAhead = state.plannedRoadPaths[tripId];
            final List<LatLng> plannedPolylinePoints = (roadPathAhead != null && roadPathAhead.isNotEmpty)
                ? roadPathAhead
                : (stopPosition != null ? [busPosition, stopPosition] : []);

            final bool isDetour = isTripActive &&
                plannedPolylinePoints.length > 1 &&
                _computeMinDistanceToPolyline(busPosition, plannedPolylinePoints) > 250.0;

            return Stack(
              children: [
                // OpenStreetMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: busPosition,
                    initialZoom: 15.0,
                    onMapReady: () {
                      if (mounted) {
                        setState(() => _isMapReady = true);
                      }
                    },
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture && !_isUserPanning) {
                        setState(() => _isUserPanning = true);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'dz.ridin.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        // Traveled Path (Solid Amber when active)
                        if (isTripActive && traveledPath.length > 1)
                          Polyline(
                            points: traveledPath,
                            color: const Color(0xFFF59E0B),
                            strokeWidth: 5.0,
                            strokeJoin: StrokeJoin.round,
                          ),
                        // Planned Path (Transit Blue when normal, Red when detour detected, Dotted Blue when inactive)
                        if (plannedPolylinePoints.length > 1)
                          Polyline(
                            points: plannedPolylinePoints,
                            color: isDetour ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                            strokeWidth: 4.5,
                            pattern: isTripActive
                                ? StrokePattern.dashed(segments: const [6, 8])
                                : const StrokePattern.dotted(spacingFactor: 2.5),
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Bus Marker (Offline Grey when inactive, Obsidian Amber when active)
                        Marker(
                          point: busPosition,
                          width: 50,
                          height: 50,
                          child: GestureDetector(
                            onTap: () => _showBusDetailsSheet(context, firstTrip),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isTripActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isTripActive ? const Color(0xFFF59E0B) : Colors.grey.shade400,
                                  width: 2.5,
                                ),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
                              ),
                              child: Icon(
                                Icons.directions_bus,
                                color: isTripActive ? const Color(0xFFF59E0B) : Colors.grey.shade200,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        // My Child Stop Marker
                        if (stopPosition != null)
                          Marker(
                            point: stopPosition,
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.pin_drop, color: Colors.red, size: 40),
                          ),
                        // School Destination Marker (if circuit route exists)
                        if (plannedPolylinePoints.isNotEmpty &&
                            (stopPosition == null ||
                             (stopPosition.latitude != plannedPolylinePoints.last.latitude &&
                              stopPosition.longitude != plannedPolylinePoints.last.longitude)))
                          Marker(
                            point: plannedPolylinePoints.last,
                            width: 38,
                            height: 38,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Icon(Icons.school, color: Colors.white, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Top Multiple Subscriptions Pill Switcher
                if (state.trips.length > 1)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(state.trips.length, (i) {
                            final tr = state.trips[i];
                            final v = tr['vehicle'] as Map<String, dynamic>?;
                            final st = (tr['stops'] as List<dynamic>? ?? []).firstOrNull as Map<String, dynamic>?;
                            final isSel = i == activeIndex;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('${st?['child_name'] ?? 'Élève'} • ${v?['name'] ?? 'Bus'}'),
                                selected: isSel,
                                selectedColor: const Color(0xFF0F172A),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  context.read<ParentTrackingBloc>().add(SelectTripRequested(i));
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),

                // Inactive Ride Status Banner (Top)
                if (!isTripActive)
                  Positioned(
                    top: state.trips.length > 1 ? 60 : 16,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, color: Color(0xFF60A5FA), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Circuit programmé • En attente du départ du bus',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Detour Alert Banner (When active bus deviates > 250m from planned circuit)
                if (isTripActive && isDetour)
                  Positioned(
                    top: state.trips.length > 1 ? 60 : 16,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Détour détecté : le bus s\'est éloigné du circuit prévu (> 250m)',
                                style: TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Approaching Alert Banner
                if (isTripActive && isApproaching && isStopPending)
                  Positioned(
                    top: state.trips.length > 1 ? 60 : 16,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notifications_active, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'parent.bus_approaching'.tr(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                if (state.distanceMeters != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${state.distanceMeters}m (~${state.etaMinutes ?? 3} min)',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF10B981),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      if (tripStopId != null) {
                                        context.read<ParentTrackingBloc>().add(
                                          AcknowledgeStopRequested(
                                            tripStopId: tripStopId,
                                            status: 'acknowledged_ready',
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: Text('parent.im_ready'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                if (allowDelay) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black26,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      if (tripStopId != null) {
                                        context.read<ParentTrackingBloc>().add(
                                          AcknowledgeStopRequested(
                                            tripStopId: tripStopId,
                                            status: 'acknowledged_delayed_2m',
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.timer_outlined, size: 18),
                                    label: Text('parent.delay_2m'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Recenter Button
                if (_isUserPanning)
                  Positioned(
                    bottom: 175,
                    right: 16,
                    child: SafeArea(
                      bottom: true,
                      child: FloatingActionButton.extended(
                        heroTag: 'parent_recenter_btn',
                        onPressed: () {
                          setState(() => _isUserPanning = false);
                          try {
                            _mapController.move(busPosition, 16.0);
                          } catch (_) {}
                        },
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 6,
                        icon: const Icon(Icons.my_location, color: Color(0xFFF59E0B), size: 18),
                        label: const Text('Recentrer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                // Bottom Driver Card
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    bottom: true,
                    child: GestureDetector(
                      onTap: () => _showBusDetailsSheet(context, firstTrip),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade50,
                                  child: const Icon(Icons.person, color: Color(0xFF0284C7)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vehicle?['driver_name'] ?? 'Chauffeur',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        '${vehicle?['name']} • ${vehicle?['plate_number']}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isStopPending && tripStopId != null && allowAbsence)
                                  TextButton.icon(
                                    onPressed: () => _confirmReportAbsence(context, tripStopId, childName),
                                    icon: const Icon(Icons.person_off_outlined, color: Colors.red, size: 16),
                                    label: Text(
                                      'parent.absent'.tr(),
                                      style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                if (vehicle?['driver_phone'] != null)
                                  IconButton.filledTonal(
                                    onPressed: () async {
                                      final uri = Uri.parse('tel:${vehicle!['driver_phone']}');
                                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                                    },
                                    icon: const Icon(Icons.phone),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isTripActive
                                        ? '${'parent.speed'.tr()}: ${busSpeed.toStringAsFixed(0)} ${'common.kmh'.tr()}'
                                        : 'Trajet non démarré',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  if (myStop != null)
                                    Text(
                                      'Statut: ${myStop['completion_status'] == 'boarded' ? 'parent.boarded'.tr() : (myStop['completion_status'] == 'absent' ? 'parent.absent'.tr() : (isTripActive ? 'En route' : 'Programmé'))}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: myStop['completion_status'] == 'boarded'
                                            ? Colors.green
                                            : (myStop['completion_status'] == 'absent' ? Colors.red : Colors.blue),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
