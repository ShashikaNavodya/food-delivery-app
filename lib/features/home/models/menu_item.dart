class MenuItem {
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.category,
    required this.isPopular,
  });

  final int id;
  final int restaurantId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final String category;
  final bool isPopular;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as int,
      restaurantId: json['restaurantId'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      isPopular: json['isPopular'] as bool,
    );
  }
}
