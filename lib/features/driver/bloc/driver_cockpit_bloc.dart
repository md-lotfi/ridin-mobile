import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/network/centrifugo_service.dart';
import '../../../core/services/location_service.dart';

// EVENTS
abstract class DriverCockpitEvent extends Equatable {
  const DriverCockpitEvent();
  @override
  List<Object?> get props => [];
}

class LoadCurrentTrip extends DriverCockpitEvent {}

class StartTripRequested extends DriverCockpitEvent {
  final int tripId;
  const StartTripRequested(this.tripId);
  @override
  List<Object?> get props => [tripId];
}

class LocationUpdated extends DriverCockpitEvent {
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  const LocationUpdated({required this.latitude, required this.longitude, required this.speed, required this.heading});
  @override
  List<Object?> get props => [latitude, longitude, speed, heading];
}

class CompleteStopRequested extends DriverCockpitEvent {
  final int tripId;
  final int tripStopId;
  final String status; // 'boarded', 'absent', 'skipped'
  const CompleteStopRequested({required this.tripId, required this.tripStopId, required this.status});
  @override
  List<Object?> get props => [tripId, tripStopId, status];
}

class CallAttemptRequested extends DriverCockpitEvent {
  final int tripId;
  final int tripStopId;
  const CallAttemptRequested({required this.tripId, required this.tripStopId});
  @override
  List<Object?> get props => [tripId, tripStopId];
}

class SafetyCheckCompleted extends DriverCockpitEvent {
  final int tripId;
  final String method;
  final String? code;
  final List<File>? photos;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;

  const SafetyCheckCompleted({
    required this.tripId,
    required this.method,
    this.code,
    this.photos,
    this.latitude,
    this.longitude,
    this.locationLabel,
  });

  @override
  List<Object?> get props => [tripId, method, code, photos, latitude, longitude, locationLabel];
}

class EndTripRequested extends DriverCockpitEvent {
  final int tripId;
  const EndTripRequested(this.tripId);
  @override
  List<Object?> get props => [tripId];
}

class BroadcastDelayRequested extends DriverCockpitEvent {
  final int tripId;
  final int minutes;
  final String reason;
  const BroadcastDelayRequested({required this.tripId, required this.minutes, required this.reason});
  @override
  List<Object?> get props => [tripId, minutes, reason];
}

class RerouteRequested extends DriverCockpitEvent {
  final int tripId;
  final double latitude;
  final double longitude;
  const RerouteRequested({required this.tripId, required this.latitude, required this.longitude});
  @override
  List<Object?> get props => [tripId, latitude, longitude];
}

// STATES
abstract class DriverCockpitState extends Equatable {
  const DriverCockpitState();
  @override
  List<Object?> get props => [];
}

class DriverCockpitInitial extends DriverCockpitState {}
class DriverCockpitLoading extends DriverCockpitState {}
class DriverCockpitNoTrip extends DriverCockpitState {}

class DriverCockpitActive extends DriverCockpitState {
  final Map<String, dynamic> trip;
  final double currentLatitude;
  final double currentLongitude;
  final double currentSpeed;
  final double currentHeading;
  final bool isSpeeding;
  final bool isSafetyCheckVerified;
  final int driverSafetyScore;
  final String driverSafetyTier;
  final int organizationSpeedLimit;
  final List<LatLng> traveledPath;
  final List<LatLng> plannedRoadPath;
  final String? errorMessage;

  const DriverCockpitActive({
    required this.trip,
    this.currentLatitude = 36.7538,
    this.currentLongitude = 3.0588,
    this.currentSpeed = 0.0,
    this.currentHeading = 0.0,
    this.isSpeeding = false,
    this.isSafetyCheckVerified = false,
    this.driverSafetyScore = 100,
    this.driverSafetyTier = 'Exemplaire',
    this.organizationSpeedLimit = 60,
    this.traveledPath = const [],
    this.plannedRoadPath = const [],
    this.errorMessage,
  });

