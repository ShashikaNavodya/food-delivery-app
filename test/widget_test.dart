import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savor_food/core/utils/formatters.dart';
import 'package:savor_food/core/widgets/primary_button.dart';
import 'package:savor_food/features/home/presentation/splash_screen.dart';

void main() {
  test('formats Sri Lankan rupee amounts with grouped thousands', () {
    expect(formatMoney(1650), 'Rs. 1,650');
    expect(formatMoney(0), 'Rs. 0');
  });

  testWidgets('primary button calls its action', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Place order',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Place order'));
    expect(pressed, isTrue);
  });

  testWidgets('splash screen shows the Savor logo on a white background', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Savor'), findsOneWidget);
    expect(find.text('GOOD FOOD, DELIVERED.'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
