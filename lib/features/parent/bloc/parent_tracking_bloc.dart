import '../../../core/errors/api_exception.dart';
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/network/centrifugo_service.dart';
import '../../../core/services/notification_service.dart';

// EVENTS
abstract class ParentTrackingEvent extends Equatable {
  const ParentTrackingEvent();
  @override
  List<Object?> get props => [];
}

class LoadParentTrips extends ParentTrackingEvent {}

class BusLocationReceived extends ParentTrackingEvent {
  final int tripId;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;

  const BusLocationReceived({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
  });

  @override
  List<Object?> get props => [tripId, latitude, longitude, speed, heading];
}

class StopAlertReceived extends ParentTrackingEvent {
  final int tripId;
  final int stopId;
  final String status;
  const StopAlertReceived({
    required this.tripId,
    required this.stopId,
    required this.status,
  });
  @override
  List<Object?> get props => [tripId, stopId, status];
}

class TransitNotificationReceived extends ParentTrackingEvent {
  final String
  type; // approaching_stop, bus_arrived, child_boarded, trip_completed, trip_started
  final String title;
  final String message;
  final int? tripId;
  final int? tripStopId;
  final int? distanceMeters;
  final int? etaMinutes;

  const TransitNotificationReceived({
    required this.type,
    required this.title,
    required this.message,
    this.tripId,
    this.tripStopId,
    this.distanceMeters,
    this.etaMinutes,
  });

  @override
  List<Object?> get props => [
    type,
    title,
    message,
    tripId,
    tripStopId,
    distanceMeters,
    etaMinutes,
  ];
}

class AcknowledgeStopRequested extends ParentTrackingEvent {
  final int tripStopId;
  final String status; // 'acknowledged_ready' or 'acknowledged_delayed_2m'

  const AcknowledgeStopRequested({
    required this.tripStopId,
    required this.status,
  });

  @override
  List<Object?> get props => [tripStopId, status];
}

class ReportAbsenceRequested extends ParentTrackingEvent {
  final int tripStopId;
  final String? reason;

  const ReportAbsenceRequested({required this.tripStopId, this.reason});

  @override
  List<Object?> get props => [tripStopId, reason];
}

class SelectTripRequested extends ParentTrackingEvent {
  final int tripIndex;
  const SelectTripRequested(this.tripIndex);
  @override
  List<Object?> get props => [tripIndex];
}

// STATES
abstract class ParentTrackingState extends Equatable {
  const ParentTrackingState();
  @override
  List<Object?> get props => [];
}

class ParentTrackingInitial extends ParentTrackingState {}

class ParentTrackingLoading extends ParentTrackingState {}

class ParentTrackingEmpty extends ParentTrackingState {}

class ParentTrackingPendingApproval extends ParentTrackingState {
  final List<Map<String, dynamic>> pendingStops;
  const ParentTrackingPendingApproval(this.pendingStops);
  @override
  List<Object?> get props => [pendingStops];
}

class ParentTrackingStandby extends ParentTrackingState {
  final List<Map<String, dynamic>> registeredChildren;
  const ParentTrackingStandby(this.registeredChildren);
  @override
  List<Object?> get props => [registeredChildren];
}

class ParentTrackingActive extends ParentTrackingState {
  final List<Map<String, dynamic>> trips;
  final int selectedTripIndex;
  final List<Map<String, dynamic>> pendingStops;
  final Map<int, Map<String, dynamic>> liveBusPositions;
  final Map<int, List<LatLng>> traveledPaths;
  final Map<int, List<LatLng>> plannedRoadPaths;
  final String? activeAlert;
  final String? alertType;
  final bool isApproaching;
  final int? distanceMeters;
  final int? etaMinutes;
  final bool isBoarded;
  final bool isTripCompleted;

  const ParentTrackingActive({
    required this.trips,
    this.selectedTripIndex = 0,
    this.pendingStops = const [],
    this.liveBusPositions = const {},
    this.traveledPaths = const {},
    this.plannedRoadPaths = const {},
    this.activeAlert,
    this.alertType,
    this.isApproaching = false,
    this.distanceMeters,
    this.etaMinutes,
    this.isBoarded = false,
    this.isTripCompleted = false,
  });

