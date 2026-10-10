import 'dart:async';
import 'package:flutter/material.dart';

import 'package:roast_n_rizz/l10n/app_localizations.dart';

class MockRewardedAdPage extends StatefulWidget {
  const MockRewardedAdPage({super.key, required this.onRewardEarned});

  /// Called when the user earns the reward. May be async — exceptions are propagated.
  final Future<void> Function() onRewardEarned;

  @override
  State<MockRewardedAdPage> createState() => _MockRewardedAdPageState();
}

class _MockRewardedAdPageState extends State<MockRewardedAdPage> {
  static const _countdownSeconds = 5;

  int _secondsLeft = _countdownSeconds;
  Timer? _timer;
  bool _isCollecting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _collectReward() async {
    if (_isCollecting) return;
    setState(() => _isCollecting = true);
    try {
      await widget.onRewardEarned();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('MockRewardedAdPage: reward callback failed: $e');
      if (mounted) setState(() => _isCollecting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.ondemand_video_rounded,
                  color: Colors.white,
                  size: 72,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.mockAdTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.mockAdBody,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(
                  _secondsLeft > 0
                      ? l10n.mockAdWaiting(_secondsLeft)
                      : l10n.mockAdReady,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_secondsLeft == 0)
                  FilledButton.icon(
                    onPressed: _isCollecting ? null : _collectReward,
                    icon: _isCollecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.card_giftcard_outlined),
                    label: Text(l10n.mockAdButton),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}