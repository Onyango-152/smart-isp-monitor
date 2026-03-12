import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Monitors network connectivity and exposes [isOffline] for the UI.
///
/// Shows a persistent banner when the device has no internet.
/// Uses connectivity_plus to listen for real-time changes.
class ConnectivityProvider extends ChangeNotifier {
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
    // Check once immediately
    Connectivity().checkConnectivity().then(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (offline != _isOffline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// A slim amber banner shown at the top of the screen when offline.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, provider, _) {
        if (!provider.isOffline) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFFEF3C7), // amber-100
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'No internet connection — showing cached data',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706), // amber-600
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
