import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsc_datetime_field/vsc_datetime_field.dart';

void main() {
  group('VscDatetimeField error handling', () {
    testWidgets('handles error widget in decoration without assertion error',
        (WidgetTester tester) async {
      // Build a VscDatetimeField with an error widget in the decoration
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VscDatetimeField(
              textFieldConfiguration: const TextFieldConfiguration(
                decoration: InputDecoration(
                  labelText: 'Test Field',
                  // This simulates what UiEditorDatetimeField does
                  error: Text('External validation error'),
                  errorMaxLines: 3,
                ),
              ),
            ),
          ),
        ),
      );

      // The widget should build without throwing an assertion error
      expect(find.byType(VscDatetimeField), findsOneWidget);
      expect(find.text('External validation error'), findsOneWidget);

      // Now trigger an internal error by typing invalid date
      await tester.enterText(find.byType(TextField), '5/3/');
      await tester.pump();

      // Should still show only the external error widget, not internal errorText
      expect(find.text('External validation error'), findsOneWidget);
      expect(find.text('Invalid value'), findsNothing);
    });

    testWidgets('shows internal error when no external error widget exists',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VscDatetimeField(
              textFieldConfiguration: const TextFieldConfiguration(
                decoration: InputDecoration(
                  labelText: 'Test Field',
                  // No error widget provided
                ),
              ),
            ),
          ),
        ),
      );

      // Enter invalid date
      await tester.enterText(find.byType(TextField), '5/3/');
      await tester.pump();

      // Should show the internal error text
      expect(find.text('Invalid value'), findsOneWidget);
    });

    testWidgets('respects existing errorText when no internal error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VscDatetimeField(
              textFieldConfiguration: const TextFieldConfiguration(
                decoration: InputDecoration(
                  labelText: 'Test Field',
                  errorText: 'Pre-existing error text',
                ),
              ),
            ),
          ),
        ),
      );

      // Should show the pre-existing error text
      expect(find.text('Pre-existing error text'), findsOneWidget);
    });
  });
}
