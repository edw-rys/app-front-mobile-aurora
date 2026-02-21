import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivity state
class ConnectivityState {
  final bool isOnline;
  final DateTime? lastChecked;

  const ConnectivityState({this.isOnline = true, this.lastChecked});
}

/// Connectivity notifier
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  StreamSubscription? _subscription;

  ConnectivityNotifier() : super(const ConnectivityState()) {
    _init();
  }

  Future<void> _init() async {
    final results = await Connectivity().checkConnectivity();
    state = ConnectivityState(
      isOnline: _isConnected(results),
      lastChecked: DateTime.now(),
    );

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      state = ConnectivityState(
        isOnline: _isConnected(results),
        lastChecked: DateTime.now(),
      );
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Connectivity provider
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

/// Simple boolean provider for is online
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).isOnline;
});
