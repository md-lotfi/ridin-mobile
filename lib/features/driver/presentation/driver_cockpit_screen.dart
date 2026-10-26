import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_drawer.dart';
import '../bloc/driver_cockpit_bloc.dart';
import 'safety_inspection_modal.dart';

class DriverCockpitScreen extends StatefulWidget {
  const DriverCockpitScreen({super.key});

  @override
  State<DriverCockpitScreen> createState() => _DriverCockpitScreenState();
}

class _DriverCockpitScreenState extends State<DriverCockpitScreen> {
  final MapController _mapController = MapController();
  bool _isUserPanning = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    context.read<DriverCockpitBloc>().add(LoadCurrentTrip());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text('driver.cockpit'.tr()),
        actions: [
          BlocBuilder<DriverCockpitBloc, DriverCockpitState>(
            builder: (context, state) {
              if (state is DriverCockpitActive) {
                final score = state.driverSafetyScore;
                final Color scoreColor = score >= 90
                    ? const Color(0xFF10B981)
                    : (score >= 75 ? const Color(0xFF3B82F6) : (score >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)));

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: scoreColor),
                      const SizedBox(width: 4),
                      Text(
                        '★ $score/100',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DriverCockpitBloc>().add(LoadCurrentTrip()),
          ),
        ],
      ),
      body: BlocConsumer<DriverCockpitBloc, DriverCockpitState>(
        listener: (context, state) {
          if (state is DriverCockpitActive) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
              );
            }

