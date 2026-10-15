import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../orders/models/food_order.dart';
import '../models/customer.dart';
import '../models/delivery_address.dart';
import '../models/menu_item.dart';
import '../models/payment_authorization.dart';
import '../models/restaurant.dart';

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class FoodRepository {
  FoodRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _baseUrl = ApiConfig.baseUrl;
  String? _authToken;

  void setAuthToken(String? token) => _authToken = token;

  Future<List<Restaurant>> getRestaurants({String? search}) async {
    final uri = Uri.parse('$_baseUrl/restaurants').replace(
      queryParameters: search == null || search.isEmpty ? null : {'search': search},
    );
    final response = await _client.get(uri);
    final data = _decode(response);
    return (data as List<dynamic>)
        .map((item) => Restaurant.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MenuItem>> getMenu(int restaurantId) async {
    final response =
        await _client.get(Uri.parse('$_baseUrl/restaurants/$restaurantId/menu'));
    final data = _decode(response);
    return (data as List<dynamic>)
        .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FoodOrder>> getOrders() async {
    final response = await _send('GET', '/orders');
    final data = _decode(response);
    return (data as List<dynamic>)
        .map((item) => FoodOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FoodOrder> createOrder({
    required List<({int itemId, int quantity})> items,
    required String address,
    required String paymentMethod,
    int? paymentId,
  }) async {
    final response = await _send(
      'POST',
      '/orders',
      body: {
        'address': address,
        'paymentMethod': paymentMethod,
        'paymentId': ?paymentId,
        'items': _jsonItems(items),
      },
    );
    return FoodOrder.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<({Customer customer, String token})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    final data = _decode(response) as Map<String, dynamic>;
    return (
      customer: Customer.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }

  Future<({Customer customer, String token})> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final data = _decode(response) as Map<String, dynamic>;
    return (
      customer: Customer.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }

  Future<Customer> getCurrentUser() async {
    final response = await _send('GET', '/auth/me');
    return Customer.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final response = await _send('POST', '/auth/logout');
    _decode(response);
  }

  Future<List<DeliveryAddress>> getAddresses() async {
    final response = await _send('GET', '/addresses');
    return (_decode(response) as List<dynamic>)
        .map((item) => DeliveryAddress.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DeliveryAddress> addAddress({
    required String label,
    required String address,
    required bool isDefault,
  }) async {
    final response = await _send(
      'POST',
      '/addresses',
      body: {'label': label, 'address': address, 'isDefault': isDefault},
    );
    return DeliveryAddress.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<DeliveryAddress> updateAddress({
    required int id,
    required String label,
    required String address,
  }) async {
    final response = await _send(
      'PATCH',
      '/addresses/$id',
      body: {'label': label, 'address': address},
    );
    return DeliveryAddress.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> setDefaultAddress(int id) async {
    final response = await _send('PUT', '/addresses/$id/default');
    _decode(response);
  }

  Future<PaymentAuthorization> authorizeCard({
    required List<({int itemId, int quantity})> items,
    required String lastFour,
  }) async {
    final response = await _send(
      'POST',
      '/payments/authorize',
      body: {
        'method': 'card',
        'lastFour': lastFour,
        'items': _jsonItems(items),
      },
    );
    return PaymentAuthorization.fromJson(
      _decode(response) as Map<String, dynamic>,
    );
  }

  List<Map<String, int>> _jsonItems(
    List<({int itemId, int quantity})> items,
  ) =>
      [
        for (final item in items)
          {'menuItemId': item.itemId, 'quantity': item.quantity},
      ];

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_authToken case final token?) {
      headers['Authorization'] = 'Bearer $token';
    }
    final uri = Uri.parse('$_baseUrl$path');
    final encodedBody = body == null ? null : jsonEncode(body);
    return switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encodedBody),
      'PUT' => _client.put(uri, headers: headers, body: encodedBody),
      'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported HTTP method'),
    };
  }

  dynamic _decode(http.Response response) {
    final dynamic body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map<String, dynamic>
          ? body['error'] as String? ??
              body['message'] as String? ??
              'The request could not be completed.'
          : 'The request could not be completed.';
      throw ApiException(message, response.statusCode);
    }
    return body;
  }

  void dispose() => _client.close();
}
