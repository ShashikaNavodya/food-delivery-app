import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/food_image.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../orders/models/food_order.dart';
import '../../orders/presentation/orders_screen.dart';
import '../application/food_app_controller.dart';
import '../data/food_repository.dart';
import '../models/delivery_address.dart';
import '../models/restaurant.dart';
import 'address_book_screen.dart';
import 'auth_screen.dart';
import 'payment_screen.dart';
import 'restaurant_screen.dart';
import 'shopping_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({this.controller, super.key});

  final FoodAppController? controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FoodAppController _controller;
  late final bool _ownsController;
  int _selectedTab = 0;
  String _category = 'Nearby';
  Timer? _searchDebounce;

  static const _categories = [
    ('Nearby', Icons.map_rounded),
    ('Offers', Icons.local_offer_rounded),
    ('Groceries', Icons.shopping_basket_rounded),
    ('Dining Out', Icons.restaurant_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? FoodAppController(FoodRepository());
    if (_ownsController) _controller.initialize();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_ownsController) {
      _controller.disposeRepository();
      _controller.dispose();
    }
    super.dispose();
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _controller.loadRestaurants(search: value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pages = [
          _HomeTab(
            controller: _controller,
            category: _category,
            categories: _categories,
            onCategoryChanged: (value) => setState(() => _category = value),
            onSearch: _search,
            onRestaurantTap: _openRestaurant,
            onAddressTap: _manageAddresses,
            onCartTap: () => setState(() => _selectedTab = 1),
          ),
          ShoppingScreen(
            controller: _controller,
            onCheckout: _beginCheckout,
            onAddressTap: _manageAddresses,
          ),
          OrdersScreen(controller: _controller),
          _ProfileTab(
            controller: _controller,
            onSignIn: _openAuthentication,
            onManageAddresses: _manageAddresses,
            onSignOut: _signOut,
          ),
        ];
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(_selectedTab),
                child: pages[_selectedTab],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) {
              setState(() => _selectedTab = index);
              if (index == 2) _controller.loadOrders();
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: _CartNavIcon(count: _controller.cartCount),
                selectedIcon: _CartNavIcon(
                  count: _controller.cartCount,
                  active: true,
                ),
                label: 'Cart',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _openAuthentication() async {
    if (_controller.isSignedIn) return true;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AuthScreen(controller: _controller)),
    );
    return result == true;
  }

  Future<DeliveryAddress?> _manageAddresses({bool selectionMode = true}) async {
    if (!_controller.isSignedIn && !await _openAuthentication()) return null;
    if (!mounted) return null;
    return Navigator.of(context).push<DeliveryAddress>(
      MaterialPageRoute(
        builder: (_) => AddressBookScreen(
          controller: _controller,
          selectionMode: selectionMode,
        ),
      ),
    );
  }

  Future<void> _beginCheckout() async {
    if (_controller.cart.isEmpty) return;
    if (!_controller.isSignedIn && !await _openAuthentication()) return;
    if (_controller.selectedAddress == null) {
      final address = await _manageAddresses();
      if (!mounted || address == null) return;
    }
    if (!mounted) return;
    final order = await Navigator.of(context).push<FoodOrder>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          controller: _controller,
          onManageAddresses: () => _manageAddresses(selectionMode: true),
        ),
      ),
    );
    if (order != null && mounted) {
      setState(() => _selectedTab = 2);
      await _controller.loadOrders();
    }
  }

  Future<void> _signOut() async {
    try {
      await _controller.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have signed out. See you soon!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openRestaurant(Restaurant restaurant) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) =>
            RestaurantScreen(restaurant: restaurant, controller: _controller),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(slide),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.controller,
    required this.category,
    required this.categories,
    required this.onCategoryChanged,
    required this.onSearch,
    required this.onRestaurantTap,
    required this.onAddressTap,
    required this.onCartTap,
  });

  final FoodAppController controller;
  final String category;
  final List<(String, IconData)> categories;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearch;
  final ValueChanged<Restaurant> onRestaurantTap;
  final Future<DeliveryAddress?> Function({bool selectionMode}) onAddressTap;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    final restaurants = controller.restaurants.where((restaurant) {
      switch (category) {
        case 'Offers':
          return restaurant.isFeatured;
        case 'Groceries':
          return restaurant.cuisine.toLowerCase().contains('groceries');
        case 'Dining Out':
          return !restaurant.cuisine.toLowerCase().contains('groceries');
        default:
          return true;
      }
    }).toList();
    final featured = controller.restaurants
        .where(
          (item) =>
              item.isFeatured &&
              !item.cuisine.toLowerCase().contains('groceries'),
        )
        .toList();
    final shopHighlights = restaurants
        .where((item) => !item.isFeatured)
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: CustomScrollView(
          key: const PageStorageKey('home-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _LocationHeader(
                    address:
                        controller.selectedAddress?.address ?? 'Colombo 07',
                    onTap: () => onAddressTap(selectionMode: true),
                    name: controller.currentUser?.name,
                    cartCount: controller.cartCount,
                    onCartTap: onCartTap,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hello, ${controller.currentUser?.name.split(' ').first ?? 'there'}! 👋',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 25),
                  ),
                  const SizedBox(height: 14),
                  _SearchField(onChanged: onSearch),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final value = categories[index].$1;
                        final selected = category == value;
                        return _CategoryChip(
                          label: value,
                          icon: categories[index].$2,
                          selected: selected,
                          onTap: () => onCategoryChanged(value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _OfferBanner(onTap: () => onCategoryChanged('Nearby')),
                  const SizedBox(height: 22),
                  if (controller.isLoadingRestaurants) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  if (controller.restaurantError != null)
                    _ErrorPanel(
                      message: controller.restaurantError!,
                      onRetry: () => controller.loadRestaurants(),
                    ),
                  const SizedBox(height: 22),
                  if (featured.isNotEmpty && category != 'Groceries') ...[
                    const SectionTitle(title: 'Recommended for you'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: featured.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => SizedBox(
                          width: 164,
                          child: _FeaturedRestaurantCard(
                            restaurant: featured[index],
                            onTap: () => onRestaurantTap(featured[index]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (shopHighlights.isNotEmpty && category == 'Nearby') ...[
                    const SectionTitle(title: 'Featured restaurants'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: shopHighlights.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => SizedBox(
                          width: 164,
                          child: _FeaturedRestaurantCard(
                            restaurant: shopHighlights[index],
                            onTap: () => onRestaurantTap(shopHighlights[index]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  SectionTitle(
                    title: category == 'Nearby'
                        ? 'All shops near you'
                        : category,
                    actionLabel: '${restaurants.length} places',
                  ),
                  const SizedBox(height: 12),
                  if (restaurants.isEmpty && !controller.isLoadingRestaurants)
                    const _EmptyRestaurants()
                  else
                    for (final restaurant in restaurants)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _RestaurantListCard(
                          restaurant: restaurant,
                          onTap: () => onRestaurantTap(restaurant),
                        ),
                      ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({
    required this.address,
    required this.name,
    required this.cartCount,
    required this.onTap,
    required this.onCartTap,
  });

  final String address;
  final String? name;
  final int cartCount;
  final VoidCallback onTap;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.ramen_dining_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'SAVOR',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            IconButton.filledTonal(
              onPressed: onCartTap,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _CartNavIcon(count: cartCount),
            ),
            const SizedBox(width: 7),
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFDDEEE1),
              child: Text(
                name?.trim().isNotEmpty == true
                    ? name!.trim().substring(0, 1).toUpperCase()
                    : 'S',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppTheme.primary,
                size: 19,
              ),
              const SizedBox(width: 7),
              Text(
                'DELIVER TO',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 12),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'Search restaurants or dishes',
        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
        suffixIcon: Icon(Icons.tune_rounded, color: AppTheme.ink),
      ),
    );
  }
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF26392E),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          height: 150,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(19)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=1000&q=85',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xE6000000), Color(0x24000000)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 13, 16, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'FRESH PICKS NEAR YOU',
                      style: TextStyle(
                        color: Color(0xFFBCE5C5),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Craving Italian?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.local_pizza_rounded,
                          color: Color(0xFFFFB54A),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Wood-fired favourites, delivered fresh.',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Explore restaurants  →',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 78,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE4F2E7) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            bottom: BorderSide(
              color: selected ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primary : const Color(0xFF737A73),
              size: 22,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? AppTheme.primary : AppTheme.ink,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedRestaurantCard extends StatelessWidget {
  const _FeaturedRestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _AnimatedTapCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              FoodImage(url: restaurant.imageUrl, height: 98, borderRadius: 14),
              Positioned(
                top: 7,
                right: 7,
                child: _RatingPill(rating: restaurant.rating),
              ),
              Positioned(
                top: 7,
                left: 7,
                child: _InfoPill(
                  label: restaurant.isFeatured ? 'TOP PICK' : 'NEAR YOU',
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            restaurant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 13),
              const SizedBox(width: 2),
              Text(
                restaurant.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${restaurant.deliveryMinutes} min · ${formatMoney(restaurant.deliveryFee)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestaurantListCard extends StatelessWidget {
  const _RestaurantListCard({required this.restaurant, required this.onTap});

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _AnimatedTapCard(
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Image.network(
              restaurant.imageUrl,
              height: 104,
              width: 116,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 104,
                width: 116,
                color: const Color(0xFFE6F2E8),
                child: const Icon(Icons.restaurant, color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  restaurant.cuisine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Colors.amber.shade700,
                      size: 17,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      restaurant.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${restaurant.deliveryMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      restaurant.deliveryFee == 0
                          ? 'Free'
                          : formatMoney(restaurant.deliveryFee),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTapCard extends StatefulWidget {
  const _AnimatedTapCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_AnimatedTapCard> createState() => _AnimatedTapCardState();
}

class _AnimatedTapCardState extends State<_AnimatedTapCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return _InfoPill(
      label: '★ ${rating.toStringAsFixed(1)}',
      background: Colors.white,
      foreground: AppTheme.ink,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    this.background = AppTheme.primary,
    this.foreground = Colors.white,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRestaurants extends StatelessWidget {
  const _EmptyRestaurants();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 35),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: AppTheme.muted, size: 34),
          SizedBox(height: 8),
          Text('No restaurants found. Try another category.'),
        ],
      ),
    );
  }
}

class _CartNavIcon extends StatelessWidget {
  const _CartNavIcon({required this.count, this.active = false});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined),
        if (count > 0)
          Positioned(
            top: -8,
            right: -10,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.controller,
    required this.onSignIn,
    required this.onManageAddresses,
    required this.onSignOut,
  });

  final FoodAppController controller;
  final Future<bool> Function() onSignIn;
  final Future<DeliveryAddress?> Function({bool selectionMode})
  onManageAddresses;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      children: [
        Text('Your profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 7),
        Text(
          user == null
              ? 'Your little corner of Savor.'
              : 'Good to see you again.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF294D3A), Color(0xFF628768)],
            ),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  user?.name.characters.first.toUpperCase() ?? 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Welcome to Savor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Good food is better when shared.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (user == null)
                IconButton(
                  tooltip: 'Sign in',
                  onPressed: onSignIn,
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
            ],
          ),
        ),
        if (user == null) ...[
          const SizedBox(height: 15),
          PrimaryButton(
            label: 'Sign in or create account',
            icon: Icons.arrow_forward_rounded,
            onPressed: onSignIn,
          ),
        ],
        const SizedBox(height: 25),
        const SectionTitle(title: 'Your account'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
          ),
          child: Column(
            children: [
              ListTile(
                onTap: () => onManageAddresses(selectionMode: false),
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Delivery addresses'),
                subtitle: Text(
                  controller.selectedAddress?.address ??
                      'Add your favourite places',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              const Divider(height: 1, indent: 56),
              const ListTile(
                leading: Icon(Icons.favorite_border_rounded),
                title: Text('Your favourites'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
              const Divider(height: 1, indent: 56),
              const ListTile(
                leading: Icon(Icons.help_outline_rounded),
                title: Text('Help & support'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 17),
          SizedBox(
            height: 51,
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB5473A),
                side: const BorderSide(color: Color(0xFFF3D8D3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
            ),
          ),
        ],
        const SizedBox(height: 23),
        const Center(
          child: Text(
            'Made with care, delivered with Savor.',
            style: TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