            // Auto-follow moving vehicle ONLY if map is rendered and driver is not manually panning
            if (_isMapReady && !_isUserPanning) {
              try {
                _mapController.move(
                  LatLng(state.currentLatitude, state.currentLongitude),
                  _mapController.camera.zoom,
                );
              } catch (_) {}
            }
          }
        },
        builder: (context, state) {
          if (state is DriverCockpitRestricted) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(state.message, textAlign: TextAlign.center)));
          }
          if (state is DriverCockpitLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DriverCockpitNoTrip) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'driver.no_trip'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.read<DriverCockpitBloc>().add(LoadCurrentTrip()),
                      icon: const Icon(Icons.sync),
                      label: const Text('Actualiser'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is DriverCockpitActive) {
            final trip = state.trip;
            final stops = (trip['trip_stops'] as List<dynamic>? ?? [])
                .where((s) => s['completion_status'] == 'pending')
                .toList();
            final nextStop = stops.isNotEmpty ? stops.first : null;
            final isStarted = trip['status'] == 'in_progress';
            final busPosition = LatLng(state.currentLatitude, state.currentLongitude);

            final List<LatLng> plannedPoints = [busPosition];
            for (final s in stops) {
              final stopData = s['stop'];
              if (stopData != null && stopData['latitude'] != null && stopData['longitude'] != null) {
                plannedPoints.add(LatLng(
                  (stopData['latitude'] as num).toDouble(),
                  (stopData['longitude'] as num).toDouble(),
                ));
              }
            }

            final List<LatLng> effectiveRoadPath = state.plannedRoadPath.isNotEmpty
                ? state.plannedRoadPath
                : plannedPoints;

            return Stack(
              children: [
                // 1. OpenStreetMap
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
                        // Traveled Path (Solid amber trail driven so far)
                        if (state.traveledPath.length > 1)
                          Polyline(
                            points: state.traveledPath,
                            color: const Color(0xFFF59E0B),
                            strokeWidth: 5.0,
                            strokeJoin: StrokeJoin.round,
                          ),
                        // Planned Circuit (Dashed vibrant Transit Blue route along exact road network)
                        if (effectiveRoadPath.length > 1)
                          Polyline(
                            points: effectiveRoadPath,
                            color: const Color(0xFF2563EB),
                            strokeWidth: 4.5,
                            pattern: StrokePattern.dashed(segments: const [6, 8]),
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Bus Marker
                        Marker(
                          point: busPosition,
                          width: 48,
                          height: 48,
                          child: Transform.rotate(
                            angle: (state.currentHeading * 3.14159 / 180),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                              ),
                              child: const Icon(Icons.navigation, color: Colors.amber, size: 28),
                            ),
                          ),
                        ),
                        // Stops Markers
                        ...stops.where((s) => s['stop'] != null && s['stop']['latitude'] != null && s['stop']['longitude'] != null).map((s) {
                          final stopData = s['stop'] as Map<String, dynamic>;
                          final lat = (stopData['latitude'] as num).toDouble();
                          final lng = (stopData['longitude'] as num).toDouble();
                          final isNext = s == nextStop;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on,
                              color: isNext ? Colors.red : Colors.blue,
                              size: isNext ? 40 : 28,
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),

                // 2. Speed Radar Indicator (Top Left)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: state.isSpeeding ? const Color(0xFFDC2626) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      border: state.isSpeeding ? Border.all(color: Colors.red.shade900, width: 2) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${state.currentSpeed.toStringAsFixed(0)} ${'common.kmh'.tr()}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: state.isSpeeding ? Colors.white : Colors.black87,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: state.isSpeeding ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'MAX ${state.organizationSpeedLimit}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: state.isSpeeding ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (state.isSpeeding)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'driver.speeding_alert'.tr(),
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 2.5 Floating Recenter Button (Appears when driver manually drags map)
                if (_isUserPanning)
                  Positioned(
                    bottom: nextStop != null ? 240 : 100,
                    right: 16,
                    child: SafeArea(
                      top: false,
                      bottom: true,
                      child: FloatingActionButton.extended(
                        heroTag: 'driver_recenter_btn',
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
                        label: const Text(
                          'Recentrer',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),

                // 3. Trip Status & Next Stop Card (Bottom)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isStarted) ...[
                          ElevatedButton.icon(
                            onPressed: () => context.read<DriverCockpitBloc>().add(StartTripRequested(trip['id'] as int)),
                            icon: const Icon(Icons.play_arrow),
                            label: Text('driver.start_trip'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ] else ...[
                          if (nextStop != null) ...[
                            _buildNextStopCard(context, trip['id'] as int, nextStop),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              // Delay Button
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDelayModal(context, trip['id'] as int),
                                  icon: const Icon(Icons.traffic, size: 18),
                                  label: Text('driver.broadcast_delay'.tr(), style: const TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // End Trip Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (!state.isSafetyCheckVerified) {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) => SafetyInspectionModal(
                                          tripId: trip['id'] as int,
                                          onPhotosVerified: (photos, lat, lng) {
                                            context.read<DriverCockpitBloc>().add(SafetyCheckCompleted(
                                              tripId: trip['id'] as int,
                                              method: 'live_photo_watermark',
                                              photos: photos,
                                              latitude: lat,
                                              longitude: lng,
                                            ));
                                          },
                                        ),
                                      );
                                    } else {
                                      context.read<DriverCockpitBloc>().add(EndTripRequested(trip['id'] as int));
                                    }
                                  },
                                  icon: Icon(
                                    state.isSafetyCheckVerified ? Icons.check_circle : Icons.shield,
                                    size: 18,
                                  ),
                                  label: Text('driver.end_trip'.tr(), style: const TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: state.isSafetyCheckVerified ? Colors.red.shade700 : Colors.amber.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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

  Widget _buildNextStopCard(BuildContext context, int tripId, Map<String, dynamic> stopEntry) {
    final stop = stopEntry['stop'] as Map<String, dynamic>?;
    final child = stop?['child'] as Map<String, dynamic>?;
    final parent = child?['parent'] as Map<String, dynamic>?;
    final tripStopId = stopEntry['id'] as int;
    final parentPhone = parent?['phone'] as String?;
    final ackStatus = stopEntry['acknowledgement_status'] as String?;
    final childName = child != null
        ? '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'.trim()
        : 'Élève';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'driver.next_stop'.tr().toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              if (ackStatus == 'acknowledged_ready')
                const Chip(
                  label: Text('Parent Prêt !', style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Color(0xFF10B981),
                  padding: EdgeInsets.zero,
                )
              else if (ackStatus == 'acknowledged_delayed_2m')
                const Chip(
                  label: Text('Attendre 2 min', style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Color(0xFFF59E0B),
                  padding: EdgeInsets.zero,
                )
              else if (stopEntry['completion_status'] == 'absent')
                const Chip(
                  label: Text('Absent (Signalé)', style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            childName.isNotEmpty ? childName : 'Élève',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            stop?['address_label'] ?? 'Arrêt de ramassage',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (parentPhone != null)
                IconButton.filledTonal(
                  onPressed: () async {
                    context.read<DriverCockpitBloc>().add(CallAttemptRequested(
                      tripId: tripId,
                      tripStopId: tripStopId,
                    ));
                    final uri = Uri.parse('tel:$parentPhone');
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  icon: const Icon(Icons.phone),
                  tooltip: 'driver.call_parent'.tr(),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<DriverCockpitBloc>().add(CompleteStopRequested(
                      tripId: tripId,
                      tripStopId: tripStopId,
                      status: 'boarded',
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('driver.mark_boarded'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  context.read<DriverCockpitBloc>().add(CompleteStopRequested(
                    tripId: tripId,
                    tripStopId: tripStopId,
                    status: 'absent',
                  ));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('driver.mark_absent'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDelayModal(BuildContext context, int tripId) {
    int minutes = 10;
    final reasonController = TextEditingController(text: 'Embouteillages');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('driver.broadcast_delay'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'driver.delay_reason'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<DriverCockpitBloc>().add(BroadcastDelayRequested(
                  tripId: tripId,
                  minutes: minutes,
                  reason: reasonController.text,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Diffuser aux parents'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
