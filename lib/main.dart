import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/build_config.dart';
import 'login_page.dart';
import 'pages/home_page.dart';
import 'pages/splash_page.dart';
import 'services/log_service.dart';
import 'services/session_store.dart';
import 'services/xg_http.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _guardReleaseEnv();

      await XgHttp.instance.resetSessionArtifacts(source: 'app_launch');
      await LogService().resetXgTraceSession();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        LogService().logRuntime(
          'Flutter Error: ${details.exception}\nStack: ${details.stack}',
        );
      };

      final home = await _resolveStartupHome();
      runApp(MyApp(home: SplashPage(nextPage: home)));
    },
    (error, stack) {
      LogService().logRuntime('Async Error: $error\nStack: $stack');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        final now = DateTime.now();
        final timeStr =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        parent.print(zone, '$timeStr $line');
      },
    ),
  );
}

Future<Widget> _resolveStartupHome() async {
  final store = SessionStore();
  final hasRecoverableSession = await store.hasRecoverableLoginSession();
  if (!hasRecoverableSession) {
    return const LoginPage();
  }
  return const HomePage();
}

void _guardReleaseEnv() {
  if (kReleaseMode && !BuildConfig.isProd) {
    final message =
        '发布构建环境错误：APP_ENV=${BuildConfig.rawAppEnv}，发布构建必须使用 --dart-define=APP_ENV=prod';
    debugPrint('❌ $message');
    throw StateError(message);
  }

  debugPrint('🌐 APP_ENV=${BuildConfig.envName}');
}

class MyApp extends StatelessWidget {
  final Widget home;

  const MyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '校园助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E90FF)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      home: home,
    );
  }
}
