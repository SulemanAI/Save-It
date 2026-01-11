// This is a basic Flutter widget test for the SaveIt app.

import 'package:flutter_test/flutter_test.dart';
import 'package:save_it/main.dart';

void main() {
  testWidgets('SaveIt app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SaveItApp());
    
    // Verify that the app title is displayed
    expect(find.text('SaveIt'), findsOneWidget);
    
    // Verify that the paste button is present
    expect(find.text('Paste'), findsOneWidget);
  });
}
