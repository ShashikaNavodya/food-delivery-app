class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.imageUrl,
    required this.rating,
    required this.deliveryMinutes,
    required this.deliveryFee,
    required this.isFeatured,
  });

  final int id;
  final String name;
  final String cuisine;
  final String imageUrl;
  final double rating;
  final int deliveryMinutes;
  final double deliveryFee;
  final bool isFeatured;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      cuisine: json['cuisine'] as String,
      imageUrl: json['imageUrl'] as String,
      rating: (json['rating'] as num).toDouble(),
      deliveryMinutes: json['deliveryMinutes'] as int,
      deliveryFee: (json['deliveryFee'] as num).toDouble(),
      isFeatured: json['isFeatured'] as bool,
    );
  }
}
