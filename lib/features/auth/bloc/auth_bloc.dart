import 'package:centrifuge/centrifuge.dart' show UnauthorizedException;
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/network/centrifugo_service.dart';
import '../../../core/services/notification_service.dart';
import '../data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  int _operation = 0;
  StreamSubscription<int>? _sessionSubscription;
  final CentrifugoService? centrifugoService;

  AuthBloc({required this.authRepository, this.centrifugoService})
    : super(AuthInitial()) {
    _sessionSubscription = authRepository.apiClient.sessionEnded.listen((
      generation,
    ) {
      if (!isClosed) add(SessionExpired(generation));
    });
    centrifugoService?.tokenProvider = (channel) async {
      try {
        final response = await authRepository.apiClient.dio.post(
          '/realtime/token',
          data: {'channel': ?channel},
        );
        return response.data['token'] as String;
      } on DioException catch (error) {
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          throw UnauthorizedException();
        }
        rethrow;
      }
    };
    on<SessionExpired>((event, emit) {
      if (event.generation == authRepository.apiClient.sessionGeneration) {
        centrifugoService?.disconnect();
        unawaited(NotificationService().clearSessionAlerts());
        emit(Unauthenticated());
      }
    });
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<ParentRegisterSubmitted>(_onParentRegisterSubmitted);
    on<ModeSwitchRequested>(_onModeSwitchRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final operation = ++_operation;
    final generation = authRepository.apiClient.sessionGeneration;
    Map<String, dynamic>? user;
    try {
      if (await authRepository.getAuthToken() != null) {
        user = await authRepository.refreshSession();
      }
    } catch (_) {
      if (operation != _operation) return;
      emit(Unauthenticated());
      return;
    }
    if (user != null) {
      final activeMode =
          await authRepository.getActiveMode() ?? user['role'] ?? 'parent';
      String? token;
      if (user['must_change_password'] != true) {
        try {
          token = await centrifugoService?.tokenProvider?.call(null);
        } catch (_) {}
      }
      if (generation != authRepository.apiClient.sessionGeneration) return;
      final wsUrl =
          await authRepository.getCentrifugoWsUrl() ??
          AppConstants.defaultCentrifugoWsUrl;
      if (token != null && centrifugoService != null) {
        try {
          await centrifugoService!.connect(wsUrl: wsUrl, token: token);
          await centrifugoService!.subscribePersonalChannel(
            user['id'] as int,
            activeMode,
          );
        } catch (_) {}
      }
      if (generation != authRepository.apiClient.sessionGeneration) return;
      if (operation != _operation) return;
      emit(Authenticated(user: user, activeMode: activeMode));
    } else {
      if (operation != _operation) return;
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final operation = ++_operation;
    if (operation != _operation) return;
    emit(AuthLoading());
    try {
      final data = await authRepository.login(
        login: event.login,
        password: event.password,
      );
      final session = authRepository.apiClient.sessionGeneration;
      final user = data['user'] as Map<String, dynamic>;
      final activeMode = user['active_mode'] ?? user['role'] ?? 'parent';
      final centrifugo = data['centrifugo'] as Map<String, dynamic>?;
      if (user['must_change_password'] != true &&
          centrifugo != null &&
          centrifugoService != null) {
        try {
          await centrifugoService!.connect(
            wsUrl: centrifugo['ws_url'] ?? AppConstants.defaultCentrifugoWsUrl,
            token: centrifugo['token'] ?? '',
          );
          await centrifugoService!.subscribePersonalChannel(
            user['id'] as int,
            activeMode,
          );
        } catch (_) {}
      }
      if (session != authRepository.apiClient.sessionGeneration) return;
      if (operation != _operation) return;
      emit(Authenticated(user: user, activeMode: activeMode));
    } on ApiException catch (e) {
      if (operation != _operation) return;
      emit(AuthFailure(e.message));
    } catch (e) {
      if (operation != _operation) return;
      emit(AuthFailure(ApiException.fromError(e).message));
    }
  }

  Future<void> _onParentRegisterSubmitted(
    ParentRegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final operation = ++_operation;
    if (operation != _operation) return;
    emit(AuthLoading());
    try {
      final data = await authRepository.registerParent(
        name: event.name,
        phone: event.phone,
        password: event.password,
        email: event.email,
      );
      final session = authRepository.apiClient.sessionGeneration;
      final user = data['user'] as Map<String, dynamic>;
      final activeMode = user['active_mode'] ?? 'parent';
      final centrifugo = data['centrifugo'] as Map<String, dynamic>?;
      if (user['must_change_password'] != true &&
          centrifugo != null &&
          centrifugoService != null) {
        try {
          await centrifugoService!.connect(
            wsUrl: centrifugo['ws_url'] ?? AppConstants.defaultCentrifugoWsUrl,
            token: centrifugo['token'] ?? '',
          );
          await centrifugoService!.subscribePersonalChannel(
            user['id'] as int,
            activeMode,
          );
        } catch (_) {}
      }
      if (session != authRepository.apiClient.sessionGeneration) return;
      if (operation != _operation) return;
      emit(Authenticated(user: user, activeMode: activeMode));
    } on ApiException catch (e) {
      if (operation != _operation) return;
      emit(AuthFailure(e.message));
    } catch (e) {
      if (operation != _operation) return;
      emit(AuthFailure(ApiException.fromError(e).message));
    }
  }

  Future<void> _onModeSwitchRequested(
    ModeSwitchRequested event,
    Emitter<AuthState> emit,
  ) async {
    final operation = ++_operation;
    if (state is Authenticated) {
      final current = state as Authenticated;
      final session = authRepository.apiClient.sessionGeneration;
      try {
        await authRepository.setActiveMode(event.targetMode);
        if (session != authRepository.apiClient.sessionGeneration) return;
        if (operation != _operation) return;
        emit(Authenticated(user: current.user, activeMode: event.targetMode));
      } catch (_) {
        if (session != authRepository.apiClient.sessionGeneration) return;
        if (operation != _operation) return;
        emit(Authenticated(user: current.user, activeMode: current.activeMode));
      }
    }
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final operation = ++_operation;
    centrifugoService?.disconnect();
    await authRepository.logout();
    if (operation != _operation) return;
    emit(Unauthenticated());
  }
}
