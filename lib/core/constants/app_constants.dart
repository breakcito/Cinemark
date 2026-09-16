class AppConstants {
  static const String appName = 'Cinemark Perú';
  static const String defaultUserName = 'Jhon Franklin';
  static const String defaultUserInitials = 'JB';
  static const String defaultUserEmail = 'jhon.franklin@cinemark.com.pe';

  // Sede por defecto vinculada al estudio en Trujillo
  static const String defaultCinemaId = 'c1';
  static const String defaultCinemaName = 'Cinemark Mallplaza Trujillo';
  static const String defaultCinemaCity = 'Trujillo';

  // Tiempo de sesión para la compra (10 minutos = 600 segundos)
  static const int sessionDurationSeconds = 600;

  // Límite máximo de tickets por transacción
  static const int maxTicketsPerPurchase = 10;

  // Claves de almacenamiento de preferencias (Heurística #5 Prevención de errores / #3 Control del usuario)
  static const String prefNotificationsAsked = 'pref_notifications_asked';
  static const String prefNotificationsEnabled = 'pref_notifications_enabled';
  static const String prefSelectedCinemaId = 'pref_selected_cinema_id';
  static const String prefHasLocationPermission = 'pref_has_location_permission';
}
