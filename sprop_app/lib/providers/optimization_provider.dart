import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class OptimizationProvider with ChangeNotifier {
  bool _isEnabled = true;
  bool _isLoading = false;
  String? _error;

  bool get isEnabled => _isEnabled;
  bool get isLoading => _isLoading;
  String? get error => _error;

  OptimizationProvider() {
    fetchStatus();
  }

  Future<void> fetchStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _isEnabled = await ApiService.getOptimizationStatus();
      _error = null;
    } catch (e) {
      _error = e.toString();
      // Default to enabled on error
      _isEnabled = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _isEnabled = await ApiService.setOptimizationStatus(enabled);
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    await setEnabled(!_isEnabled);
  }
}

