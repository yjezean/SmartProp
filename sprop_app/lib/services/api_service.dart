import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/sensor_data.dart';
import 'config_service.dart';

class ApiService {
  static Future<String> getBaseUrl() => ConfigService.getApiBaseUrl();

  // Create HTTP client that accepts self-signed certificates
  static http.Client _createHttpClient() {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // Accept self-signed certificates
      return true;
    };
    return IOClient(httpClient);
  }

  // Get historical sensor data
  static Future<List<SensorData>> getSensorData({int days = 7}) async {
    final client = _createHttpClient();
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/sensor-data?days=$days';
      print('[API] Fetching sensor data from: $url');
      final response = await client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      print('[API] Sensor data response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final dataList = jsonData['data'] as List;
        return dataList
            .map((item) => SensorData.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load sensor data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching sensor data: $e');
    } finally {
      client.close();
    }
  }

  static Future<bool> testConnection() async {
    final client = _createHttpClient();
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse(baseUrl.replaceAll('/api/v1', '/health'));
      print('[API] Testing connection to: $uri');
      final response =
          await client.get(uri).timeout(const Duration(seconds: 5));
      print('[API] Response status: ${response.statusCode}');
      print('[API] Response body: ${response.body}');
      return response.statusCode == 200;
    } catch (e, stackTrace) {
      print('[API] Connection test failed: $e');
      print('[API] Stack trace: $stackTrace');
      return false;
    } finally {
      client.close();
    }
  }

  // Optimization Settings Endpoints

  // Get optimization status
  static Future<bool> getOptimizationStatus() async {
    final client = _createHttpClient();
    try {
      final baseUrl = await getBaseUrl();
      final response = await client.get(
        Uri.parse('$baseUrl/optimization/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return jsonData['enabled'] as bool;
      } else {
        throw Exception(
            'Failed to load optimization status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching optimization status: $e');
    } finally {
      client.close();
    }
  }

  // Set optimization status
  static Future<bool> setOptimizationStatus(bool enabled) async {
    final client = _createHttpClient();
    try {
      final baseUrl = await getBaseUrl();
      final response = await client
          .put(
            Uri.parse('$baseUrl/optimization/status'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'enabled': enabled}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return jsonData['enabled'] as bool;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
            'Failed to update optimization status: ${errorBody['detail'] ?? response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating optimization status: $e');
    } finally {
      client.close();
    }
  }
}
