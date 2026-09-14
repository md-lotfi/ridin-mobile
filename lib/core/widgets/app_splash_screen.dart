import 'package:flutter/material.dart';
import 'ridin_logo.dart';

class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RidinLogoIcon(size: 104, showShadow: true),
            SizedBox(height: 24),
            Text(
              'Ridin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Transport scolaire intelligent',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
