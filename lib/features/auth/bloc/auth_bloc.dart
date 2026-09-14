import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/network/centrifugo_service.dart';
import '../data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final CentrifugoService? centrifugoService;

  AuthBloc({
    required this.authRepository,
    this.centrifugoService,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<ParentRegisterSubmitted>(_onParentRegisterSubmitted);
    on<ModeSwitchRequested>(_onModeSwitchRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final user = await authRepository.getCurrentUser();
    if (user != null) {
      final activeMode = await authRepository.getActiveMode() ?? user['role'] ?? 'parent';
      final token = await authRepository.getCentrifugoToken();
      final wsUrl = await authRepository.getCentrifugoWsUrl() ?? AppConstants.defaultCentrifugoWsUrl;
      if (token != null && centrifugoService != null) {
        try {
          await centrifugoService!.connect(wsUrl: wsUrl, token: token);
        } catch (_) {}
      }
      emit(Authenticated(user: user, activeMode: activeMode));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginSubmitted(LoginSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final data = await authRepository.login(
        login: event.login,
        password: event.password,
      );
      final user = data['user'] as Map<String, dynamic>;
      final activeMode = user['active_mode'] ?? user['role'] ?? 'parent';
      final centrifugo = data['centrifugo'] as Map<String, dynamic>?;
      if (centrifugo != null && centrifugoService != null) {
        try {
          await centrifugoService!.connect(
            wsUrl: centrifugo['ws_url'] ?? AppConstants.defaultCentrifugoWsUrl,
            token: centrifugo['token'] ?? '',
          );
        } catch (_) {}
      }
      emit(Authenticated(user: user, activeMode: activeMode));
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    } catch (e) {
      emit(AuthFailure(ApiException.fromError(e).message));
    }
  }

  Future<void> _onParentRegisterSubmitted(ParentRegisterSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final data = await authRepository.registerParent(
        name: event.name,
        phone: event.phone,
        password: event.password,
        email: event.email,
      );
      final user = data['user'] as Map<String, dynamic>;
      final activeMode = user['active_mode'] ?? 'parent';
      final centrifugo = data['centrifugo'] as Map<String, dynamic>?;
      if (centrifugo != null && centrifugoService != null) {
        try {
          await centrifugoService!.connect(
            wsUrl: centrifugo['ws_url'] ?? AppConstants.defaultCentrifugoWsUrl,
            token: centrifugo['token'] ?? '',
          );
        } catch (_) {}
      }
      emit(Authenticated(user: user, activeMode: activeMode));
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    } catch (e) {
      emit(AuthFailure(ApiException.fromError(e).message));
    }
  }

  Future<void> _onModeSwitchRequested(ModeSwitchRequested event, Emitter<AuthState> emit) async {
    if (state is Authenticated) {
      final current = state as Authenticated;
      await authRepository.setActiveMode(event.targetMode);
      emit(Authenticated(user: current.user, activeMode: event.targetMode));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    centrifugoService?.disconnect();
    await authRepository.logout();
    emit(Unauthenticated());
  }
}
