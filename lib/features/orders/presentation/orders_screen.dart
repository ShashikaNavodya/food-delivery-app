import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_title.dart';
import '../../home/application/food_app_controller.dart';
import '../models/food_order.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({required this.controller, super.key});

  final FoodAppController controller;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: controller.loadOrders,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 32),
            children: [
              Text('Your orders', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 7),
              Text(
                'Every good meal has a story.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Order history'),
              if (controller.isLoadingOrders)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.ordersError != null)
                _OrdersError(
                  message: controller.ordersError!,
                  onRetry: controller.loadOrders,
                )
              else if (controller.orders.isEmpty)
                const _NoOrders()
              else
                for (final order in controller.orders)
                  _OrderCard(order: order),
            ],
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final statusIndex = switch (order.status.toLowerCase()) {
      'preparing' => 1,
      'on the way' => 2,
      'delivered' => 3,
      _ => 0,
    };
    final date = DateTime.tryParse('${order.createdAt}Z')?.toLocal();
    final dateLabel = date == null
        ? 'Just now'
        : '${_month(date.month)} ${date.day} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.restaurant_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.restaurantName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Order #${order.id}  ·  $dateLabel', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                formatMoney(order.total),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              _StatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 18),
          _OrderProgress(currentStep: statusIndex),
        ],
      ),
    );
  }

  String _month(int value) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][value - 1];
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4ED),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFF3F7954),
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.currentStep});

  final int currentStep;
  static const _labels = ['Confirmed', 'Preparing', 'On the way', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _labels.length; index++) ...[
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: index <= currentStep ? AppTheme.primary : const Color(0xFFE4E5E0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _labels[index],
                style: TextStyle(
                  color: index <= currentStep ? AppTheme.ink : AppTheme.muted,
                  fontSize: 8,
                  fontWeight: index == currentStep ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
          if (index < _labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(left: 5, right: 5, bottom: 14),
                color: index < currentStep ? AppTheme.primary : const Color(0xFFE4E5E0),
              ),
            ),
        ],
      ],
    );
  }
}

class _NoOrders extends StatelessWidget {
  const _NoOrders();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Container(
            height: 91,
            width: 91,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F2E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 17),
          Text('No orders yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Your next favourite meal is just a few taps away.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
