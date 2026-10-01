import 'package:flutter/material.dart';

import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GushiHelperApp());
}

class GushiHelperApp extends StatelessWidget {
  const GushiHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '诗忆',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D6E63)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