  ParentTrackingActive copyWith({
    List<Map<String, dynamic>>? trips,
    int? selectedTripIndex,
    List<Map<String, dynamic>>? pendingStops,
    Map<int, Map<String, dynamic>>? liveBusPositions,
    Map<int, List<LatLng>>? traveledPaths,
    Map<int, List<LatLng>>? plannedRoadPaths,
    String? activeAlert,
    String? alertType,
    bool? isApproaching,
    int? distanceMeters,
    int? etaMinutes,
    bool? isBoarded,
    bool? isTripCompleted,
  }) {
    return ParentTrackingActive(
      trips: trips ?? this.trips,
      selectedTripIndex: selectedTripIndex ?? this.selectedTripIndex,
      pendingStops: pendingStops ?? this.pendingStops,
      liveBusPositions: liveBusPositions ?? this.liveBusPositions,
      traveledPaths: traveledPaths ?? this.traveledPaths,
      plannedRoadPaths: plannedRoadPaths ?? this.plannedRoadPaths,
      activeAlert: activeAlert ?? this.activeAlert,
      alertType: alertType ?? this.alertType,
      isApproaching: isApproaching ?? this.isApproaching,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      isBoarded: isBoarded ?? this.isBoarded,
      isTripCompleted: isTripCompleted ?? this.isTripCompleted,
    );
  }

  @override
  List<Object?> get props => [
    trips,
    selectedTripIndex,
    pendingStops,
    liveBusPositions,
    traveledPaths,
    plannedRoadPaths,
    activeAlert,
    alertType,
    isApproaching,
    distanceMeters,
    etaMinutes,
    isBoarded,
    isTripCompleted,
  ];
}

class ParentTrackingSessionCleared extends ParentTrackingEvent {}

class ParentTrackingRestricted extends ParentTrackingState {
  final String message;
  const ParentTrackingRestricted(this.message);
  @override
  List<Object?> get props => [message];
}

