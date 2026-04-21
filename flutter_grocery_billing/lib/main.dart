import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/app_settings.dart';
import 'services/settings_service.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final settings = await SettingsService.load();

  runApp(GroceryBillingApp(initialSettings: settings));
}

class GroceryBillingApp extends StatelessWidget {
  final AppSettings initialSettings;
  const GroceryBillingApp({super.key, required this.initialSettings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery Billing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF66BB6A),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansBengali',
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
      ),
      home: MainShell(initialSettings: initialSettings),
    );
  }
}

class MainShell extends StatefulWidget {
  final AppSettings initialSettings;
  const MainShell({super.key, required this.initialSettings});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentTab = 0;
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  Future<void> _reloadSettings() async {
    final s = await SettingsService.load();
    setState(() => _settings = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Only 2 tabs: Home + History (no bloat)
      body: IndexedStack(
        index: _currentTab,
        children: [
          HomeScreen(
            settings: _settings,
            onSettingsChanged: _reloadSettings,
          ),
          HistoryScreen(settings: _settings),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F5E9),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF2E7D32)),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFF2E7D32)),
            label: 'ইতিহাস',
          ),
        ],
      ),
    );
  }
}
