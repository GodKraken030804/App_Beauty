import 'package:app_beauty/src/views/home_view.dart';
import 'package:flutter/material.dart';


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

