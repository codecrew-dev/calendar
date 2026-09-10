import 'dart:async';

import 'package:flutter/cupertino.dart';
import '../services/auth_service.dart';

/// Keeps connection monitoring alive across all app pages and routes.
class ServerConnectionMonitor extends StatefulWidget {
  final Widget child;
  const ServerConnectionMonitor({super.key, required this.child});

  static final available = ValueNotifier<bool?>(null);

  @override
  State<ServerConnectionMonitor> createState() => _ServerConnectionMonitorState();
}

class _ServerConnectionMonitorState extends State<ServerConnectionMonitor>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;
  bool _foreground = true;
  bool _connectionAlertVisible = false;
  CupertinoDialogRoute<bool>? _connectionRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConnection());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnection());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _checkConnection();
  }

  Future<void> _checkConnection() async {
    if (!mounted || !_foreground || _checking) return;
    _checking = true;
    try {
      await AuthService.instance.enabledSocialProviders();
      if (!mounted) return;
      ServerConnectionMonitor.available.value = true;
      final route = _connectionRoute;
      if (route != null && route.isActive) route.navigator?.removeRoute(route);
    } on ServerConnectionException {
      if (!mounted) return;
      ServerConnectionMonitor.available.value = false;
      if (_foreground) _showConnectionAlert();
    } catch (_) {
      // Provider configuration errors do not imply a connection outage.
    } finally {
      _checking = false;
    }
  }

  Future<void> _showConnectionAlert() async {
    if (!mounted || _connectionAlertVisible) return;
    _connectionAlertVisible = true;
    final route = CupertinoDialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('서버에 연결할 수 없습니다'),
        content: const Text('인터넷 연결을 확인한 후 새로고침해 주세요.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '새로고침',
              style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(dialogContext)),
            ),
          ),
        ],
      ),
    );
    _connectionRoute = route;
    final refresh = await Navigator.of(context, rootNavigator: true).push(route);
    _connectionRoute = null;
    _connectionAlertVisible = false;
    if (mounted && refresh == true) _checkConnection();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
