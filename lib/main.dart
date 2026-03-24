import 'package:flutter/material.dart';
import 'package:mobile/screens/splash_screen.dart';

void main() {
  runApp(const WeighGuardApp());
}

class WeighGuardApp extends StatelessWidget {
  const WeighGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeighGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter', 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A7B51),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}