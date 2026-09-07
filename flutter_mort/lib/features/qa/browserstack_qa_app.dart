import 'package:flutter/material.dart';

/// Temporary isolated shell for local BrowserStack functional QA.
///
/// Task 2 replaces this body with the fixture router.
class BrowserStackQaApp extends StatelessWidget {
  const BrowserStackQaApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SizedBox.shrink()),
  );
}
