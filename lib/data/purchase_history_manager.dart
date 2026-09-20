import 'package:flutter/foundation.dart';
import 'models/completed_order_model.dart';

class PurchaseHistoryManager extends ChangeNotifier {
  static final PurchaseHistoryManager _instance =
      PurchaseHistoryManager._internal();
  factory PurchaseHistoryManager() => _instance;
  PurchaseHistoryManager._internal();

  final List<CompletedOrder> _orders = [];

  List<CompletedOrder> get orders => List.unmodifiable(_orders);

  List<CompletedOrder> get upcomingOrders {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _orders
        .where((o) => o.showtimeDate.isAfter(today) ||
            _isSameDay(o.showtimeDate, today))
        .toList()
      ..sort((a, b) => a.showtimeDate.compareTo(b.showtimeDate));
  }

  List<CompletedOrder> get pastOrders {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _orders.where((o) => o.showtimeDate.isBefore(today)).toList()
      ..sort((a, b) => b.showtimeDate.compareTo(a.showtimeDate));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  CompletedOrder? get nextUpcomingOrder {
    final upcoming = upcomingOrders;
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  void addOrder(CompletedOrder order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void clearHistory() {
    _orders.clear();
    notifyListeners();
  }
}
