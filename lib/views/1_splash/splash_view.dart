import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_constants.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import '../../data/mock_data.dart';
import '../../data/models/purchase_session.dart';
import '../2_home/home_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    TelemetryTracker().startSession();
    TelemetryTracker().startStep('Splash');

    // Inicializar sesión con el cine por defecto de Trujillo
    final defaultCinema = MockData.cinemas.firstWhere(
      (c) => c.id == AppConstants.defaultCinemaId,
      orElse: () => MockData.cinemas.first,
    );
    PurchaseSession().setCinema(defaultCinema);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();

    // Transición fluida a Inicio después de 1.8 segundos
    _navigationTimer = Timer(const Duration(milliseconds: 1800), _goToHome);
  }

  void _goToHome() {
    if (!mounted) return;
    TelemetryTracker().completeStep('Splash');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const HomeView(),
        transitionsBuilder: (context, anim1, anim2, child) {
          return FadeTransition(opacity: anim1, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: InkWell(
        onTap: _goToHome, // Control del usuario: puede tocar para avanzar inmediatamente
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Hero(
                tag: 'cinemark-logo',
                child: SvgPicture.asset(
                  'assets/logo-tm.svg',
                  width: 240,
                  placeholderBuilder: (context) => const Text(
                    'CINEMARK™',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDD0000),
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
