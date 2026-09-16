import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/telemetry/telemetry_tracker.dart';
import 'cinema_model.dart';
import 'movie_model.dart';
import 'showtime_model.dart';
import 'ticket_model.dart';

class PurchaseSession extends ChangeNotifier {
  static final PurchaseSession _instance = PurchaseSession._internal();
  factory PurchaseSession() => _instance;
  PurchaseSession._internal();

  Cinema? _selectedCinema;
  Movie? _selectedMovie;
  DateTime _selectedDate = DateTime.now();
  Showtime? _selectedShowtime;

  // Mapa de TicketType -> cantidad seleccionada
  final Map<String, int> _ticketQuantities = {};

  // Tickets canjeados por cupones (Batch Vouchers)
  final List<RedeemedCouponTicket> _redeemedTickets = [];

  // Temporizador de sesión
  Timer? _sessionTimer;
  int _remainingSeconds = AppConstants.sessionDurationSeconds;
  bool _isTimerRunning = false;
  bool _isSessionExpired = false;

  // Getters
  Cinema? get selectedCinema => _selectedCinema;
  Movie? get selectedMovie => _selectedMovie;
  DateTime get selectedDate => _selectedDate;
  Showtime? get selectedShowtime => _selectedShowtime;
  Map<String, int> get ticketQuantities => Map.unmodifiable(_ticketQuantities);
  List<RedeemedCouponTicket> get redeemedTickets =>
      List.unmodifiable(_redeemedTickets);

  int get remainingSeconds => _remainingSeconds;
  bool get isTimerRunning => _isTimerRunning;
  bool get isSessionExpired => _isSessionExpired;

  String get formattedTimeRemaining {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get isTimerCritical => _remainingSeconds <= 120; // Menos de 2 min

  int get totalRegularTickets {
    return _ticketQuantities.values.fold(0, (sum, count) => sum + count);
  }

  int get totalRedeemedTickets => _redeemedTickets.length;

  int get totalTicketCount => totalRegularTickets + totalRedeemedTickets;

  double calculateTotalAmount(List<TicketType> availableTypes) {
    double total = 0.0;
    _ticketQuantities.forEach((typeId, qty) {
      final type = availableTypes.firstWhere(
        (t) => t.id == typeId,
        orElse: () => const TicketType(
          id: '',
          name: '',
          price: 0,
          category: '',
        ),
      );
      total += type.price * qty;
    });
    return total;
  }

  void setCinema(Cinema cinema) {
    _selectedCinema = cinema;
    notifyListeners();
  }

  void selectMovie(Movie movie) {
    _selectedMovie = movie;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void selectShowtime(Showtime showtime) {
    _selectedShowtime = showtime;
    // Al seleccionar horario, iniciamos el temporizador de sesión visible
    startTimer();
    notifyListeners();
  }

  void updateTicketQuantity(String ticketTypeId, int delta, {int max = 10}) {
    final current = _ticketQuantities[ticketTypeId] ?? 0;
    final newCount = current + delta;
    if (newCount <= 0) {
      _ticketQuantities.remove(ticketTypeId);
    } else {
      if (totalTicketCount + delta > AppConstants.maxTicketsPerPurchase) {
        TelemetryTracker().recordError(
          'Tickets',
          'Límite Excedido',
          'Intento de seleccionar más de ${AppConstants.maxTicketsPerPurchase} entradas',
        );
        return;
      }
      _ticketQuantities[ticketTypeId] = newCount;
    }
    notifyListeners();
  }

  void addBatchRedeemedTickets(List<RedeemedCouponTicket> tickets) {
    if (totalTicketCount + tickets.length > AppConstants.maxTicketsPerPurchase) {
      TelemetryTracker().recordError(
        'Tickets',
        'Límite Excedido Cupón',
        'El canje de cupón excede el límite máximo de ${AppConstants.maxTicketsPerPurchase} entradas',
      );
      return;
    }
    _redeemedTickets.addAll(tickets);
    notifyListeners();
  }

  void removeRedeemedTicket(String ticketId) {
    _redeemedTickets.removeWhere((t) => t.id == ticketId);
    notifyListeners();
  }

  void startTimer({int initialSeconds = AppConstants.sessionDurationSeconds}) {
    _sessionTimer?.cancel();
    _remainingSeconds = initialSeconds;
    _isTimerRunning = true;
    _isSessionExpired = false;

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _isSessionExpired = true;
        _isTimerRunning = false;
        timer.cancel();
        TelemetryTracker().recordError(
          'SessionTimer',
          'Timeout',
          'El tiempo límite de compra ha expirado',
        );
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void stopTimer() {
    _sessionTimer?.cancel();
    _isTimerRunning = false;
    notifyListeners();
  }

  void resetSession() {
    stopTimer();
    _selectedMovie = null;
    _selectedShowtime = null;
    _ticketQuantities.clear();
    _redeemedTickets.clear();
    _remainingSeconds = AppConstants.sessionDurationSeconds;
    _isSessionExpired = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
