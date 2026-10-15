String formatMoney(double amount) {
  final wholeAmount = amount.round();
  final digits = wholeAmount.toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'Rs. $grouped';
}
