import 'package:flutter/foundation.dart';
import 'models/completed_order_model.dart';

class PurchaseHistoryManager extends ChangeNotifier {
  static final PurchaseHistoryManager _instance =
      PurchaseHistoryManager._internal();
  factory PurchaseHistoryManager() => _instance;
  PurchaseHistoryManager._internal();

  final List<CompletedOrder> _orders = [];

  List<CompletedOrder> get orders => List.unmodifiable(_orders);

  List<CompletedOrder> get upcomingOrders =>
      _orders.where((o) => o.isUpcoming).toList();

  List<CompletedOrder> get pastOrders =>
      _orders.where((o) => !o.isUpcoming).toList();

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