  DriverCockpitActive copyWith({
    Map<String, dynamic>? trip,
    double? currentLatitude,
    double? currentLongitude,
    double? currentSpeed,
    double? currentHeading,
    bool? isSpeeding,
    bool? isSafetyCheckVerified,
    int? driverSafetyScore,
    String? driverSafetyTier,
    int? organizationSpeedLimit,
    List<LatLng>? traveledPath,
    List<LatLng>? plannedRoadPath,
    String? errorMessage,
  }) {
    return DriverCockpitActive(
      trip: trip ?? this.trip,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentHeading: currentHeading ?? this.currentHeading,
      isSpeeding: isSpeeding ?? this.isSpeeding,
      isSafetyCheckVerified: isSafetyCheckVerified ?? this.isSafetyCheckVerified,
      driverSafetyScore: driverSafetyScore ?? this.driverSafetyScore,
      driverSafetyTier: driverSafetyTier ?? this.driverSafetyTier,
      organizationSpeedLimit: organizationSpeedLimit ?? this.organizationSpeedLimit,
      traveledPath: traveledPath ?? this.traveledPath,
      plannedRoadPath: plannedRoadPath ?? this.plannedRoadPath,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    trip,
    currentLatitude,
    currentLongitude,
    currentSpeed,
    currentHeading,
    isSpeeding,
    isSafetyCheckVerified,
    driverSafetyScore,
    driverSafetyTier,
    organizationSpeedLimit,
    traveledPath,
    plannedRoadPath,
    errorMessage,
  ];
}

// BLOC
class DriverCockpitBloc extends Bloc<DriverCockpitEvent, DriverCockpitState> {
  final ApiClient apiClient;
  final CentrifugoService centrifugoService;
  final LocationService locationService;

  StreamSubscription? _locationSubscription;

  DriverCockpitBloc({
    required this.apiClient,
    required this.centrifugoService,
    required this.locationService,
  }) : super(DriverCockpitInitial()) {
    on<LoadCurrentTrip>(_onLoadCurrentTrip);
    on<StartTripRequested>(_onStartTripRequested);
    on<LocationUpdated>(_onLocationUpdated);
    on<CompleteStopRequested>(_onCompleteStopRequested);
    on<CallAttemptRequested>(_onCallAttemptRequested);
    on<SafetyCheckCompleted>(_onSafetyCheckCompleted);
    on<EndTripRequested>(_onEndTripRequested);
    on<BroadcastDelayRequested>(_onBroadcastDelayRequested);
    on<RerouteRequested>(_onRerouteRequested);
  }

