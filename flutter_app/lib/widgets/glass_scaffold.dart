import 'package:flutter/material.dart';
import 'glass_background.dart';
import 'glass_app_bar.dart';

/// A complete glass scaffold that wraps common screen patterns
class GlassScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final bool extendBodyBehindAppBar;
  final bool showAppBar;

  const GlassScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.extendBodyBehindAppBar = false,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: GlassAppBar(
                title: title,
                actions: actions,
              ),
            )
          : null,
      body: GlassBackground(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
    );
  }
}
