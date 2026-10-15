import 'package:flutter/material.dart';

class FoodImage extends StatelessWidget {
  const FoodImage({
    required this.url,
    required this.height,
    this.borderRadius = 18,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String url;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return Container(
            height: height,
            color: const Color(0xFFDCECDD),
            alignment: Alignment.center,
            child: const Icon(
              Icons.restaurant_menu_rounded,
              size: 34,
              color: Color(0xFF15985B),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          color: const Color(0xFFDCECDD),
          alignment: Alignment.center,
          child: const Icon(
            Icons.restaurant_menu_rounded,
            size: 34,
            color: Color(0xFF15985B),
          ),
        ),
      ),
    );
  }
}
