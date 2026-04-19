import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

class AppNavigationHistory extends ChangeNotifier {
  AppNavigationHistory._();

  static final AppNavigationHistory instance = AppNavigationHistory._();

  final List<String> _backStack = <String>[];
  final List<String> _forwardStack = <String>[];
  String? _currentLocation;

  bool get canGoBack => _backStack.isNotEmpty;
  bool get canGoForward => _forwardStack.isNotEmpty;

  void record(String location) {
    if (location.isEmpty || _currentLocation == location) {
      return;
    }

    if (_currentLocation != null) {
      _backStack.add(_currentLocation!);
    }
    _currentLocation = location;
    _forwardStack.clear();
    notifyListeners();
  }

  void goBack(GoRouter router) {
    if (!canGoBack || _currentLocation == null) {
      return;
    }

    final String target = _backStack.removeLast();
    _forwardStack.add(_currentLocation!);
    _currentLocation = target;
    notifyListeners();
    router.go(target);
  }

  void goForward(GoRouter router) {
    if (!canGoForward || _currentLocation == null) {
      return;
    }

    final String target = _forwardStack.removeLast();
    _backStack.add(_currentLocation!);
    _currentLocation = target;
    notifyListeners();
    router.go(target);
  }
}
