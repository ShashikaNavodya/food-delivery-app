class FoodOrder {
  const FoodOrder({
    required this.id,
    required this.restaurantName,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.itemCount,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  final int id;
  final String restaurantName;
  final double total;
  final String status;
  final String createdAt;
  final int itemCount;
  final String paymentMethod;
  final String paymentStatus;

  factory FoodOrder.fromJson(Map<String, dynamic> json) {
    return FoodOrder(
      id: json['id'] as int,
      restaurantName: json['restaurantName'] as String,
      total: (json['total'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
      itemCount: json['itemCount'] as int,
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
    );
  }
}
