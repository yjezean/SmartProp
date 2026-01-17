import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/user.dart';
import 'config_service.dart';

class AuthService {
  static Future<String> getBaseUrl() async {
    final baseUrl = await ConfigService.getApiBaseUrl();
    // Remove /api/v1 if present, we'll add /api/v1/auth
    return baseUrl.replaceAll('/api/v1', '');
  }

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

  // Register a new user
  static Future<User> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    final client = _createHttpClient();
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/api/v1/auth/register');

      print('[Auth] Registering user: $username');
      print('[Auth] Base URL: $baseUrl');
      print('[Auth] Full URL: $url');

      final response = await client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': username,
              'email': email,
              'password': password,
              if (fullName != null && fullName.isNotEmpty)
                'full_name': fullName,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('[Auth] Register response: ${response.statusCode}');
      print('[Auth] Response body: ${response.body}');

      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return User.fromJson(jsonData);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Registration failed');
      }
    } on SocketException catch (e) {
      print('[Auth] Socket error: $e');
      throw Exception('Cannot connect to server. Please check:\n'
          '1. Server is running\n'
          '2. Network connection\n'
          '3. API URL in settings: ${await getBaseUrl()}');
    } on HttpException catch (e) {
      print('[Auth] HTTP error: $e');
      throw Exception('HTTP error: $e');
    } on FormatException catch (e) {
      print('[Auth] Format error: $e');
      throw Exception('Invalid response format: $e');
    } catch (e) {
      print('[Auth] Registration error: $e');
      if (e.toString().contains('Connection refused')) {
        throw Exception('Connection refused. Please check:\n'
            '1. Server is running on port 8000\n'
            '2. Firewall allows connections\n'
            '3. API URL is correct: ${await getBaseUrl()}');
      }
      throw Exception('Registration failed: $e');
    } finally {
      client.close();
    }
  }

  // Login and get access token
  static Future<String> login({
    required String username,
    required String password,
  }) async {
    final client = _createHttpClient();
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/api/v1/auth/login');

      print('[Auth] Logging in user: $username');
      print('[Auth] Base URL: $baseUrl');
      print('[Auth] Full URL: $url');

      final response = await client
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'username=$username&password=$password',
          )
          .timeout(const Duration(seconds: 30));

      print('[Auth] Login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final token = jsonData['access_token'] as String;

        // Store token
        await ConfigService.setAuthToken(token);

        return token;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Login failed');
      }
    } on SocketException catch (e) {
      print('[Auth] Socket error: $e');
      throw Exception('Cannot connect to server. Please check:\n'
          '1. Server is running\n'
          '2. Network connection\n'
          '3. API URL in settings: ${await getBaseUrl()}');
    } on HttpException catch (e) {
      print('[Auth] HTTP error: $e');
      throw Exception('HTTP error: $e');
    } catch (e) {
      print('[Auth] Login error: $e');
      if (e.toString().contains('Connection refused')) {
        throw Exception('Connection refused. Please check:\n'
            '1. Server is running on port 8000\n'
            '2. Firewall allows connections\n'
            '3. API URL is correct: ${await getBaseUrl()}');
      }
      throw Exception('Login failed: $e');
    } finally {
      client.close();
    }
  }

  // Get current user information
  static Future<User> getCurrentUser() async {
    final client = _createHttpClient();
    try {
      final token = await ConfigService.getAuthToken();
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/api/v1/auth/me');

      print('[Auth] Fetching current user info');

      final response = await client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('[Auth] Get user response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return User.fromJson(jsonData);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Failed to get user info');
      }
    } catch (e) {
      print('[Auth] Get user error: $e');
      throw Exception('Failed to get user info: $e');
    } finally {
      client.close();
    }
  }

  // Logout
  static Future<void> logout() async {
    await ConfigService.clearAuthToken();
    print('[Auth] User logged out');
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await ConfigService.getAuthToken();
    return token != null && token.isNotEmpty;
  }
}