  Future<void> _onLoadCurrentTrip(LoadCurrentTrip event, Emitter<DriverCockpitState> emit) async {
    emit(DriverCockpitLoading());
    try {
      final response = await apiClient.dio.get('/driver/trips/current');
      final trip = response.data['trip'] as Map<String, dynamic>?;

      if (trip == null) {
        emit(DriverCockpitNoTrip());
        return;
      }

      final subscriptionToken = response.data['centrifugo_subscription_token'] as String?;
      final channel = response.data['channel'] as String?;

      if (channel != null) {
        unawaited(centrifugoService.subscribeToChannel(
          channel: channel,
          token: subscriptionToken,
          onData: (data) {
            // Parent acknowledgement or delay response handling
          },
        ).catchError((_) {}));
      }

      final rawPath = (response.data['traveled_path'] as List<dynamic>?) ?? [];
      final List<LatLng> initialPath = rawPath.map((p) {
        final pt = p as Map<String, dynamic>;
        return LatLng(
          (pt['latitude'] as num).toDouble(),
          (pt['longitude'] as num).toDouble(),
        );
      }).toList();

      if (initialPath.isEmpty && trip['locations'] is List) {
        for (final loc in (trip['locations'] as List)) {
          if (loc['latitude'] != null && loc['longitude'] != null) {
            initialPath.add(LatLng(
              (loc['latitude'] as num).toDouble(),
              (loc['longitude'] as num).toDouble(),
            ));
          }
        }
      }

      final rawRoadPath = (response.data['planned_road_path'] as List<dynamic>?) ?? [];
      final List<LatLng> initialRoadPath = rawRoadPath.map((p) {
        if (p is List && p.length >= 2) {
          return LatLng(
            (p[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          );
        }
        final pt = p as Map<String, dynamic>;
        return LatLng(
          (pt['latitude'] as num).toDouble(),
          (pt['longitude'] as num).toDouble(),
        );
      }).toList();

      // Resolve initial bus coordinates: from last GPS fix, or first circuit stop
      double initialLat = 36.7538;
      double initialLng = 3.0588;

      if (initialPath.isNotEmpty) {
        initialLat = initialPath.last.latitude;
        initialLng = initialPath.last.longitude;
      } else {
        final tripStops = trip['trip_stops'] as List<dynamic>? ?? [];
        for (final ts in tripStops) {
          final stop = ts['stop'] as Map<String, dynamic>?;
          if (stop != null && stop['latitude'] != null && stop['longitude'] != null) {
            initialLat = (stop['latitude'] as num).toDouble();
            initialLng = (stop['longitude'] as num).toDouble();
            break;
          }
        }
      }

      final isSafetyCheckDone = trip['child_check_verified_at'] != null;
      final score = response.data['driver_safety_score'] as int? ?? 100;
      final tier = response.data['driver_safety_tier'] as String? ?? 'Exemplaire';
      final speedLimit = response.data['organization_speed_limit'] as int? ?? 60;

      emit(DriverCockpitActive(
        trip: trip,
        currentLatitude: initialLat,
        currentLongitude: initialLng,
        isSafetyCheckVerified: isSafetyCheckDone,
        driverSafetyScore: score,
        driverSafetyTier: tier,
        organizationSpeedLimit: speedLimit,
        traveledPath: initialPath,
        plannedRoadPath: initialRoadPath,
      ));

      if (trip['status'] == 'in_progress') {
        _startLocationStreaming(trip['id'] as int);
      }
    } catch (e) {
      emit(DriverCockpitNoTrip());
    }
  }

  Future<void> _onStartTripRequested(StartTripRequested event, Emitter<DriverCockpitState> emit) async {
    try {
      final response = await apiClient.dio.post('/driver/trips/${event.tripId}/start');
      final trip = response.data['trip'] as Map<String, dynamic>;

      if (state is DriverCockpitActive) {
        emit((state as DriverCockpitActive).copyWith(trip: trip, errorMessage: null));
      } else {
        emit(DriverCockpitActive(trip: trip));
      }

      _startLocationStreaming(event.tripId);
    } catch (e) {
      if (e is DioException) {
        final msg = e.response?.data?['message'] as String? ?? 'Erreur lors du démarrage du trajet.';
        if (state is DriverCockpitActive) {
          emit((state as DriverCockpitActive).copyWith(errorMessage: msg));
        }
      }
    }
  }

  void _startLocationStreaming(int tripId) {
    _locationSubscription?.cancel();
    _locationSubscription = locationService.getPositionStream().listen((pos) {
      add(LocationUpdated(
        latitude: pos.latitude,
        longitude: pos.longitude,
        speed: (pos.speed * 3.6), // m/s to km/h
        heading: pos.heading,
      ));
    });
  }

  Future<void> _onLocationUpdated(LocationUpdated event, Emitter<DriverCockpitState> emit) async {
    if (state is! DriverCockpitActive) return;
    final current = state as DriverCockpitActive;
    final tripId = current.trip['id'] as int;
    final isSpeeding = event.speed > current.organizationSpeedLimit;

    final updatedPath = List<LatLng>.from(current.traveledPath)..add(LatLng(event.latitude, event.longitude));

    List<LatLng> updatedRoadPath = current.plannedRoadPath;
    if (current.plannedRoadPath.isNotEmpty) {
      updatedRoadPath = List<LatLng>.from(current.plannedRoadPath);
      updatedRoadPath[0] = LatLng(event.latitude, event.longitude);
    }

    emit(current.copyWith(
      currentLatitude: event.latitude,
      currentLongitude: event.longitude,
      currentSpeed: event.speed,
      currentHeading: event.heading,
      isSpeeding: isSpeeding,
      traveledPath: updatedPath,
      plannedRoadPath: updatedRoadPath,
    ));

    // Send to backend
    try {
      await apiClient.dio.post('/driver/trips/$tripId/locations', data: {
        'latitude': event.latitude,
        'longitude': event.longitude,
        'speed': event.speed,
        'heading': event.heading,
        'recorded_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      await locationService.saveBreadcrumbOffline(
        latitude: event.latitude,
        longitude: event.longitude,
        speed: event.speed,
        heading: event.heading,
        recordedAt: DateTime.now(),
      );
    }
  }

  Future<void> _onCompleteStopRequested(CompleteStopRequested event, Emitter<DriverCockpitState> emit) async {
    try {
      await apiClient.dio.post(
        '/driver/trips/${event.tripId}/stops/${event.tripStopId}/status',
        data: {'status': event.status},
      );
      add(LoadCurrentTrip());
    } catch (_) {}
  }

  Future<void> _onCallAttemptRequested(CallAttemptRequested event, Emitter<DriverCockpitState> emit) async {
    try {
      await apiClient.dio.post('/driver/trips/${event.tripId}/stops/${event.tripStopId}/call-attempt');
    } catch (_) {}
  }

  Future<void> _onSafetyCheckCompleted(SafetyCheckCompleted event, Emitter<DriverCockpitState> emit) async {
    try {
      if (event.photos != null && event.photos!.isNotEmpty) {
        final formData = FormData();
        formData.fields.add(MapEntry('latitude', (event.latitude ?? 36.7525).toString()));
        formData.fields.add(MapEntry('longitude', (event.longitude ?? 3.0380).toString()));
        formData.fields.add(const MapEntry('method', 'live_photo_watermark'));
        if (event.locationLabel != null) {
          formData.fields.add(MapEntry('location_label', event.locationLabel!));
        }

        for (var i = 0; i < event.photos!.length; i++) {
          final file = event.photos![i];
          formData.files.add(MapEntry(
            'photos[]',
            await MultipartFile.fromFile(file.path, filename: 'aisle_$i.jpg'),
          ));
        }

        await apiClient.dio.post('/driver/trips/${event.tripId}/safety-check', data: formData);
      } else {
        await apiClient.dio.post('/driver/trips/${event.tripId}/safety-check', data: {
          'method': event.method,
          'verification_code': event.code,
        });
      }

      if (state is DriverCockpitActive) {
        emit((state as DriverCockpitActive).copyWith(isSafetyCheckVerified: true));
      }
    } catch (e) {
      if (state is DriverCockpitActive) {
        emit((state as DriverCockpitActive).copyWith(
          errorMessage: ApiException.fromError(e).message,
        ));
      }
    }
  }

  Future<void> _onEndTripRequested(EndTripRequested event, Emitter<DriverCockpitState> emit) async {
    try {
      await apiClient.dio.post('/driver/trips/${event.tripId}/end');
      _locationSubscription?.cancel();
      emit(DriverCockpitNoTrip());
    } catch (e) {
      if (state is DriverCockpitActive) {
        emit((state as DriverCockpitActive).copyWith(
          errorMessage: 'Inspection de sécurité requise au fond du bus avant clôture.',
        ));
      }
    }
  }

  Future<void> _onBroadcastDelayRequested(BroadcastDelayRequested event, Emitter<DriverCockpitState> emit) async {
    try {
      await apiClient.dio.post('/driver/trips/${event.tripId}/broadcast-delay', data: {
        'delay_minutes': event.minutes,
        'reason': event.reason,
      });
    } catch (_) {}
  }

  Future<void> _onRerouteRequested(RerouteRequested event, Emitter<DriverCockpitState> emit) async {
    if (state is! DriverCockpitActive) return;
    final current = state as DriverCockpitActive;
    try {
      final response = await apiClient.dio.post(
        '/driver/trips/${event.tripId}/reroute',
        data: {
          'latitude': event.latitude,
          'longitude': event.longitude,
        },
      );
      final rawRoadPath = (response.data['planned_road_path'] as List<dynamic>?) ?? [];
      final List<LatLng> newRoadPath = rawRoadPath.map((p) {
        if (p is List && p.length >= 2) {
          return LatLng(
            (p[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          );
        }
        final pt = p as Map<String, dynamic>;
        return LatLng(
          (pt['latitude'] as num).toDouble(),
          (pt['longitude'] as num).toDouble(),
        );
      }).toList();

      emit(current.copyWith(plannedRoadPath: newRoadPath));
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
