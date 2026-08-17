import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';
import 'services/ad_service.dart';
import 'services/database_service.dart';
import 'services/purchase_service.dart';
import 'services/tier_service.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_disclaimer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DatabaseService>(create: (_) => DatabaseService()),
        ChangeNotifierProvider<TierService>(create: (_) => TierService()),
        ChangeNotifierProvider<PurchaseService>(
          create: (ctx) => PurchaseService(ctx.read<TierService>()),
        ),
      ],
      child: const ForgeFeedApp(),
    ),
  );
}

class ForgeFeedApp extends StatelessWidget {
  const ForgeFeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForgeFeed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          brightness: Brightness.dark,
        ),
      ),
      home: const AppStartup(),
    );
  }
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late final Future<bool> _initFuture;
  bool _disclaimerAccepted = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  Future<bool> _init() async {
    await Future.wait([
      context.read<DatabaseService>().initialize(),
      context.read<TierService>().initialize(),
      context.read<PurchaseService>().initialize(),
      initializeAds(),
    ]);
    return hasAcceptedDisclaimer();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF1A1A1C),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            ),
          );
        }
        if (!(snapshot.data ?? false) && !_disclaimerAccepted) {
          return OnboardingDisclaimerScreen(
            onAccepted: () => setState(() => _disclaimerAccepted = true),
          );
        }
        return UpgradeAlert(
          upgrader: Upgrader(debugLogging: false),
          child: const MainScreen(),
        );
      },
    );
  }
}