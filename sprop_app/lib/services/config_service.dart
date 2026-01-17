import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _mqttBrokerKey = 'mqtt_broker_url';
  static const String _apiBaseUrlKey = 'api_base_url';
  static const String _mqttUsernameKey = 'mqtt_username';
  static const String _mqttPasswordKey = 'mqtt_password';

  // Default values
  static const String defaultMqttBroker = 'ssl://34.124.234.109:8883';
  static const String defaultApiBaseUrl = 'https://34.124.234.109:8000/api/v1';
  static const String defaultMqttUsername = 'your_username'; // Set via settings
  static const String defaultMqttPassword = 'abc1234'; // Set via settings

  static Future<String> getMqttBrokerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mqttBrokerKey) ?? defaultMqttBroker;
  }

  static Future<void> setMqttBrokerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mqttBrokerKey, url);
  }

  static Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiBaseUrlKey) ?? defaultApiBaseUrl;
  }

  static Future<void> setApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlKey, url);
  }

  static Future<String> getMqttUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mqttUsernameKey) ?? defaultMqttUsername;
  }

  static Future<void> setMqttUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mqttUsernameKey, username);
  }

  static Future<String> getMqttPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mqttPasswordKey) ?? defaultMqttPassword;
  }

  static Future<void> setMqttPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mqttPasswordKey, password);
  }

  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mqttBrokerKey);
    await prefs.remove(_apiBaseUrlKey);
    await prefs.remove(_mqttUsernameKey);
    await prefs.remove(_mqttPasswordKey);
  }
}
