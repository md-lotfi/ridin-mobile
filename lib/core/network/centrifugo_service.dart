import 'dart:async';
import 'dart:convert';
import 'package:centrifuge/centrifuge.dart';

class CentrifugoService {
  Client? _client;
  final Map<String, Subscription> _subscriptions = {};
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();

  Stream<bool> get isConnectedStream => _connectionStateController.stream;
  bool get isConnected => _client != null;

  Future<void> connect({
    required String wsUrl,
    required String token,
  }) async {
    disconnect();

    _client = createClient(
      wsUrl,
      ClientConfig(
        token: token,
      ),
    );

    _client?.connected.listen((_) {
      _connectionStateController.add(true);
    });

    _client?.disconnected.listen((_) {
      _connectionStateController.add(false);
    });

    _client?.error.listen((_) {
      _connectionStateController.add(false);
    });

    await _client?.connect();
  }

  Future<void> subscribeToChannel({
    required String channel,
    String? token,
    required void Function(Map<String, dynamic> data) onData,
  }) async {
    if (_client == null) return;

    if (_subscriptions.containsKey(channel)) {
      try {
        await _subscriptions[channel]?.unsubscribe().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    final subscription = _client!.newSubscription(
      channel,
      SubscriptionConfig(
        token: token ?? '',
      ),
    );

    subscription.publication.listen((PublicationEvent event) {
      try {
        final decoded = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
        onData(decoded);
      } catch (_) {}
    });

    _subscriptions[channel] = subscription;
    try {
      await subscription.subscribe().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Non-blocking timeout guard: prevents hanging if network/centrifugo connection is delayed
    }
  }

  Future<void> unsubscribeFromChannel(String channel) async {
    if (_subscriptions.containsKey(channel)) {
      try {
        await _subscriptions[channel]?.unsubscribe().timeout(const Duration(seconds: 2));
      } catch (_) {}
      _subscriptions.remove(channel);
    }
  }

  void disconnect() {
    for (final sub in _subscriptions.values) {
      sub.unsubscribe();
    }
    _subscriptions.clear();
    _client?.disconnect();
    _client = null;
    _connectionStateController.add(false);
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
  }
}
