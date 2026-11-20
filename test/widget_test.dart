
import 'package:flutter_test/flutter_test.dart';
import 'package:apps_placeholder/features/onboarding/onboarding_screen.dart';
import 'package:material_ui/material_ui.dart';
void main() {
  testWidgets('PocketPace onboarding screen loads', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onComplete: (profile) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to PocketPace'), findsOneWidget);
    expect(find.text('Choose your base currency'), findsOneWidget);
    expect(find.text('Monthly income'), findsOneWidget);
    expect(find.text('Create my budget'), findsOneWidget);
  });
}
