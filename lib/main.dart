import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/api/api_client.dart';
import 'core/network/centrifugo_service.dart';
import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_splash_screen.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/change_temporary_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/driver/bloc/driver_cockpit_bloc.dart';
import 'features/driver/presentation/driver_cockpit_screen.dart';
import 'features/parent/bloc/parent_tracking_bloc.dart';
import 'features/parent/presentation/parent_tracking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final apiClient = ApiClient();
  final centrifugoService = CentrifugoService();
  final locationService = LocationService();
  final authRepository = AuthRepository(apiClient: apiClient);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('fr'),
      child: RidinApp(
        apiClient: apiClient,
        centrifugoService: centrifugoService,
        locationService: locationService,
        authRepository: authRepository,
      ),
    ),
  );
}

class RidinApp extends StatelessWidget {
  final ApiClient apiClient;
  final CentrifugoService centrifugoService;
  final LocationService locationService;
  final AuthRepository authRepository;

  const RidinApp({
    super.key,
    required this.apiClient,
    required this.centrifugoService,
    required this.locationService,
    required this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: apiClient),
        RepositoryProvider.value(value: centrifugoService),
        RepositoryProvider.value(value: locationService),
        RepositoryProvider.value(value: authRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(
              authRepository: authRepository,
              centrifugoService: centrifugoService,
            )..add(AuthCheckRequested()),
          ),
          BlocProvider<DriverCockpitBloc>(
            create: (_) => DriverCockpitBloc(
              apiClient: apiClient,
              centrifugoService: centrifugoService,
              locationService: locationService,
            ),
          ),
          BlocProvider<ParentTrackingBloc>(
            create: (_) => ParentTrackingBloc(
              apiClient: apiClient,
              centrifugoService: centrifugoService,
            ),
          ),
        ],
        child: Builder(
          builder: (ctx) {
            return MaterialApp(
              title: 'app_name'.tr(),
              debugShowCheckedModeBanner: false,
              localizationsDelegates: ctx.localizationDelegates,
              supportedLocales: ctx.supportedLocales,
              locale: ctx.locale,
              theme: AppTheme.lightTheme(ctx.locale.languageCode),
              darkTheme: AppTheme.darkTheme(ctx.locale.languageCode),
              home: AppRootView(apiClient: apiClient),
            );
          },
        ),
      ),
    );
  }
}

class AppRootView extends StatefulWidget {
  final ApiClient apiClient;
  const AppRootView({super.key, required this.apiClient});

  @override
  State<AppRootView> createState() => _AppRootViewState();
}

class _AppRootViewState extends State<AppRootView> {
  DateTime? _lastBackPressTime;
  bool _tokenSynced = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated && !_tokenSynced) {
          _tokenSynced = true;
          NotificationService().syncDeviceToken(widget.apiClient);
        } else if (state is Unauthenticated) {
          _tokenSynced = false;
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const AppSplashScreen();
        }

        if (state is Authenticated) {
          if (!_tokenSynced) {
            _tokenSynced = true;
            NotificationService().syncDeviceToken(widget.apiClient);
          }
          final role = state.activeMode;
          final mustChangePassword = state.user['must_change_password'] == true;

          if (mustChangePassword) {
            return const ChangeTemporaryPasswordScreen();
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;

              final now = DateTime.now();
              if (_lastBackPressTime == null ||
                  now.difference(_lastBackPressTime!) >
                      const Duration(seconds: 2)) {
                _lastBackPressTime = now;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('common.press_back_again_to_exit'.tr()),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                SystemNavigator.pop();
              }
            },
            child: role == 'driver'
                ? const DriverCockpitScreen()
                : const ParentTrackingScreen(),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
