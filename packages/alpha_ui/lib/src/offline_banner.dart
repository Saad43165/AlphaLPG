import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Wraps the whole app: when the phone has no internet, a slim bar says so
/// (instead of screens silently showing old or empty data).
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child, this.probe});
  final Widget child;

  /// Returns true when the internet is reachable. Defaults to a DNS lookup.
  final Future<bool> Function()? probe;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  Timer? _timer;
  bool _offline = false;
  int _misses = 0;

  static Future<bool> _lookup() async {
    try {
      final r = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(seconds: 4));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Widget tests must not be left with a running timer.
    final testing = Platform.environment.containsKey('FLUTTER_TEST');
    if (widget.probe == null && testing) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _check());
    _check();
  }

  Future<void> _check() async {
    final ok = await (widget.probe ?? _lookup)();
    if (!mounted) return;
    // Two misses in a row, so one slow lookup does not flash the bar.
    _misses = ok ? 0 : _misses + 1;
    final off = _misses >= 2;
    if (off != _offline) setState(() => _offline = off);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return widget.child;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF3A3F47),
          child: SafeArea(
            bottom: false,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                      child: Text('No internet. Showing the last saved data.'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
