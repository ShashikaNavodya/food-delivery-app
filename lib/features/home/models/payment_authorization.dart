class PaymentAuthorization {
  const PaymentAuthorization({
    required this.paymentId,
    required this.amount,
    required this.status,
    required this.cardLastFour,
    required this.message,
  });

  final int paymentId;
  final double amount;
  final String status;
  final String cardLastFour;
  final String message;

  factory PaymentAuthorization.fromJson(Map<String, dynamic> json) {
    return PaymentAuthorization(
      paymentId: json['paymentId'] as int,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      cardLastFour: json['cardLastFour'] as String,
      message: json['message'] as String,
    );
  }
}
