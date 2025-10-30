import 'package:flutter/material.dart';
import 'package:test_map/MapStreet.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Mapstreet());
  }
}
