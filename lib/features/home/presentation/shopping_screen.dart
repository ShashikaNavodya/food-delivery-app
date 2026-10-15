import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../application/food_app_controller.dart';
import '../models/delivery_address.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({
    required this.controller,
    required this.onCheckout,
    required this.onAddressTap,
    super.key,
  });

  final FoodAppController controller;
  final VoidCallback onCheckout;
  final Future<DeliveryAddress?> Function({bool selectionMode}) onAddressTap;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final restaurant = controller.cartRestaurant;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final deliveryFee = restaurant?.deliveryFee ?? 0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: controller.cart.isEmpty
                ? const _EmptyCart()
                : CustomScrollView(
                    key: const PageStorageKey('cart-scroll'),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(22, 25, 22, 25),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Text('Your bag', style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 7),
                            Text(
                              restaurant?.name ?? '',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            for (final entry in controller.cart.values)
                              _CartItem(
                                entry: entry,
                                onChange: (delta) =>
                                    controller.changeQuantity(entry.item.id, delta),
                              ),
                            const SizedBox(height: 12),
                            SectionTitle(
                              title: 'Delivery address',
                              actionLabel: controller.selectedAddress == null
                                  ? 'Add'
                                  : 'Change',
                              onAction: () => widget.onAddressTap(
                                selectionMode: true,
                              ),
                            ),
                            const SizedBox(height: 7),
                            _DeliveryAddressCard(
                              label: controller.selectedAddress?.label ??
                                  (controller.isSignedIn ? 'Add an address' : 'Sign in required'),
                              address: controller.selectedAddress?.address ??
                                  'Sign in to save your delivery address.',
                              onTap: () => widget.onAddressTap(
                                selectionMode: true,
                              ),
                            ),
                            const SizedBox(height: 23),
                            const SectionTitle(title: 'Bill details'),
                            const SizedBox(height: 14),
                            _BillRow(label: 'Subtotal', value: formatMoney(controller.subtotal)),
                            const SizedBox(height: 9),
                            _BillRow(label: 'Delivery fee', value: formatMoney(deliveryFee)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(height: 1),
                            ),
                            _BillRow(
                              label: 'Total',
                              value: formatMoney(controller.subtotal + deliveryFee),
                              isTotal: true,
                            ),
                            const SizedBox(height: 19),
                            PrimaryButton(
                              label: 'Continue to payment  ·  ${formatMoney(controller.subtotal + deliveryFee)}',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: controller.isPlacingOrder,
                              onPressed: controller.isPlacingOrder
                                  ? null
                                  : widget.onCheckout,
                            ),
                            const SizedBox(height: 9),
                            Center(
                              child: Text(
                                controller.isSignedIn
                                    ? 'Encrypted checkout  ·  Cash or card'
                                    : 'Sign in to continue  ·  Your bag will stay here',
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

}

class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({
    required this.label,
    required this.address,
    required this.onTap,
  });

  final String label;
  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(address, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  const _CartItem({required this.entry, required this.onChange});

  final CartEntry entry;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: FoodImage(
              url: entry.item.imageUrl,
              height: 76,
              borderRadius: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.item.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(formatMoney(entry.item.price), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _QuantityStepper(quantity: entry.quantity, onChange: onChange),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChange});

  final int quantity;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EC),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 36),
            onPressed: () => onChange(-1),
            icon: const Icon(Icons.remove_rounded, size: 16, color: AppTheme.primary),
          ),
          Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 36),
            onPressed: () => onChange(1),
            icon: const Icon(Icons.add_rounded, size: 16, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.label, required this.value, this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isTotal ? 16 : 13,
      fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
      color: isTotal ? AppTheme.ink : AppTheme.muted,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F2E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: AppTheme.primary, size: 43),
          ),
          const SizedBox(height: 22),
          Text('Your bag is taking a break', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Add something delicious from a nearby restaurant and it will show up here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
