import 'package:flutter/material.dart';
import 'src/views/home_view.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Beauty',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: HomeView(),
    );
  }
}

