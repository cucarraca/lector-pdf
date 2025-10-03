import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider()..initialize(),
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'Lector PDF',
            debugShowCheckedModeBanner: false,
            theme: provider.themeData.themeData,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
