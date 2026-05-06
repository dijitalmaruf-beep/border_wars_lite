import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'game/ui/screens/home_screen.dart';

class BorderWarsLiteApp extends StatelessWidget {
  const BorderWarsLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Border Wars Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.humanBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.screenBackground,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
