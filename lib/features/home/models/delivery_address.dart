class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.isDefault,
  });

  final int id;
  final String label;
  final String address;
  final bool isDefault;

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] as int,
      label: json['label'] as String,
      address: json['address'] as String,
      isDefault: json['isDefault'] as bool,
    );
  }
}
