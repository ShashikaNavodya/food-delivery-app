import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../orders/models/food_order.dart';
import '../data/food_repository.dart';
import '../models/customer.dart';
import '../models/delivery_address.dart';
import '../models/menu_item.dart';
import '../models/payment_authorization.dart';
import '../models/restaurant.dart';

class CartEntry {
  const CartEntry({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

  CartEntry withQuantity(int value) => CartEntry(item: item, quantity: value);
}

class FoodAppController extends ChangeNotifier {
  FoodAppController(this._repository);

  final FoodRepository _repository;
  static const _secureStorage = FlutterSecureStorage();
  List<Restaurant> restaurants = const [];
  List<FoodOrder> orders = const [];
  List<DeliveryAddress> addresses = const [];
  final Map<int, CartEntry> cart = {};
  Customer? currentUser;
  int? selectedAddressId;
  bool isLoadingRestaurants = true;
  bool isLoadingOrders = false;
  bool isPlacingOrder = false;
  bool isInitializingSession = true;
  String? restaurantError;
  String? ordersError;
  String? addressError;

  int get cartCount => cart.values.fold(0, (sum, entry) => sum + entry.quantity);
  bool get isSignedIn => currentUser != null;
  DeliveryAddress? get selectedAddress {
    for (final address in addresses) {
      if (address.id == selectedAddressId) return address;
    }
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  double get subtotal => cart.values.fold(
        0,
        (sum, entry) => sum + entry.item.price * entry.quantity,
      );

  Restaurant? get cartRestaurant {
    if (cart.isEmpty) return null;
    final restaurantId = cart.values.first.item.restaurantId;
    for (final restaurant in restaurants) {
      if (restaurant.id == restaurantId) return restaurant;
    }
    return null;
  }

  Future<void> loadRestaurants({String? search}) async {
    isLoadingRestaurants = true;
    restaurantError = null;
    notifyListeners();
    try {
      restaurants = await _repository.getRestaurants(search: search);
    } catch (error) {
      restaurantError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingRestaurants = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    final token = await _secureStorage.read(key: 'savor.authToken');
    if (token != null) {
      _repository.setAuthToken(token);
      try {
        currentUser = await _repository.getCurrentUser();
        await loadAddresses();
      } catch (error) {
        if (error is ApiException && error.statusCode == 401) {
          await _secureStorage.delete(key: 'savor.authToken');
          _repository.setAuthToken(null);
        } else {
          addressError = error.toString();
        }
      }
    }
    isInitializingSession = false;
    notifyListeners();
    await Future.wait([loadRestaurants(), if (isSignedIn) loadOrders()]);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await _repository.register(
      name: name,
      email: email,
      password: password,
    );
    await _saveSession(session.token, session.customer);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final session = await _repository.login(email: email, password: password);
    await _saveSession(session.token, session.customer);
  }

  Future<void> _saveSession(String token, Customer customer) async {
    _repository.setAuthToken(token);
    await _secureStorage.write(key: 'savor.authToken', value: token);
    currentUser = customer;
    ordersError = null;
    notifyListeners();
    await Future.wait([loadAddresses(), loadOrders()]);
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      _repository.setAuthToken(null);
      await _secureStorage.delete(key: 'savor.authToken');
      currentUser = null;
      addresses = const [];
      orders = const [];
      selectedAddressId = null;
      notifyListeners();
    }
  }

  Future<void> loadAddresses() async {
    addressError = null;
    try {
      addresses = await _repository.getAddresses();
      selectedAddressId = selectedAddress?.id;
    } catch (error) {
      addressError = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> addAddress({
    required String label,
    required String address,
    bool makeDefault = false,
  }) async {
    final saved = await _repository.addAddress(
      label: label,
      address: address,
      isDefault: addresses.isEmpty || makeDefault,
    );
    addresses = [
      if (saved.isDefault) ...[
        for (final current in addresses)
          DeliveryAddress(
            id: current.id,
            label: current.label,
            address: current.address,
            isDefault: false,
          ),
      ] else ...addresses,
      saved,
    ];
    if (saved.isDefault) selectedAddressId = saved.id;
    notifyListeners();
  }

  Future<void> selectAddress(int id) async {
    await _repository.setDefaultAddress(id);
    selectedAddressId = id;
    addresses = [
      for (final address in addresses)
        DeliveryAddress(
          id: address.id,
          label: address.label,
          address: address.address,
          isDefault: address.id == id,
        ),
    ];
    notifyListeners();
  }

  Future<void> updateAddress({
    required int id,
    required String label,
    required String address,
  }) async {
    final updated = await _repository.updateAddress(
      id: id,
      label: label,
      address: address,
    );
    addresses = [
      for (final current in addresses)
        current.id == id
            ? DeliveryAddress(
                id: updated.id,
                label: updated.label,
                address: updated.address,
                isDefault: current.isDefault,
              )
            : current,
    ];
    notifyListeners();
  }

  Future<List<MenuItem>> loadMenu(int restaurantId) {
    return _repository.getMenu(restaurantId);
  }

  bool addToCart(MenuItem item) {
    if (cart.isNotEmpty &&
        cart.values.first.item.restaurantId != item.restaurantId) {
      return false;
    }
    final current = cart[item.id];
    cart[item.id] = CartEntry(item: item, quantity: (current?.quantity ?? 0) + 1);
    notifyListeners();
    return true;
  }

  void changeQuantity(int itemId, int delta) {
    final entry = cart[itemId];
    if (entry == null) return;
    final quantity = entry.quantity + delta;
    if (quantity <= 0) {
      cart.remove(itemId);
    } else {
      cart[itemId] = entry.withQuantity(quantity);
    }
    notifyListeners();
  }

  Future<PaymentAuthorization> authorizeCard(String lastFour) {
    return _repository.authorizeCard(
      lastFour: lastFour,
      items: [
        for (final entry in cart.values)
          (itemId: entry.item.id, quantity: entry.quantity),
      ],
    );
  }

  Future<FoodOrder> placeOrder({
    required String address,
    required String paymentMethod,
    int? paymentId,
  }) async {
    if (cart.isEmpty) throw StateError('Add something delicious to your cart first.');
    if (address.trim().length < 5) {
      throw ArgumentError('Please enter a delivery address.');
    }
    if (!isSignedIn) throw StateError('Sign in to place your order.');
    isPlacingOrder = true;
    notifyListeners();
    try {
      final order = await _repository.createOrder(
        address: address.trim(),
        items: [
          for (final entry in cart.values)
            (itemId: entry.item.id, quantity: entry.quantity),
        ],
        paymentMethod: paymentMethod,
        paymentId: paymentId,
      );
      cart.clear();
      await loadOrders();
      return order;
    } finally {
      isPlacingOrder = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders() async {
    if (!isSignedIn) {
      orders = const [];
      return;
    }
    isLoadingOrders = true;
    ordersError = null;
    notifyListeners();
    try {
      orders = await _repository.getOrders();
    } catch (error) {
      ordersError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingOrders = false;
      notifyListeners();
    }
  }

  void disposeRepository() => _repository.dispose();
}
