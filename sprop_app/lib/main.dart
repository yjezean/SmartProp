import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/mqtt_service.dart';
import 'providers/sensor_provider.dart';
import 'providers/chart_data_provider.dart';
import 'providers/device_control_provider.dart';
import 'providers/optimization_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chart_screen.dart';
import 'screens/control_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CompostMonitorApp());
}

class CompostMonitorApp extends StatelessWidget {
  const CompostMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize MQTT service
    final mqttService = MqttService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SensorProvider(mqttService)),
        ChangeNotifierProvider(create: (_) => ChartDataProvider()),
        ChangeNotifierProvider(
            create: (_) => DeviceControlProvider(mqttService)),
        ChangeNotifierProvider(create: (_) => OptimizationProvider()),
      ],
      child: MaterialApp(
        title: 'SProp Monitor',
        theme: AppTheme.lightTheme,
        home: AuthWrapper(mqttService: mqttService),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final MqttService mqttService;

  AuthWrapper({
    super.key,
    required this.mqttService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show login screen if not authenticated
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // Show main app if authenticated
        return MainScreen(mqttService: mqttService);
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final MqttService mqttService;

  const MainScreen({
    super.key,
    required this.mqttService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _initializeScreens();
    _connectMqtt();
  }

  void _initializeScreens() {
    _screens.addAll([
      const DashboardScreen(),
      const ChartScreen(),
      ControlScreen(),
      SettingsScreen(mqttService: widget.mqttService),
    ]);
  }

  Future<void> _connectMqtt() async {
    try {
      print('[APP] Attempting MQTT connection...');
      final sensorProvider =
          Provider.of<SensorProvider>(context, listen: false);
      await sensorProvider.connect();
      print('[APP] MQTT connection successful');
    } catch (e, stackTrace) {
      print('[APP] MQTT connection failed: $e');
      print('[APP] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to MQTT: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Charts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_remote),
            label: 'Control',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.mqttService.dispose();
    super.dispose();
  }
}
