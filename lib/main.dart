import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider<DatabaseService>(
      create: (_) => DatabaseService(),
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
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF84CC16),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}