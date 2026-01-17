import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';
import '../services/api_service.dart';

class ChartDataProvider with ChangeNotifier {
  List<SensorData> _data = [];
  int _selectedDays = 7;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetched;

  List<SensorData> get data => _data;
  int get selectedDays => _selectedDays;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastFetched => _lastFetched;

  void setSelectedDays(int days) {
    _selectedDays = days;
    notifyListeners();
    fetchData();
  }

  Future<void> fetchData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final sensorData = await ApiService.getSensorData(days: _selectedDays);
      _data = sensorData;
      _error = null;
      _lastFetched = DateTime.now();
    } catch (e) {
      _error = e.toString();
      _data = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

