import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

class TwinkLegoFinderApp extends StatelessWidget {
  const TwinkLegoFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TwinkLegoFinder',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
