import 'package:flutter/material.dart';

class HomePlaceholderView extends StatelessWidget {
  const HomePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            'Sendaris',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
