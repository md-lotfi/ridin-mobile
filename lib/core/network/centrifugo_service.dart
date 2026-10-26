import 'dart:async';
import 'dart:convert';
import 'package:centrifuge/centrifuge.dart';

class CentrifugoService {
  Client? _client;
  Future<String> Function(String? channel)? tokenProvider;
  bool _connected = false;
  final _deniedChannels = StreamController<String>.broadcast();
  Stream<String> get deniedChannels => _deniedChannels.stream;
  int _generation = 0;
  final Map<String, Subscription> _subscriptions = {};
  final Map<String, void Function(Map<String, dynamic>)> _handlers = {};
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  Stream<bool> get isConnectedStream => _connectionStateController.stream;
  bool get isConnected => _connected;

  Future<void> connect({required String wsUrl, required String token}) async {
    disconnect();
    final generation = _generation;

    _client = createClient(
      wsUrl,
      ClientConfig(
        token: token,
        getToken: tokenProvider == null
            ? null
            : (_) async {
                final fresh = await tokenProvider!(null);
                return generation == _generation ? fresh : '';
              },
      ),
    );

    _client?.connected.listen((_) {
      if (generation != _generation) return;
      _connected = true;
      _connectionStateController.add(true);
    });

    _client?.disconnected.listen((_) {
      if (generation != _generation) return;
      _connected = false;
      _connectionStateController.add(false);
    });

    _client?.error.listen((_) {
      if (generation != _generation) return;
      _connected = false;
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
    final generation = _generation;
    _handlers[channel] = onData;

    if (_subscriptions.containsKey(channel)) return;
    final client = _client!;
    final initialToken = token ?? (await tokenProvider?.call(channel) ?? '');
    if (generation != _generation ||
        client != _client ||
        _subscriptions.containsKey(channel)) {
      return;
    }
    final subscription = client.newSubscription(
      channel,
      SubscriptionConfig(
        token: initialToken,
        getToken: tokenProvider == null
            ? null
            : (_) async {
                try {
                  final fresh = await tokenProvider!(channel);
                  if (generation != _generation) throw UnauthorizedException();
                  return fresh;
                } on UnauthorizedException {
                  if (generation == _generation) _deniedChannels.add(channel);
                  rethrow;
                }
              },
      ),
    );

    subscription.publication.listen((PublicationEvent event) {
      try {
        final decoded =
            jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
        if (generation == _generation) _handlers[channel]?.call(decoded);
      } catch (_) {}
    });

    _subscriptions[channel] = subscription;
    try {
      await subscription.subscribe().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Non-blocking timeout guard: prevents hanging if network/centrifugo connection is delayed
    }
  }

  Future<void> subscribePersonalChannel(int userId, String mode) async {
    if (mode != 'driver' && mode != 'parent') return;
    await subscribeToChannel(
      channel: 'private:$mode.$userId',
      onData: (data) {
        final tripId = data['trip_id'];
        if (tripId != null) _handlers['trips:$tripId']?.call(data);
      },
    );
  }

  Future<void> retainTripChannels(Set<String> channels) async {
    for (final channel
        in _subscriptions.keys
            .where(
              (channel) =>
                  channel.startsWith('trips:') && !channels.contains(channel),
            )
            .toList()) {
      await unsubscribeFromChannel(channel);
    }
  }

  Future<void> unsubscribeFromChannel(String channel) async {
    final subscription = _subscriptions.remove(channel);
    _handlers.remove(channel);
    final client = _client;
    if (subscription != null && client != null) {
      try {
        await client
            .removeSubscription(subscription)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  void disconnect() {
    _generation++;
    _connected = false;
    for (final sub in _subscriptions.values) {
      sub.unsubscribe();
    }
    _subscriptions.clear();
    _handlers.clear();
    _client?.disconnect();
    _client = null;
    _connectionStateController.add(false);
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _deniedChannels.close();
  }
}
