import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/reminders.dart';
import 'core/session.dart';
import 'models.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VidaAssistidaApp());
}

class VidaAssistidaApp extends StatefulWidget {
  const VidaAssistidaApp({super.key});

  @override
  State<VidaAssistidaApp> createState() => _VidaAssistidaAppState();
}

class _VidaAssistidaAppState extends State<VidaAssistidaApp> {
  final ApiClient _api = ApiClient();
  final AppSettings _settings = AppSettings();
  late final NotificationCenter _notifications = NotificationCenter(
    _api,
    _settings,
  );
  CareStore? _store;
  UserProfile? _user;
  bool _splash = true;

  @override
  void initState() {
    super.initState();
    _settings.load();
    _settings.addListener(_onSettings);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() => setState(() {});

  void _onAuthenticated(UserProfile user) => setState(() {
    if (_user?.id != user.id) {
      _store = CareStore(_api, _notifications)..load();
    }
    _user = user;
  });

  void _logout() {
    _api.clearSession();
    MedicationReminders.instance.clear();
    setState(() {
      _user = null;
      _store = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final app = MaterialApp(
      title: 'Vida Assistida Home Care',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MobileFrame(
        textScale: _settings.textScale,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _splash
          ? SplashScreen(onDone: () => setState(() => _splash = false))
          : user == null
          ? LoginScreen(
              api: _api,
              settings: _settings,
              onAuthenticated: _onAuthenticated,
            )
          : const HomeShell(),
    );
    if (user == null || _store == null) return app;
    return Session(
      api: _api,
      user: user,
      settings: _settings,
      notifications: _notifications,
      store: _store!,
      onLogout: _logout,
      onUserUpdated: _onAuthenticated,
      child: app,
    );
  }
}

/// Moldura de celular no navegador/tablet, como no protótipo do Figma.
class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child, this.textScale = 1});

  final Widget child;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scaled = media.copyWith(textScaler: TextScaler.linear(textScale));
    final size = media.size;
    if (size.width < 640) {
      return MediaQuery(
        data: scaled,
        child: ColoredBox(
          color: AppColors.canvas,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: child,
            ),
          ),
        ),
      );
    }
    final height = (size.height - 32).clamp(560.0, 900.0);
    const width = 430.0;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: backdropGradient),
      child: Stack(
        children: [
          const Positioned.fill(child: _BackdropGlow()),
          Center(
            child: Container(
              width: width + 16,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .86),
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x381C3E48),
                    blurRadius: 80,
                    offset: Offset(0, 32),
                  ),
                  BoxShadow(
                    color: Color(0x1F1C3E48),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: MediaQuery(
                  data: scaled.copyWith(
                    size: Size(width, height - 16),
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                  ),
                  child: ColoredBox(color: AppColors.canvas, child: child),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow();

  @override
  Widget build(BuildContext context) => const Stack(
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.7, -.7),
              radius: .7,
              colors: [Color(0x3314B8A6), Color(0x0014B8A6)],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(.7, .6),
              radius: .65,
              colors: [Color(0x2E0E7490), Color(0x000E7490)],
            ),
          ),
        ),
      ),
    ],
  );
}
