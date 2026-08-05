import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  StreamSubscription? _connectivitySub;
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  static Future<void> initialize() async {
    await _instance._init();
  }

  Future<void> _init() async {
    // Initial check
    final results = await Connectivity().checkConnectivity();
    _handleConnectivityChange(results);

    // Listen for changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final currentlyOffline =
        results.contains(ConnectivityResult.none) || results.isEmpty;

    if (currentlyOffline != _isOffline) {
      _isOffline = currentlyOffline;
      if (_isOffline) {
        debugPrint(
          'NetworkService: Connection lost. Disabling Firestore network to force cache mode.',
        );
        FirebaseFirestore.instance.disableNetwork();
      } else {
        debugPrint(
          'NetworkService: Connection restored. Enabling Firestore network for sync.',
        );
        FirebaseFirestore.instance.enableNetwork();
      }
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
