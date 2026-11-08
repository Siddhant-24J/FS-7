import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class FS7App extends ConsumerWidget {
  const FS7App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FS-7',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            backgroundColor: const Color(0xFF0E0E0E),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center, color: Color(0xFFF58000), size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'FS-7 Gym Staff App',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exceptionAsString().contains('PostgrestException') || details.exceptionAsString().contains('DOCTYPE html')
                          ? 'Please refresh the page or restart the preview to load the updated secure state.'
                          : details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return child ?? const SizedBox();
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'IN'),
      ],
      locale: const Locale('en', 'IN'),
    );
  }
}