// BLOC
class ParentTrackingBloc
    extends Bloc<ParentTrackingEvent, ParentTrackingState> {
  final ApiClient apiClient;
  StreamSubscription<int>? _sessionSubscription;
  StreamSubscription<String>? _deniedSubscription;
  final CentrifugoService centrifugoService;
  final NotificationService notificationService;

  ParentTrackingBloc({
    required this.apiClient,
    required this.centrifugoService,
    NotificationService? notificationService,
  }) : notificationService = notificationService ?? NotificationService(),
       super(ParentTrackingInitial()) {
    _deniedSubscription = centrifugoService.deniedChannels.listen((_) {
      if (!isClosed) add(LoadParentTrips());
    });
    _sessionSubscription = apiClient.sessionEnded.listen((_) {
      if (!isClosed) add(ParentTrackingSessionCleared());
    });
    on<ParentTrackingSessionCleared>((event, emit) {
      emit(ParentTrackingInitial());
    });
    on<LoadParentTrips>(_onLoadParentTrips);
    on<SelectTripRequested>(_onSelectTripRequested);
    on<BusLocationReceived>(_onBusLocationReceived);
    on<StopAlertReceived>(_onStopAlertReceived);
    on<TransitNotificationReceived>(_onTransitNotificationReceived);
    on<AcknowledgeStopRequested>(_onAcknowledgeStopRequested);
    on<ReportAbsenceRequested>(_onReportAbsenceRequested);
  }

  void _onSelectTripRequested(
    SelectTripRequested event,
    Emitter<ParentTrackingState> emit,
  ) {
    if (state is ParentTrackingActive) {
      final current = state as ParentTrackingActive;
      if (event.tripIndex >= 0 && event.tripIndex < current.trips.length) {
        emit(current.copyWith(selectedTripIndex: event.tripIndex));
      }
    }
  }

  Future<void> _onLoadParentTrips(
    LoadParentTrips event,
    Emitter<ParentTrackingState> emit,
  ) async {
    final session = apiClient.sessionGeneration;
    emit(ParentTrackingLoading());
    try {
      final response = await apiClient.dio.get('/parent/trips/active');
      if (session != apiClient.sessionGeneration || isClosed) return;
      final serviceNotice = response.data['service_notice'] as String?;
      final rawTrips = (response.data['trips'] as List<dynamic>?) ?? [];
      await centrifugoService.retainTripChannels(
        rawTrips
            .map((trip) => trip['channel'] as String?)
            .whereType<String>()
            .toSet(),
      );
      if (session != apiClient.sessionGeneration || isClosed) return;
      final rawPendingStops =
          (response.data['pending_stops'] as List<dynamic>?) ?? [];
      final rawRegisteredChildren =
          (response.data['registered_children'] as List<dynamic>?) ?? [];
      final pendingStops = rawPendingStops
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final registeredChildren = rawRegisteredChildren
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (rawTrips.isEmpty &&
          pendingStops.isEmpty &&
          registeredChildren.isEmpty &&
          serviceNotice != null) {
        emit(ParentTrackingRestricted(serviceNotice));
        return;
      }
      if (rawTrips.isEmpty &&
          pendingStops.isEmpty &&
          registeredChildren.isEmpty) {
        final requestsResponse = await apiClient.dio.get('/parent/requests');
        if (session != apiClient.sessionGeneration || isClosed) return;
        final requests = requestsResponse.data['requests'] as List? ?? [];
        if (requests.any((request) => request['status'] == 'pending')) {
          emit(
            const ParentTrackingRestricted(
              'Demande en attente de validation. Contactez l’école pour la vérification de votre identité.',
            ),
          );
          return;
        }
      }

      if (rawTrips.isEmpty && pendingStops.isNotEmpty) {
        emit(ParentTrackingPendingApproval(pendingStops));
        return;
      }

      if (rawTrips.isEmpty && registeredChildren.isNotEmpty) {
        emit(ParentTrackingStandby(registeredChildren));
        return;
      }

      if (rawTrips.isEmpty) {
        emit(ParentTrackingEmpty());
        return;
      }

      final trips = rawTrips
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final Map<int, Map<String, dynamic>> busPositions = {};
      final Map<int, List<LatLng>> traveledPaths = {};
      final Map<int, List<LatLng>> plannedRoadPaths = {};

      bool isApproaching = false;
      bool isBoarded = false;

      for (final trip in trips) {
        final tripId = trip['id'] as int;
        final channel = trip['channel'] as String?;
        final subToken = trip['centrifugo_subscription_token'] as String?;

        if (trip['last_location'] != null) {
          busPositions[tripId] = Map<String, dynamic>.from(
            trip['last_location'] as Map,
          );
        }

        final rawPath = trip['traveled_path'] as List<dynamic>? ?? [];
        traveledPaths[tripId] = rawPath.map((p) {
          final pt = p as Map<String, dynamic>;
          return LatLng(
            (pt['latitude'] as num).toDouble(),
            (pt['longitude'] as num).toDouble(),
          );
        }).toList();

        if (traveledPaths[tripId]!.isEmpty && busPositions[tripId] != null) {
          traveledPaths[tripId]!.add(
            LatLng(
              (busPositions[tripId]!['latitude'] as num).toDouble(),
              (busPositions[tripId]!['longitude'] as num).toDouble(),
            ),
          );
        }

        final rawRoadPath = trip['planned_road_path'] as List<dynamic>? ?? [];
        plannedRoadPaths[tripId] = rawRoadPath.map((p) {
          if (p is List && p.length >= 2) {
            return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
          }
          final pt = p as Map<String, dynamic>;
          return LatLng(
            (pt['latitude'] as num).toDouble(),
            (pt['longitude'] as num).toDouble(),
          );
        }).toList();

        final stops = (trip['stops'] as List<dynamic>? ?? []);
        for (final s in stops) {
          final stopMap = Map<String, dynamic>.from(s as Map);
          if (stopMap['alert_outer_sent_at'] != null &&
              stopMap['completion_status'] == 'pending') {
            isApproaching = true;
          }
          if (stopMap['completion_status'] == 'boarded') {
            isBoarded = true;
          }
        }

        if (channel != null) {
          unawaited(
            centrifugoService
                .subscribeToChannel(
                  channel: channel,
                  token: subToken,
                  onData: (data) {
                    final eventName = data['event'] as String?;

                    if (eventName == 'location_update') {
                      final payload = data['payload'] as Map<String, dynamic>;
                      add(
                        BusLocationReceived(
                          tripId: tripId,
                          latitude: (payload['latitude'] as num).toDouble(),
                          longitude: (payload['longitude'] as num).toDouble(),
                          speed: (payload['speed'] as num?)?.toDouble() ?? 0.0,
                          heading:
                              (payload['heading'] as num?)?.toDouble() ?? 0.0,
                        ),
                      );
                    } else if (eventName == 'approaching_stop') {
                      add(
                        TransitNotificationReceived(
                          type: 'approaching_stop',
                          title:
                              data['title'] as String? ??
                              '📍 Le bus approche !',
                          message:
                              data['message'] as String? ??
                              'Le bus arrive dans quelques minutes.',
                          tripId: tripId,
                          tripStopId: data['trip_stop_id'] as int?,
                          distanceMeters: data['distance_meters'] as int?,
                          etaMinutes: data['eta_minutes'] as int?,
                        ),
                      );
                    } else if (eventName == 'bus_arrived') {
                      add(
                        TransitNotificationReceived(
                          type: 'bus_arrived',
                          title:
                              data['title'] as String? ??
                              '🔔 Le bus est arrivé !',
                          message:
                              data['message'] as String? ??
                              'Le chauffeur est devant votre arrêt.',
                          tripId: tripId,
                          tripStopId: data['trip_stop_id'] as int?,
                        ),
                      );
                    } else if (eventName == 'child_boarded') {
                      add(
                        TransitNotificationReceived(
                          type: 'child_boarded',
                          title:
                              data['title'] as String? ??
                              '✅ Montée à bord validée',
                          message:
                              data['message'] as String? ??
                              'Votre enfant est dans le bus.',
                          tripId: tripId,
                          tripStopId: data['trip_stop_id'] as int?,
                        ),
                      );
                    } else if (eventName == 'trip_completed') {
                      add(
                        TransitNotificationReceived(
                          type: 'trip_completed',
                          title:
                              data['title'] as String? ??
                              '🏫 Arrivée à l\'école confirmée',
                          message:
                              data['message'] as String? ??
                              'Tous les élèves sont arrivés à l\'école.',
                          tripId: tripId,
                        ),
                      );
                    } else if (eventName == 'trip_started') {
                      add(
                        TransitNotificationReceived(
                          type: 'trip_started',
                          title:
                              data['title'] as String? ?? '🚌 Tournée démarrée',
                          message:
                              data['message'] as String? ??
                              'La tournée matinale a débuté.',
                          tripId: tripId,
                        ),
                      );
                    } else if (eventName == 'stop_status_changed') {
                      final stopId = data['stop_id'] as int;
                      final status = data['status'] as String;
                      add(
                        StopAlertReceived(
                          tripId: tripId,
                          stopId: stopId,
                          status: status,
                        ),
                      );
                    }
                  },
                )
                .catchError((_) {}),
          );
        }
      }

      emit(
        ParentTrackingActive(
          trips: trips,
          pendingStops: pendingStops,
          liveBusPositions: busPositions,
          traveledPaths: traveledPaths,
          plannedRoadPaths: plannedRoadPaths,
          isApproaching: isApproaching,
          isBoarded: isBoarded,
        ),
      );
    } catch (e) {
      if (session != apiClient.sessionGeneration || isClosed) return;
      emit(ParentTrackingRestricted(ApiException.fromError(e).message));
    }
  }

  void _onBusLocationReceived(
    BusLocationReceived event,
    Emitter<ParentTrackingState> emit,
  ) {
    if (state is! ParentTrackingActive) return;
    final current = state as ParentTrackingActive;
    final updatedPositions = Map<int, Map<String, dynamic>>.from(
      current.liveBusPositions,
    );

    updatedPositions[event.tripId] = {
      'latitude': event.latitude,
      'longitude': event.longitude,
      'speed': event.speed,
      'heading': event.heading,
    };

    final updatedPaths = Map<int, List<LatLng>>.from(
      current.traveledPaths.map((k, v) => MapEntry(k, List<LatLng>.from(v))),
    );
    final currentPath = updatedPaths[event.tripId] ?? [];
    currentPath.add(LatLng(event.latitude, event.longitude));
    updatedPaths[event.tripId] = currentPath;

    final updatedPlanned = Map<int, List<LatLng>>.from(
      current.plannedRoadPaths.map((k, v) => MapEntry(k, List<LatLng>.from(v))),
    );
    if (updatedPlanned[event.tripId] != null &&
        updatedPlanned[event.tripId]!.isNotEmpty) {
      final roadList = List<LatLng>.from(updatedPlanned[event.tripId]!);
      roadList[0] = LatLng(event.latitude, event.longitude);
      updatedPlanned[event.tripId] = roadList;
    }

    emit(
      current.copyWith(
        liveBusPositions: updatedPositions,
        traveledPaths: updatedPaths,
        plannedRoadPaths: updatedPlanned,
      ),
    );
  }

  void _onStopAlertReceived(
    StopAlertReceived event,
    Emitter<ParentTrackingState> emit,
  ) {
    if (state is! ParentTrackingActive) return;
    final current = state as ParentTrackingActive;
    emit(current.copyWith(activeAlert: 'Statut mis à jour: ${event.status}'));
  }

  Future<void> _onTransitNotificationReceived(
    TransitNotificationReceived event,
    Emitter<ParentTrackingState> emit,
  ) async {
    if (state is! ParentTrackingActive) return;
    // Show high-priority local Heads-Up notification
    await notificationService.showTransitAlert(
      id: event.type.hashCode,
      title: event.title,
      body: event.message,
      payload: {
        'type': event.type,
        'trip_id': event.tripId,
        'trip_stop_id': event.tripStopId,
      },
    );

    if (state is! ParentTrackingActive) return;
    final current = state as ParentTrackingActive;

    if (event.type == 'approaching_stop') {
      emit(
        current.copyWith(
          activeAlert: event.message,
          alertType: event.type,
          isApproaching: true,
          distanceMeters: event.distanceMeters ?? 800,
          etaMinutes: event.etaMinutes ?? 3,
        ),
      );
    } else if (event.type == 'child_boarded') {
      emit(
        current.copyWith(
          activeAlert: event.message,
          alertType: event.type,
          isBoarded: true,
          isApproaching: false,
        ),
      );
    } else if (event.type == 'trip_completed') {
      emit(
        current.copyWith(
          activeAlert: event.message,
          alertType: event.type,
          isTripCompleted: true,
        ),
      );
    } else {
      emit(current.copyWith(activeAlert: event.message, alertType: event.type));
    }
  }

  Future<void> _onAcknowledgeStopRequested(
    AcknowledgeStopRequested event,
    Emitter<ParentTrackingState> emit,
  ) async {
    final session = apiClient.sessionGeneration;
    try {
      await apiClient.dio.post(
        '/parent/stops/${event.tripStopId}/acknowledge',
        data: {'status': event.status},
      );

      if (session != apiClient.sessionGeneration || isClosed) return;
      if (state is ParentTrackingActive) {
        final current = state as ParentTrackingActive;
        final updatedTrips = current.trips.map((t) {
          final tripMap = Map<String, dynamic>.from(t);
          final stops = (tripMap['stops'] as List<dynamic>? ?? []).map((s) {
            final stopMap = Map<String, dynamic>.from(s as Map);
            if (stopMap['trip_stop_id'] == event.tripStopId) {
              stopMap['acknowledgement_status'] = event.status;
            }
            return stopMap;
          }).toList();
          tripMap['stops'] = stops;
          return tripMap;
        }).toList();

        emit(
          current.copyWith(
            trips: updatedTrips,
            activeAlert: event.status == 'acknowledged_ready'
                ? 'Le chauffeur a été prévenu : Vous êtes prêt !'
                : 'Le chauffeur a été prévenu : +2 min de retard.',
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _onReportAbsenceRequested(
    ReportAbsenceRequested event,
    Emitter<ParentTrackingState> emit,
  ) async {
    final session = apiClient.sessionGeneration;
    try {
      await apiClient.dio.post(
        '/parent/stops/${event.tripStopId}/report-absence',
        data: {'reason': event.reason ?? 'Absence signalée par le parent'},
      );

      if (session != apiClient.sessionGeneration || isClosed) return;
      if (state is ParentTrackingActive) {
        final current = state as ParentTrackingActive;
        final updatedTrips = current.trips.map((t) {
          final tripMap = Map<String, dynamic>.from(t);
          final stops = (tripMap['stops'] as List<dynamic>? ?? []).map((s) {
            final stopMap = Map<String, dynamic>.from(s as Map);
            if (stopMap['trip_stop_id'] == event.tripStopId) {
              stopMap['completion_status'] = 'absent';
            }
            return stopMap;
          }).toList();
          tripMap['stops'] = stops;
          return tripMap;
        }).toList();

        emit(
          current.copyWith(
            trips: updatedTrips,
            isApproaching: false,
            activeAlert:
                'Absence signalée. Le chauffeur a été prévenu et passera l\'arrêt.',
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    await _deniedSubscription?.cancel();
    return super.close();
  }
}
