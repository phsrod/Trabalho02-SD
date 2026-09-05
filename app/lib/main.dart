import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const FotoViaBotaoApp());
}

class FotoViaBotaoApp extends StatelessWidget {
  const FotoViaBotaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foto via Botão',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}