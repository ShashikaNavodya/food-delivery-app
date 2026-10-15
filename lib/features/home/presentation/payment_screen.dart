import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../orders/models/food_order.dart';
import '../application/food_app_controller.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    required this.controller,
    required this.onManageAddresses,
    super.key,
  });

  final FoodAppController controller;
  final VoidCallback onManageAddresses;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _PaymentMethod { cash, card }

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _securityCode = TextEditingController();
  _PaymentMethod _method = _PaymentMethod.cash;
  bool _isSubmitting = false;
  FoodOrder? _completedOrder;
  String? _failureMessage;

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _securityCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _completedOrder != null) return;
    if (_method == _PaymentMethod.card &&
        !_formKey.currentState!.validate()) {
      return;
    }
    final address = widget.controller.selectedAddress?.address;
    if (address == null) {
      setState(() => _failureMessage = 'Choose a saved delivery address before placing your order.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _failureMessage = null;
    });
    try {
      final paymentId = _method == _PaymentMethod.card
          ? (await widget.controller.authorizeCard(
              _cardNumber.text.replaceAll(RegExp(r'\D'), '').substring(
                    _cardNumber.text.replaceAll(RegExp(r'\D'), '').length - 4,
                  ),
            ))
              .paymentId
          : null;
      final order = await widget.controller.placeOrder(
        address: address,
        paymentMethod: _method == _PaymentMethod.card ? 'card' : 'cash',
        paymentId: paymentId,
      );
      if (mounted) setState(() => _completedOrder = order);
    } catch (error) {
      if (mounted) {
        setState(() {
          _failureMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _trackOrder() {
    final order = _completedOrder;
    if (order != null) Navigator.of(context).pop(order);
  }

  @override
  Widget build(BuildContext context) {
    if (_completedOrder case final order?) {
      return _CheckoutResultScreen(
        order: order,
        onDone: _trackOrder,
      );
    }
    final controller = widget.controller;
    final restaurant = controller.cartRestaurant;
    final total = controller.subtotal + (restaurant?.deliveryFee ?? 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Secure checkout')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _CheckoutHero(total: total),
              const SizedBox(height: 21),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delivery location',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onManageAddresses,
                    child: const Text('Change'),
                  ),
                ],
              ),
              _DeliverySummary(
                name: controller.selectedAddress?.label ?? 'No address selected',
                address: controller.selectedAddress?.address ?? '',
              ),
              const SizedBox(height: 22),
              const SectionTitle(title: 'How would you like to pay?'),
              const SizedBox(height: 10),
              _PaymentOption(
                icon: Icons.payments_outlined,
                title: 'Cash on delivery',
                description: 'Pay when your food arrives',
                selected: _method == _PaymentMethod.cash,
                onTap: () => setState(() {
                  _method = _PaymentMethod.cash;
                  _failureMessage = null;
                }),
              ),
              const SizedBox(height: 10),
              _PaymentOption(
                icon: Icons.credit_card_rounded,
                title: 'Credit or debit card',
                description: 'Secure demo payment',
                selected: _method == _PaymentMethod.card,
                onTap: () => setState(() {
                  _method = _PaymentMethod.card;
                  _failureMessage = null;
                }),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                child: _method == _PaymentMethod.card
                    ? _CardForm(
                        formKey: _formKey,
                        number: _cardNumber,
                        expiry: _expiry,
                        securityCode: _securityCode,
                      )
                    : const SizedBox.shrink(),
              ),
              if (_failureMessage != null) ...[
                const SizedBox(height: 14),
                _PaymentFailure(message: _failureMessage!),
                const SizedBox(height: 9),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _method = _PaymentMethod.cash;
                    _failureMessage = null;
                  }),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Try cash on delivery instead'),
                ),
              ],
              const SizedBox(height: 22),
              const SectionTitle(title: 'Your order'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Column(
                  children: [
                    for (final entry in controller.cart.values) ...[
                      _PriceRow(
                        label: '${entry.quantity} × ${entry.item.name}',
                        value: formatMoney(entry.item.price * entry.quantity),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _PriceRow(
                      label: 'Delivery fee',
                      value: formatMoney(restaurant?.deliveryFee ?? 0),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Divider(height: 1),
                    ),
                    _PriceRow(
                      label: 'Total',
                      value: formatMoney(total),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: _method == _PaymentMethod.card
                    ? 'Pay ${formatMoney(total)}'
                    : 'Confirm order  ·  ${formatMoney(total)}',
                icon: Icons.lock_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
              const SizedBox(height: 10),
              const Text(
                'Demo checkout only. No real charge is made and complete card details are never sent or saved.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 10, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutHero extends StatelessWidget {
  const _CheckoutHero({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      padding: const EdgeInsets.all(19),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B503A), Color(0xFF73936D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -24,
            child: Icon(
              Icons.local_dining_rounded,
              color: Colors.white.withValues(alpha: 0.13),
              size: 160,
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Almost there.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Fresh food, headed your way.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverySummary extends StatelessWidget {
  const _DeliverySummary({required this.name, required this.address});

  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE6F2E8),
            child: Icon(Icons.location_on_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(address, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF0F8F1) : Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppTheme.primary : AppTheme.muted),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(description, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppTheme.primary : AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardForm extends StatelessWidget {
  const _CardForm({
    required this.formKey,
    required this.number,
    required this.expiry,
    required this.securityCode,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController number;
  final TextEditingController expiry;
  final TextEditingController securityCode;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            TextFormField(
              controller: number,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
              ],
              decoration: const InputDecoration(
                labelText: 'Card number',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
              validator: (value) {
                final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                return digits.length < 12 ? 'Enter a valid card number' : null;
              },
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: expiry,
                    keyboardType: TextInputType.datetime,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Expiry',
                      hintText: 'MM/YY',
                    ),
                    validator: (value) =>
                        value != null && RegExp(r'^\d{2}/\d{2}$').hasMatch(value)
                            ? null
                            : 'Use MM/YY',
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: TextFormField(
                    controller: securityCode,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(labelText: 'Security code'),
                    validator: (value) =>
                        (value?.length ?? 0) < 3 ? 'Enter the card code' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            const _DemoCardHint(),
          ],
        ),
      ),
    );
  }
}

class _DemoCardHint extends StatelessWidget {
  const _DemoCardHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Demo success: any valid number  ·  Demo decline: end the number with 0002',
        style: TextStyle(color: AppTheme.muted, fontSize: 10, height: 1.35),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: bold ? AppTheme.ink : AppTheme.muted,
      fontSize: bold ? 15 : 12,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _PaymentFailure extends StatelessWidget {
  const _PaymentFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFEC),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB94B3C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9D3F34),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutResultScreen extends StatelessWidget {
  const _CheckoutResultScreen({required this.order, required this.onDone});

  final FoodOrder order;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.55, end: 1),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    height: 112,
                    width: 112,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF4ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF3F7954),
                      size: 57,
                    ),
                  ),
                ),
                const SizedBox(height: 27),
                Text(
                  'It\'s official!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Order #${order.id} from ${order.restaurantName} is confirmed. The kitchen is getting started.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Column(
                    children: [
                      _PriceRow(label: 'Order total', value: formatMoney(order.total), bold: true),
                      const SizedBox(height: 11),
                      _PriceRow(
                        label: 'Payment',
                        value: order.paymentMethod == 'card'
                            ? 'Card · ${order.paymentStatus}'
                            : 'Cash on delivery',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Track my order',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
