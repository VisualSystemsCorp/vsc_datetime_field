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
final timeIconFinder = find.descendant(
    of: fieldFinder, matching: find.byIcon(Icons.access_time_outlined));
final clearIconFinder = find.descendant(
    of: fieldFinder, matching: find.byIcon(Icons.clear_outlined));
final textFieldFinder =
    find.descendant(of: fieldFinder, matching: find.byType(TextField));
final focusButtonKey = UniqueKey();
final focusButtonFinder = find.byKey(focusButtonKey);
final fixedTime = DateTime.parse('2023-10-06T16:15:14.123');
final valueController = ValueNotifier<DateTime?>(null);
final onValueChangedChanges = <DateTime?>[];

void main() {
  setUp(() {
    testableNow = () => fixedTime;
    valueController.value = null;
    onValueChangedChanges.clear();
  });

  group('date-only mode', () => dateOnlyGroupTests());
  group('datetime mode', () => datetimeGroupTests());
  group('time-only mode', () => timeGroupTests());
}

void dateOnlyGroupTests() {
  testWidgets('displays properly - no error, onValueChanged called',
      (tester) async {
    await tester.pumpDateOnlyField();

    expect(labelFinder, findsOneWidget);
    expect(dateIconFinder, findsOneWidget);
    expect(clearIconFinder, findsNothing);
    expect(calPickerFinder, findsNothing);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/date_only_pre_focus.png'));

    await tester.showKeyboard(fieldFinder); // Focuses
    await tester.pumpAndSettle();

    // Calendar picker should be up now and defaulted to the "current" date
    expect(calPickerFinder, findsOneWidget);
    expect(
        find.descendant(
            of: calPickerFinder, matching: find.text('October 2023')),
        findsOneWidget);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/date_only_post_focus.png'));

    expect(onValueChangedChanges, isEmpty);

    await tester.enterText(fieldFinder, '1/2/22');
    await tester.pumpAndSettle();

    expect(onValueChangedChanges, [DateTime.parse('2022-01-02')]);
    onValueChangedChanges.clear();
    expect(dateIconFinder, findsNothing);
    expect(clearIconFinder, findsOneWidget);
    expect(calPickerFinder, findsOneWidget);
    expect(
        find.descendant(
            of: calPickerFinder, matching: find.text('January 2022')),
        findsOneWidget);

    // Before losing focus, the text should be what we entered with no error
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

    expect(onValueChangedChanges, isEmpty);
    expect(tester.getTextField().controller!.text, '1/2/2022');
    expect(tester.getTextField().decoration!.errorText, null);

    // Clearing the field with the clear icon should wipe out the text.
    await tester.tap(clearIconFinder);
    await tester.pumpAndSettle();

    expect(onValueChangedChanges, [null]);
    expect(dateIconFinder, findsOneWidget);
    expect(clearIconFinder, findsNothing);
    expect(tester.getTextField().controller!.text, '');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('picker pops above field if not enough room below',
      (tester) async {
    await tester.pumpDateOnlyFieldOnBottom();

    expect(calPickerFinder, findsNothing);

    // Focuses and picker is displayed
    await tester.showKeyboard(fieldFinder);
    await tester.pumpAndSettle();

    // Calendar picker should be up now
    expect(calPickerFinder, findsOneWidget);

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/date_only_with_picker_above_field.png'));
  });

  testWidgets('does not allow entry nor displays picker when read-only',
      (tester) async {
    await tester.pumpDateOnlyField(readOnly: true);

    // Focuses and but does NOT pop-up picker
    await tester.showKeyboard(fieldFinder);
    await tester.pumpAndSettle();

    expect(calPickerFinder, findsNothing);

    await tester.enterText(fieldFinder, '1/2/22');
    await tester.pumpAndSettle();

    // Value should not have changed.
    expect(tester.getTextField().controller!.text, '');
    expect(tester.getTextField().decoration!.errorText, null);
    expect(onValueChangedChanges, isEmpty);

    // Tap the icon button - the picker should not be displayed.
    await tester.tap(dateIconFinder);
    await tester.pumpAndSettle();

    expect(calPickerFinder, findsNothing);
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

  testWidgets('tap date in calendar', (tester) async {
    await tester.pumpDateOnlyField();

    // We are on 10/2023 by default. Tap the 13th.
    await tester.showKeyboard(fieldFinder); // Focuses and pops-up picker
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
        of: calPickerFinder, matching: find.textContaining('13')));
    await tester.pumpAndSettle();

    expect(tester.getTextField().controller!.text, '10/13/2023');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('valueController sets initial value and sends updates to field',
      (tester) async {
    final date = DateTime.parse('2022-01-04');
    final date2 = DateTime.parse('2022-01-05');
    valueController.value = date;

    await tester.pumpDateOnlyField();

    // Check initialized value
    expect(valueController.value, date);
    expect(onValueChangedChanges, isEmpty);
    expect(tester.getTextField().controller!.text, '1/4/2022');
    expect(tester.getTextField().decoration!.errorText, null);

    valueController.value = date2;
    await tester.pumpAndSettle();

    expect(valueController.value, date2);
    // It should not invoke onValueChanged
    expect(onValueChangedChanges, isEmpty);
    // Text should change immediately because we do not have focus.
    expect(tester.getTextField().controller!.text, '1/5/2022');
    expect(tester.getTextField().decoration!.errorText, null);

    // Setting while field has focus set the text until it loses focus
    await tester.showKeyboard(fieldFinder); // Focuses
    await tester.pumpAndSettle();

    valueController.value = date;
    await tester.pumpAndSettle();

    // Should still be the previous date in the text.
    expect(tester.getTextField().controller!.text, '1/5/2022');
    expect(tester.getTextField().decoration!.errorText, null);

    // Lose focus
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // Now it should have the new date
    expect(tester.getTextField().controller!.text, '1/4/2022');
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

    await tester.enterText(fieldFinder, '1/32');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, 'Invalid value');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '1/2/25');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });
}

void datetimeGroupTests() {
  testWidgets('displays properly - no error, onValueChanged called',
      (tester) async {
    await tester.pumpDatetimeField();

    expect(labelFinder, findsOneWidget);
    expect(dateIconFinder, findsOneWidget);
    expect(clearIconFinder, findsNothing);
    expect(calPickerFinder, findsNothing);

    await tester.showKeyboard(fieldFinder); // Focuses
    await tester.pumpAndSettle();

    // Calendar picker should be up now and defaulted to the "current" date
    expect(calPickerFinder, findsOneWidget);
    expect(
        find.descendant(
            of: calPickerFinder, matching: find.text('October 2023')),
        findsOneWidget);

    expect(onValueChangedChanges, isEmpty);

    await tester.enterText(fieldFinder, '1/2/22 4pm');
    await tester.pumpAndSettle();

    expect(onValueChangedChanges, [DateTime.parse('2022-01-02T16:00:00')]);
    onValueChangedChanges.clear();
    expect(dateIconFinder, findsNothing);
    expect(clearIconFinder, findsOneWidget);
    expect(calPickerFinder, findsOneWidget);
    expect(
        find.descendant(
            of: calPickerFinder, matching: find.text('January 2022')),
        findsOneWidget);

    // Before losing focus, the text should be what we entered with no error
    expect(tester.getTextField().controller!.text, '1/2/22 4pm');
    expect(tester.getTextField().decoration!.errorText, null);

    // After focusing out of field to icon, picker is closed
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(calPickerFinder, findsNothing);

    // After focusing out of field to button value is reformatted.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(onValueChangedChanges, isEmpty);
    expect(tester.getTextField().controller!.text, '1/2/2022 4:00 PM');
    expect(tester.getTextField().decoration!.errorText, null);

    // Clearing the field with the clear icon should wipe out the text.
    await tester.tap(clearIconFinder);
    await tester.pumpAndSettle();

    expect(onValueChangedChanges, [null]);
    expect(dateIconFinder, findsOneWidget);
    expect(clearIconFinder, findsNothing);
    expect(tester.getTextField().controller!.text, '');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('datetime filling in year', (tester) async {
    await tester.pumpDatetimeField();

    await tester.enterText(fieldFinder, '1/2 3am');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(tester.getTextField().controller!.text, '1/2/2023 3:00 AM');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('datetime filling in year and midnight', (tester) async {
    await tester.pumpDatetimeField();

    await tester.enterText(fieldFinder, '1/2');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(tester.getTextField().controller!.text, '1/2/2023 12:00 AM');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('tap date in calendar', (tester) async {
    await tester.pumpDatetimeField();

    // We are on 10/2023 by default. Tap the 13th.
    await tester.showKeyboard(fieldFinder); // Focuses and pops-up picker
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
        of: calPickerFinder, matching: find.textContaining('13')));
    await tester.pumpAndSettle();

    // It should keep the current time and just change the date
    expect(tester.getTextField().controller!.text, '10/13/2023 4:15 PM');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('valueController sets initial value and sends updates to field',
      (tester) async {
    final date = DateTime.parse('2022-01-04T12:34:56');
    final date2 = DateTime.parse('2022-01-05T11:11:11');
    valueController.value = date;

    await tester.pumpDatetimeField();

    // Check initialized value
    expect(valueController.value, date);
    expect(onValueChangedChanges, isEmpty);
    expect(tester.getTextField().controller!.text, '1/4/2022 12:34 PM');
    expect(tester.getTextField().decoration!.errorText, null);

    valueController.value = date2;
    await tester.pumpAndSettle();

    expect(valueController.value, date2);
    // It should not invoke onValueChanged
    expect(onValueChangedChanges, isEmpty);
    // Text should change immediately because we do not have focus.
    expect(tester.getTextField().controller!.text, '1/5/2022 11:11 AM');
    expect(tester.getTextField().decoration!.errorText, null);

    // Setting while field has focus set the text until it loses focus
    await tester.showKeyboard(fieldFinder); // Focuses
    await tester.pumpAndSettle();

    valueController.value = date;
    await tester.pumpAndSettle();

    // Should still be the previous date in the text.
    expect(tester.getTextField().controller!.text, '1/5/2022 11:11 AM');
    expect(tester.getTextField().decoration!.errorText, null);

    // Lose focus
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // Now it should have the new date
    expect(tester.getTextField().controller!.text, '1/4/2022 12:34 PM');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('datetime beyond maxValue', (tester) async {
    await tester.pumpDatetimeField();

    await tester.enterText(fieldFinder, '12/15/25 17:01');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText,
        'Must be on or before 12/15/2025 5:00 PM');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '12/15/25 17:00');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('datetime before minValue', (tester) async {
    await tester.pumpDatetimeField();

    await tester.enterText(fieldFinder, '2/15/20 7:59am');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText,
        'Must be on or after 2/15/2020 8:00 AM');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '2/15/2020 8am');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('datetime invalid', (tester) async {
    await tester.pumpDatetimeField();

    await tester.enterText(fieldFinder, '1/1 25pm');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, 'Invalid value');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '1/2/25 4pm');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });
}

void timeGroupTests() {
  testWidgets('displays properly - no error, onValueChanged called',
      (tester) async {
    await tester.pumpTimeField();

    expect(labelFinder, findsOneWidget);
    expect(timeIconFinder, findsOneWidget);
    expect(clearIconFinder, findsNothing);
    expect(calPickerFinder, findsNothing);

    await tester.showKeyboard(fieldFinder); // Focuses
    await tester.pumpAndSettle();

    // Calendar picker should NOT be displayed because we are time-only
    expect(calPickerFinder, findsNothing);
    expect(onValueChangedChanges, isEmpty);

    await tester.enterText(fieldFinder, '4:01pm');
    await tester.pumpAndSettle();

    expect(onValueChangedChanges, [DateTime.parse('0000-01-01T16:01:00')]);
    onValueChangedChanges.clear();
    expect(dateIconFinder, findsNothing);
    expect(clearIconFinder, findsOneWidget);

    // Before losing focus, the text should be what we entered with no error
    expect(tester.getTextField().controller!.text, '4:01pm');
    expect(tester.getTextField().decoration!.errorText, null);

    // After focusing out of field to button value is reformatted.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(onValueChangedChanges, isEmpty);
    expect(tester.getTextField().controller!.text, '4:01 PM');
    expect(tester.getTextField().decoration!.errorText, null);

    // Clearing the field with the clear icon should wipe out the text.
    await tester.tap(clearIconFinder);
    await tester.pumpAndSettle();

    expect(onValueChangedChanges, [null]);
    expect(timeIconFinder, findsOneWidget);
    expect(clearIconFinder, findsNothing);
    expect(tester.getTextField().controller!.text, '');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('time filling in minute', (tester) async {
    await tester.pumpTimeField();

    await tester.showKeyboard(fieldFinder); // Focuses
    await tester.enterText(fieldFinder, '9am');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(tester.getTextField().controller!.text, '9:00 AM');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('valueController sets initial value and sends updates to field',
      (tester) async {
    final date = DateTime.parse('2022-01-04T12:34:56');
    final date2 = DateTime.parse('2022-01-05T11:11:11');
    valueController.value = date;

    await tester.pumpTimeField();

    // Check initialized value
    expect(valueController.value, date);
    expect(onValueChangedChanges, isEmpty);
    expect(tester.getTextField().controller!.text, '12:34 PM');
    expect(tester.getTextField().decoration!.errorText, null);

    valueController.value = date2;
    await tester.pumpAndSettle();

    expect(valueController.value, date2);
    // It should not invoke onValueChanged
    expect(onValueChangedChanges, isEmpty);
    // Text should change immediately because we do not have focus.
    expect(tester.getTextField().controller!.text, '11:11 AM');
    expect(tester.getTextField().decoration!.errorText, null);

    // Setting while field has focus set the text until it loses focus
    await tester.showKeyboard(fieldFinder); // Focuses
    await tester.pumpAndSettle();

    valueController.value = date;
    await tester.pumpAndSettle();

    // Should still be the previous date in the text.
    expect(tester.getTextField().controller!.text, '11:11 AM');
    expect(tester.getTextField().decoration!.errorText, null);

    // Lose focus
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // Now it should have the new date
    expect(tester.getTextField().controller!.text, '12:34 PM');
    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('time beyond maxValue', (tester) async {
    await tester.pumpTimeField();

    await tester.enterText(fieldFinder, '17:01');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText,
        'Must be on or before 5:00 PM');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '17:00');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('time before minValue', (tester) async {
    await tester.pumpTimeField();

    await tester.enterText(fieldFinder, '7:59am');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText,
        'Must be on or after 8:00 AM');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '8am');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });

  testWidgets('time invalid', (tester) async {
    await tester.pumpTimeField();

    await tester.enterText(fieldFinder, '25pm');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, 'Invalid value');

    // Correct the entry - error should clear
    await tester.enterText(fieldFinder, '12pm');
    await tester.pumpAndSettle();

    expect(tester.getTextField().decoration!.errorText, null);
  });
}

extension MoreWidgetTester on WidgetTester {
  TextField getTextField() => widget(textFieldFinder);

  Future<void> pumpDateOnlyField({bool readOnly = false}) async {
    await pumpWidgetWithHarness(VscDatetimeField(
      type: VscDatetimeFieldType.date,
      valueController: valueController,
      textFieldConfiguration: const TextFieldConfiguration(
          decoration: InputDecoration(
        label: Text(label),
      )),
      onValueChanged: (value) => onValueChangedChanges.add(value),
      minValue: DateTime.parse('2020-02-15'),
      maxValue: DateTime.parse('2025-12-15'),
      readOnly: readOnly,
    ));
  }

  Future<void> pumpDateOnlyFieldOnBottom() async {
    await pumpWidgetWithHarness(
        VscDatetimeField(
          type: VscDatetimeFieldType.date,
          valueController: valueController,
          textFieldConfiguration: const TextFieldConfiguration(
              decoration: InputDecoration(
            label: Text(label),
          )),
        ),
        onBottom: true);
  }

  Future<void> pumpDatetimeField() async {
    await pumpWidgetWithHarness(VscDatetimeField(
      type: VscDatetimeFieldType.datetime,
      valueController: valueController,
      textFieldConfiguration: const TextFieldConfiguration(
          decoration: InputDecoration(
        label: Text(label),
      )),
      onValueChanged: (value) => onValueChangedChanges.add(value),
      minValue: DateTime.parse('2020-02-15T08:00:00'),
      maxValue: DateTime.parse('2025-12-15T17:00:00'),
    ));
  }

  Future<void> pumpTimeField() async {
    await pumpWidgetWithHarness(VscDatetimeField(
      type: VscDatetimeFieldType.time,
      valueController: valueController,
      textFieldConfiguration: const TextFieldConfiguration(
          decoration: InputDecoration(
        label: Text(label),
      )),
      onValueChanged: (value) => onValueChangedChanges.add(value),
      minValue: DateTime.parse('0000-01-01T08:00:00'),
      maxValue: DateTime.parse('0000-01-01T17:00:00'),
    ));
  }

  Future<void> pumpWidgetWithHarness(
    Widget child, {
    bool onBottom = false,
  }) async {
    await pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBottom) const Spacer(),
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
