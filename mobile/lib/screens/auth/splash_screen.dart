import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: appHeaderGradient),
      child: Stack(
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - value)),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 150),
                  const SizedBox(height: 20),
                  Text(
                    'Vida Assistida',
                    style: display(
                      size: 36,
                      weight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'HOME CARE',
                    style: display(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.teal100,
                      letterSpacing: 3.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 220,
                    child: Text(
                      'Cuidado conectado, informação segura',
                      textAlign: TextAlign.center,
                      style: body(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppColors.teal100,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Container(
                    width: i == 1 ? 24 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == 1 ? 1 : .35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Marca do aplicativo: casa com coração, sinal de saúde e selo de confirmação.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 112});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/logo_splash.png',
    width: size,
    height: size,
    semanticLabel: 'Logo Vida Assistida',
  );
}
