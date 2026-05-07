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
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: AppColors.premiumBackground,
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.premiumText,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
