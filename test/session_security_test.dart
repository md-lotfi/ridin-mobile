import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ridin/core/api/api_client.dart';
import 'package:ridin/core/constants/app_constants.dart';
import 'package:ridin/features/auth/data/auth_repository.dart';
import 'package:ridin/features/auth/bloc/auth_bloc.dart';
import 'package:ridin/features/auth/bloc/auth_event.dart';
import 'package:ridin/features/auth/bloc/auth_state.dart';

class _ControlledAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final pending = <Completer<ResponseBody>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    final response = Completer<ResponseBody>();
    pending.add(response);
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _until(bool Function() ready) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(ready(), isTrue);
}

ResponseBody _json(int status, String body) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient client;
  late _ControlledAdapter adapter;
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.keyAuthToken: 'account-a',
      AppConstants.keyUserData: '{"id":1}',
      AppConstants.keyCentrifugoToken: 'old-jwt',
    });
    SharedPreferences.setMockInitialValues({
      AppConstants.keyOfflineBreadcrumbs: ['private old position'],
    });
    client = ApiClient(baseUrl: 'https://api.example.invalid/api/v1');
    adapter = _ControlledAdapter();
    client.dio.httpClientAdapter = adapter;
  });
  tearDown(() => client.dio.close(force: true));

  test(
    'concurrent authenticated 401 responses clear the whole session once',
    () async {
      final events = <int>[];
      final subscription = client.sessionEnded.listen(events.add);
      final first = client.dio.get('/parent/children');
      final second = client.dio.get('/parent/trips/active');
      final failures = Future.wait([
        expectLater(first, throwsA(isA<DioException>())),
        expectLater(second, throwsA(isA<DioException>())),
      ]);
      await _until(() => adapter.pending.length == 2);
      for (final pending in adapter.pending) {
        pending.complete(_json(401, '{"message":"Expired"}'));
      }
      await failures;
      expect(events, hasLength(1));
      expect(await storage.readAll(), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          AppConstants.keyOfflineBreadcrumbs,
        ),
        isFalse,
      );
      await subscription.cancel();
    },
  );

  test(
    'an old successful response cannot populate a new account session',
    () async {
      final oldRequest = client.dio.get('/parent/children');
      final rejected = expectLater(
        oldRequest,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await _until(() => adapter.pending.length == 1);
      await client.endSession();
      await storage.write(key: AppConstants.keyAuthToken, value: 'account-b');
      client.activateSession();
      adapter.pending.single.complete(_json(200, '{"children":[{"id":123}]}'));
      await rejected;
      expect(await storage.read(key: AppConstants.keyAuthToken), 'account-b');
    },
  );

  test('an old 401 cannot delete the replacement account token', () async {
    final oldRequest = client.dio.get('/parent/children');
    final rejected = expectLater(oldRequest, throwsA(isA<DioException>()));
    await _until(() => adapter.pending.length == 1);
    await client.endSession();
    await storage.write(key: AppConstants.keyAuthToken, value: 'account-b');
    client.activateSession();
    adapter.pending.single.complete(_json(401, '{}'));
    await rejected;
    expect(await storage.read(key: AppConstants.keyAuthToken), 'account-b');
  });

  test('forbidden mode switches preserve the stored mode', () async {
    await storage.write(key: AppConstants.keyActiveMode, value: 'parent');
    final repository = AuthRepository(apiClient: client);
    final change = repository.setActiveMode('driver');
    final rejected = expectLater(change, throwsA(isA<DioException>()));
    await _until(() => adapter.pending.length == 1);
    adapter.pending.single.complete(_json(403, '{"error_code":"FORBIDDEN"}'));
    await rejected;
    expect(await repository.getActiveMode(), 'parent');
  });
  test('a late logout response cannot clear the next login', () async {
    final repository = AuthRepository(apiClient: client);
    final logout = repository.logout();
    await _until(() => adapter.pending.length == 1);
    await client.persistSession(
      client.sessionGeneration,
      () => storage.write(key: AppConstants.keyAuthToken, value: 'account-b'),
      activate: true,
    );
    adapter.pending.single.complete(_json(200, '{}'));
    await logout;
    expect(await storage.read(key: AppConstants.keyAuthToken), 'account-b');
  });

  test('logout clears credential writes already in flight', () async {
    final started = Completer<void>();
    final finishWrite = Completer<void>();
    final persist = client.persistSession(client.sessionGeneration, () async {
      started.complete();
      await finishWrite.future;
      await storage.write(key: AppConstants.keyAuthToken, value: 'stale-token');
    }, activate: true);
    final rejected = expectLater(persist, throwsStateError);
    await started.future;
    final logout = client.endSession();
    finishWrite.complete();
    await rejected;
    await logout;
    expect(await storage.readAll(), isEmpty);
  });
  test(
    'an older logout cannot replace the authenticated replacement account',
    () async {
      final bloc = AuthBloc(authRepository: AuthRepository(apiClient: client));
      addTearDown(bloc.close);
      bloc.add(LogoutRequested());
      await _until(() => adapter.pending.length == 1);
      bloc.add(
        const LoginSubmitted(
          login: 'second@example.test',
          password: 'password',
        ),
      );
      await _until(() => adapter.pending.length == 2);
      adapter.pending[1].complete(
        _json(
          200,
          '{"token":"account-b","user":{"id":2,"role":"parent","active_mode":"parent"},"centrifugo":{"token":"jwt-b","ws_url":"wss://example.invalid"}}',
        ),
      );
      await _until(() => bloc.state is Authenticated);
      adapter.pending[0].complete(_json(200, '{}'));
      await Future<void>.delayed(Duration.zero);
      expect(
        bloc.state,
        isA<Authenticated>().having((state) => state.user['id'], 'account', 2),
      );
      expect(await storage.read(key: AppConstants.keyAuthToken), 'account-b');
    },
  );

  test(
    'an obsolete login failure cannot replace a newer successful login',
    () async {
      final bloc = AuthBloc(authRepository: AuthRepository(apiClient: client));
      addTearDown(bloc.close);
      bloc.add(
        const LoginSubmitted(login: 'first@example.test', password: 'password'),
      );
      await _until(() => adapter.pending.length == 1);
      bloc.add(
        const LoginSubmitted(
          login: 'second@example.test',
          password: 'password',
        ),
      );
      await _until(() => adapter.pending.length == 2);
      adapter.pending[1].complete(
        _json(
          200,
          '{"token":"account-b","user":{"id":2,"role":"parent","active_mode":"parent"},"centrifugo":{"token":"jwt-b","ws_url":"wss://example.invalid"}}',
        ),
      );
      await _until(() => bloc.state is Authenticated);
      adapter.pending[0].complete(
        _json(422, '{"message":"Invalid credentials"}'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        bloc.state,
        isA<Authenticated>().having((state) => state.user['id'], 'account', 2),
      );
    },
  );
}
