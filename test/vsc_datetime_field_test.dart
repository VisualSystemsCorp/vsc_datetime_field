import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsc_datetime_field/datetime_parser.dart';

import 'package:vsc_datetime_field/vsc_datetime_field.dart';

const label = 'label';
final fieldFinder = find.byType(VscDatetimeField);
final calPickerFinder = find.byType(CalendarDatePicker);
final labelFinder =
    find.descendant(of: fieldFinder, matching: find.text(label));
final dateIconFinder = find.descendant(
    of: fieldFinder, matching: find.byIcon(Icons.event_outlined));
final clearIconFinder = find.descendant(
    of: fieldFinder, matching: find.byIcon(Icons.clear_outlined));
final textFieldFinder =
    find.descendant(of: fieldFinder, matching: find.byType(TextField));
final focusButtonKey = UniqueKey();
final focusButtonFinder = find.byKey(focusButtonKey);
final fixedTime = DateTime.parse('2023-10-06T16:15:14.123');

void main() {
  // TODO -
  //  - '1/2' reformats 1/2/<current year>
  //  - Other short-cut date/time entries - note that datetime_parser handles all those details and is tested separately
  //  - Tapping date in the calendar
  // TODO Test controller values. onValueChanged
  //
  testableNow = () => fixedTime;
  group('date-only mode', () => dateOnlyGroupTests());
}

void dateOnlyGroupTests() {
  testWidgets('displays properly - no error', (tester) async {
    await tester.pumpDateOnlyField();

    expect(labelFinder, findsOneWidget);
    expect(dateIconFinder, findsOneWidget);
    expect(clearIconFinder, findsNothing);
    expect(calPickerFinder, findsNothing);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/date_only_pre_focus.png'));

    await tester.showKeyboard(fieldFinder); // Focuses
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Calendar picker should be up now and defaulted to the "current" date
    expect(calPickerFinder, findsOneWidget);
    expect(
        find.descendant(
            of: calPickerFinder, matching: find.text('October 2023')),
        findsOneWidget);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/date_only_post_focus.png'));

    await tester.enterText(fieldFinder, '1/2/22');
    await tester.pumpAndSettle();

    expect(dateIconFinder, findsNothing);
    expect(clearIconFinder, findsOneWidget);
    expect(calPickerFinder, findsOneWidget);
    expect(
        find.descendant(
            of: calPickerFinder, matching: find.text('January 2022')),
        findsOneWidget);

    // Before losing focus, the text should be correct with no error
    expect(tester.getTextField().controller!.text, '1/2/22');
    expect(tester.getTextField().decoration!.errorText, null);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/date_only_after_entry.png'));

    // After focusing out of field, value is reformatted.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(calPickerFinder, findsNothing);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/date_only_after_entry_and_tab_to_icon.png'));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
            'goldens/date_only_after_entry_and_loss_of_focus.png'));

    expect(tester.getTextField().controller!.text, '1/2/2022');
    expect(tester.getTextField().decoration!.errorText, null);

    // Clearing the field with the clear icon should wipe out the text.
    await tester.tap(clearIconFinder);
    await tester.pumpAndSettle();

    expect(dateIconFinder, findsOneWidget);
    expect(clearIconFinder, findsNothing);
    expect(tester.getTextField().controller!.text, '');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('date filling in year', (tester) async {
    await tester.pumpDateOnlyField();

    await tester.enterText(fieldFinder, '1/2');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(tester.getTextField().controller!.text, '1/2/2023');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('date beyond maxValue', (tester) async {
    await tester.pumpDateOnlyField();

    await tester.enterText(fieldFinder, '1/2/29');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText,
        'Must be on or before 12/15/2025');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '1/2/25');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('date before minValue', (tester) async {
    await tester.pumpDateOnlyField();

    expect(labelFinder, findsOneWidget);
    expect(dateIconFinder, findsOneWidget);

    await tester.enterText(fieldFinder, '2/14/20');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText,
        'Must be on or after 2/15/2020');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '1/2/25');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('date invalid', (tester) async {
    await tester.pumpDateOnlyField();

    expect(labelFinder, findsOneWidget);
    expect(dateIconFinder, findsOneWidget);

    await tester.enterText(fieldFinder, '1/32');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, 'Invalid value');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '1/2/25');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });
}

extension MoreWidgetTester on WidgetTester {
  TextField getTextField() => widget(textFieldFinder);

  Future<void> pumpDateOnlyField() async {
    await pumpWidgetWithHarness(VscDatetimeField(
      type: VscDatetimeFieldType.date,
      // valueController: _valueController,
      textFieldConfiguration: const TextFieldConfiguration(
          decoration: InputDecoration(
        label: Text(label),
      )),
      onValueChanged: (value) {},
      minValue: DateTime.parse('2020-02-15'),
      maxValue: DateTime.parse('2025-12-15'),
    ));
  }

  Future<void> pumpWidgetWithHarness(Widget child) async {
    await pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              // A button to test focus
              ElevatedButton(
                  key: focusButtonKey,
                  onPressed: () {},
                  child: const Text('Focus here')),
            ],
          ),
        ),
      ),
    );
    await pumpAndSettle();
  }
}
