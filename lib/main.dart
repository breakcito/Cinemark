import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/telemetry/telemetry_api_client.dart';
import 'core/telemetry/telemetry_tracker.dart';
import 'core/theme/app_theme.dart';
import 'views/1_splash/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde .env de manera segura
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[Env] No se pudo cargar archivo .env: $e');
  }

  // Inicializar cliente de API con la URL de .env
  TelemetryApiClient().initFromEnv();

  // Iniciar sincronización de participante en tiempo real (multi-dispositivo)
  TelemetryTracker().startLiveParticipantSync();

  // Configurar la barra de estado con colores cinematográficos limpios
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CinemarkApp());
}

class CinemarkApp extends StatelessWidget {
  const CinemarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinemark Perú',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashView(),
      builder: (context, child) {
        // Captura global y silenciosa de toques para telemetría sin interferir con la UI
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            TelemetryTracker().recordTap();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
