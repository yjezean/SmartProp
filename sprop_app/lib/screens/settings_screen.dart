import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final MqttService mqttService;

  const SettingsScreen({
    super.key,
    required this.mqttService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _mqttController = TextEditingController();
  final _apiController = TextEditingController();
  final _mqttUsernameController = TextEditingController();
  final _mqttPasswordController = TextEditingController();
  bool _isTesting = false;
  bool _mqttConnected = false;
  bool _apiConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final mqttUrl = await ConfigService.getMqttBrokerUrl();
    final apiUrl = await ConfigService.getApiBaseUrl();
    final mqttUsername = await ConfigService.getMqttUsername();
    final mqttPassword = await ConfigService.getMqttPassword();

    setState(() {
      _mqttController.text = mqttUrl;
      _apiController.text = apiUrl;
      _mqttUsernameController.text = mqttUsername;
      _mqttPasswordController.text = mqttPassword;
    });
  }

  Future<void> _testConnections() async {
    setState(() {
      _isTesting = true;
      _mqttConnected = false;
      _apiConnected = false;
    });

    // Test API
    String apiError = '';
    try {
      print('[SETTINGS] Testing API connection...');
      final apiOk = await ApiService.testConnection();
      setState(() {
        _apiConnected = apiOk;
      });
      if (!apiOk) {
        apiError = 'API test returned false';
      }
    } catch (e) {
      print('[SETTINGS] API test error: $e');
      apiError = e.toString();
      setState(() {
        _apiConnected = false;
      });
    }

    // Test MQTT
    String mqttError = '';
    try {
      print('[SETTINGS] Testing MQTT connection...');
      // Disconnect first if connected
      if (widget.mqttService.isConnected) {
        await widget.mqttService.disconnect();
        await Future.delayed(const Duration(seconds: 1));
      }
      // Try to connect
      await widget.mqttService.connect();
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _mqttConnected = widget.mqttService.isConnected;
      });
      if (!_mqttConnected) {
        mqttError = 'MQTT connection attempt failed';
      }
    } catch (e) {
      print('[SETTINGS] MQTT test error: $e');
      mqttError = e.toString();
      setState(() {
        _mqttConnected = false;
      });
    }

    setState(() {
      _isTesting = false;
    });

    if (mounted) {
      final allConnected = _mqttConnected && _apiConnected;
      final errorMsg = allConnected
          ? 'All connections successful!'
          : 'Connection failed.\n'
              '${!_apiConnected ? "API: $apiError\n" : ""}'
              '${!_mqttConnected ? "MQTT: $mqttError" : ""}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: allConnected ? AppTheme.success : AppTheme.error,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    await ConfigService.setMqttBrokerUrl(_mqttController.text);
    await ConfigService.setApiBaseUrl(_apiController.text);
    await ConfigService.setMqttUsername(_mqttUsernameController.text);
    await ConfigService.setMqttPassword(_mqttPasswordController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Settings saved successfully! Reconnect MQTT to apply changes.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  void dispose() {
    _mqttController.dispose();
    _apiController.dispose();
    _mqttUsernameController.dispose();
    _mqttPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Settings Section
          Text(
            'Connection Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),

          // MQTT Broker URL
          TextField(
            controller: _mqttController,
            decoration: const InputDecoration(
              labelText: 'MQTT Broker URL',
              hintText: 'ssl://34.87.144.95:8883',
              helperText: 'Format: ssl://host:port or tcp://host:port',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // MQTT Username
          TextField(
            controller: _mqttUsernameController,
            decoration: const InputDecoration(
              labelText: 'MQTT Username',
              hintText: 'Enter MQTT broker username',
              helperText: 'Required for MQTT connection',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // MQTT Password
          TextField(
            controller: _mqttPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'MQTT Password',
              hintText: 'Enter MQTT broker password',
              helperText: 'Required for MQTT connection',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // API Base URL
          TextField(
            controller: _apiController,
            decoration: const InputDecoration(
              labelText: 'API Base URL',
              hintText: 'http://34.87.144.95:8000/api/v1',
              helperText: 'Use http:// (not https://) unless SSL is configured',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Test Connections Button
          ElevatedButton.icon(
            onPressed: _isTesting ? null : _testConnections,
            icon: _isTesting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi),
            label: const Text('Test Connections'),
          ),
          const SizedBox(height: 16),

          // Connection Status
          if (_isTesting || _mqttConnected || _apiConnected) ...[
            Card(
              color: AppTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusRow('MQTT Broker', _mqttConnected),
                    _buildStatusRow('API Server', _apiConnected),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // About Section
          Text(
            'About',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),
          Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compost Monitor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Save Button
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool connected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            connected ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: connected ? AppTheme.success : AppTheme.error,
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            connected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: connected ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
