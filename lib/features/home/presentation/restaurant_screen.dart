import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../application/food_app_controller.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({
    required this.restaurant,
    required this.controller,
    super.key,
  });

  final Restaurant restaurant;
  final FoodAppController controller;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  late Future<List<MenuItem>> _menuFuture;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _menuFuture = widget.controller.loadMenu(widget.restaurant.id);
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 255,
              pinned: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.all(7),
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodImage(
                      url: restaurant.imageUrl,
                      height: 255,
                      borderRadius: 0,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x77000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      bottom: 20,
                      child: _Badge(label: restaurant.isFeatured ? 'LOCAL FAVOURITE' : 'OPEN NOW'),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton.filledTonal(
                  onPressed: () => setState(() => _isFavorite = !_isFavorite),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                  ),
                  icon: Icon(
                    _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFavorite ? AppTheme.primary : AppTheme.ink,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    restaurant.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(restaurant.cuisine, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF2B442)),
                      const SizedBox(width: 4),
                      Text(
                        '${restaurant.rating.toStringAsFixed(1)} rating',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const _Dot(),
                      const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.muted),
                      const SizedBox(width: 4),
                      Text('${restaurant.deliveryMinutes} min', style: Theme.of(context).textTheme.bodySmall),
                      const _Dot(),
                      Text(
                        '${formatMoney(restaurant.deliveryFee)} delivery',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 27),
                  const SectionTitle(title: 'Our menu'),
                  const SizedBox(height: 5),
                  FutureBuilder<List<MenuItem>>(
                    future: _menuFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _MenuError(
                          message: snapshot.error.toString(),
                          onRetry: () => setState(
                            () => _menuFuture =
                                widget.controller.loadMenu(restaurant.id),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Column(
                        children: [
                          for (final item in snapshot.data!)
                            _MenuItemCard(
                              item: item,
                              onAdd: () {
                                final added = widget.controller.addToCart(item);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      added
                                          ? '${item.name} added to your bag'
                                          : 'Your bag has items from another restaurant. Finish or clear that order first.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.controller.cartRestaurant?.id == restaurant.id
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: PrimaryButton(
                  label:
                      'View bag  ·  ${widget.controller.cartCount} items  ·  ${formatMoney(widget.controller.subtotal)}',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Open your Cart from the bottom navigation.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              )
            : null,
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item, required this.onAdd});

  final MenuItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Stack(
              children: [
                FoodImage(url: item.imageUrl, height: 104, borderRadius: 15),
                if (item.isPopular)
                  const Positioned(
                    left: 5,
                    top: 5,
                    child: _Badge(label: 'POPULAR', compact: true),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: SizedBox(
              height: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        formatMoney(item.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 32,
                        width: 35,
                        child: IconButton.filled(
                          padding: EdgeInsets.zero,
                          onPressed: onAdd,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFE6F2E8),
                            foregroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 7 : 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Container(
        height: 4,
        width: 4,
        decoration: const BoxDecoration(
          color: AppTheme.muted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MenuError extends StatelessWidget {
  const _MenuError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(message),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
