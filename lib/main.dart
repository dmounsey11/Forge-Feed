import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/purchase_service.dart';
import 'services/tier_service.dart';
import 'screens/main_screen.dart';

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
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = Future.wait([
      context.read<DatabaseService>().initialize(),
      context.read<TierService>().initialize(),
      context.read<PurchaseService>().initialize(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
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
        return const MainScreen();
      },
    );
  }
}