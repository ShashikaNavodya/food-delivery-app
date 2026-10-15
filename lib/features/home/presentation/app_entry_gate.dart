import 'package:flutter/material.dart';

import '../application/food_app_controller.dart';
import '../data/food_repository.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'splash_screen.dart';

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  late final FoodAppController _controller;
  String? _startupError;
  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    _controller = FoodAppController(FoodRepository())..addListener(_refresh);
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minimumSplashElapsed = true);
    });
    _initialize();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..disposeRepository()
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    setState(() => _startupError = null);
    try {
      await _controller.initialize();
    } catch (error) {
      if (mounted) setState(() => _startupError = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 42),
                const SizedBox(height: 16),
                const Text(
                  'Savor could not start.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(_startupError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _initialize,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller.isInitializingSession || !_minimumSplashElapsed) {
      return const SplashScreen();
    }
    if (!_controller.isSignedIn) {
      return AuthScreen(controller: _controller, isEntryFlow: true);
    }
    return HomeScreen(controller: _controller);
  }
}
