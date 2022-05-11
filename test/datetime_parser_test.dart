import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vsc_datetime_field/datetime_parser.dart';

final dateFmts = <DateFormat>[
  DateFormat('M/d/y'),
  DateFormat('y-M-d'),
];

final dateTimeFmts = <DateFormat>[
  DateFormat('M/d/y H'),
  DateFormat('M/d/y h a'),
  DateFormat('M/d/y H:m'),
  DateFormat('M/d/y h:m a'),
  DateFormat('M/d/y H:m:s'),
  DateFormat('M/d/y h:m:s a'),
  DateFormat('M/d/y H:m:s.S'),
  DateFormat('M/d/y h:m:s.S a'),
];

final timeFmts = <DateFormat>[
  DateFormat('H'),
  DateFormat('h a'),
  DateFormat('H:m'),
  DateFormat('h:m a'),
  DateFormat('H:m:s'),
  DateFormat('h:m:s a'),
  DateFormat('H:m:s.S'),
  DateFormat('h:m:s.S a'),
];

final fixedTime = DateTime.parse('2023-10-06T16:15:14.123');
final currentYear = fixedTime.year;

main() {
  Intl.defaultLocale = 'en-US';

  for (final t in [
    // --- Date only formats
    _Case(dateFmts, '05/02/2022', DateTime.parse('2022-05-02T00:00:00.000')),
    // Ambiguous years:
    _Case(dateFmts, '5/2/22', DateTime.parse('2022-05-02T00:00:00.000')),
    _Case(dateFmts, '5/2/62', DateTime.parse('1962-05-02T00:00:00.000')),
    // Missing year
    _Case(dateFmts, '5/2', DateTime.parse('$currentYear-05-02T00:00:00.000')),
    // Deviant formatting
    _Case(dateFmts, '05/02/22', DateTime.parse('2022-05-02T00:00:00.000')),
    _Case(dateFmts, '5 2 22', DateTime.parse('2022-05-02T00:00:00.000')),
    _Case(dateFmts, '5.2.22', DateTime.parse('2022-05-02T00:00:00.000')),
    _Case(dateFmts, 'May 2, 2022', DateTime.parse('2022-05-02T00:00:00.000')),
    _Case(dateFmts, 'Feb 2, 2022', DateTime.parse('2022-02-02T00:00:00.000')),
    _Case(dateFmts, 'September 2 2022',
        DateTime.parse('2022-09-02T00:00:00.000')),
    _Case(dateFmts, 'september 2 2022',
        DateTime.parse('2022-09-02T00:00:00.000')),
    _Case(dateFmts, 'FEB 2, 2022', DateTime.parse('2022-02-02T00:00:00.000')),
    _Case(dateFmts, '5/2/2022', DateTime.parse('2022-05-02T00:00:00.000')),
    // Alternate format
    _Case(dateFmts, '2022-05-10', DateTime.parse('2022-05-10T00:00:00.000')),
    // Day overflows month, which goes into the next month. This is the DateTime behavior.
    _Case(dateFmts, '2/30/2022', DateTime.parse('2022-03-02T00:00:00.000')),
    _Case(dateFmts, '4/31/2022', DateTime.parse('2022-05-01T00:00:00.000')),

    // --- Datetime formats
    _Case(dateTimeFmts, '5/2 3:46p', DateTime.parse('2023-05-02T15:46:00.000')),
    _Case(dateTimeFmts, '5/2 15:46', DateTime.parse('2023-05-02T15:46:00.000')),
    _Case(dateTimeFmts, '5/2 3p', DateTime.parse('2023-05-02T15:00:00.000')),
    _Case(dateTimeFmts, '5/2/22 3', DateTime.parse('2022-05-02T03:00:00.000')),
    _Case(dateTimeFmts, '5/2/22 3:46p',
        DateTime.parse('2022-05-02T15:46:00.000')),
    _Case(dateTimeFmts, '5/2/22 3:46:34 pm',
        DateTime.parse('2022-05-02T15:46:34.000')),
    _Case(dateTimeFmts, '5/2/22 3:46 pM',
        DateTime.parse('2022-05-02T15:46:00.000')),
    _Case(dateTimeFmts, '5/2/22 3:46a',
        DateTime.parse('2022-05-02T03:46:00.000')),
    _Case(dateTimeFmts, '5/2/22 3:46 AM',
        DateTime.parse('2022-05-02T03:46:00.000')),
    _Case(
        dateTimeFmts, '5/2/22 3:46', DateTime.parse('2022-05-02T03:46:00.000')),
    _Case(dateTimeFmts, '5/2/22 15:46',
        DateTime.parse('2022-05-02T15:46:00.000')),
    _Case(dateTimeFmts, '5/2/22 15:46:34',
        DateTime.parse('2022-05-02T15:46:34.000')),
    _Case(dateTimeFmts, '9/13/22', DateTime.parse('2022-09-13T00:00:00.000')),
    _Case(dateTimeFmts, '12/31/22 1am',
        DateTime.parse('2022-12-31T01:00:00.000')),
    _Case(dateTimeFmts, '12/31/22 1pm',
        DateTime.parse('2022-12-31T13:00:00.000')),
    _Case(dateTimeFmts, '12/31/22 12 am',
        DateTime.parse('2022-12-31T00:00:00.000')),
    _Case(dateTimeFmts, '12/31/22 12 pm',
        DateTime.parse('2022-12-31T12:00:00.000')),
    _Case(dateTimeFmts, '12/31/22 13:00',
        DateTime.parse('2022-12-31T13:00:00.000')),
    _Case(dateTimeFmts, '12/31/22 01:00',
        DateTime.parse('2022-12-31T01:00:00.000')),
    // Fractional seconds and extra whitespace
    _Case(dateTimeFmts, '  1/2/22 12:34.56.789  ',
        DateTime.parse('2022-01-02T12:34:56.789')),

    // --- Time only formats
    _Case(timeFmts, '3:46p', DateTime.parse('2023-10-06T15:46:00.000')),
    _Case(timeFmts, '3:46:34 pm', DateTime.parse('2023-10-06T15:46:34.000')),
    _Case(timeFmts, '3:46 pM', DateTime.parse('2023-10-06T15:46:00.000')),
    _Case(timeFmts, '3:46a', DateTime.parse('2023-10-06T03:46:00.000')),
    _Case(timeFmts, '3:46 AM', DateTime.parse('2023-10-06T03:46:00.000')),
    _Case(timeFmts, '3:46', DateTime.parse('2023-10-06T03:46:00.000')),
    _Case(timeFmts, '15:46', DateTime.parse('2023-10-06T15:46:00.000')),
    _Case(timeFmts, '15:46:34', DateTime.parse('2023-10-06T15:46:34.000')),
    _Case(timeFmts, '1am', DateTime.parse('2023-10-06T01:00:00.000')),
    _Case(timeFmts, '1pm', DateTime.parse('2023-10-06T13:00:00.000')),
    _Case(timeFmts, '12 am', DateTime.parse('2023-10-06T00:00:00.000')),
    _Case(timeFmts, '00:00', DateTime.parse('2023-10-06T00:00:00.000')),
    _Case(timeFmts, '12 pm', DateTime.parse('2023-10-06T12:00:00.000')),
    _Case(timeFmts, '13:00', DateTime.parse('2023-10-06T13:00:00.000')),
    _Case(timeFmts, '01:00', DateTime.parse('2023-10-06T01:00:00.000')),
    // Fractional seconds and extra whitespace
    _Case(
        timeFmts, ' 12:34.56.789  ', DateTime.parse('2023-10-06T12:34:56.789')),
    _Case(timeFmts, '12:34.56.999', DateTime.parse('2023-10-06T12:34:56.999')),

    // --- Special-case formats
    //  Standalone month
    _Case([DateFormat('L')], '12', DateTime.parse('2023-12-06T00:00:00.000')),
    _Case([DateFormat('L')], 'Dec', DateTime.parse('2023-12-06T00:00:00.000')),
    _Case([DateFormat('L')], 'december',
        DateTime.parse('2023-12-06T00:00:00.000')),
    // Hour 'k' - 1-24
    _Case([DateFormat('k')], '13', DateTime.parse('2023-10-06T12:00:00.000')),
    _Case([DateFormat('k')], '24', DateTime.parse('2023-10-06T23:00:00.000')),
    _Case([DateFormat('k')], '1', DateTime.parse('2023-10-06T00:00:00.000')),
    // Hour 'K' - 0-11 in 12h
    _Case([DateFormat('K')], '5', DateTime.parse('2023-10-06T05:00:00.000')),
    _Case([DateFormat('K')], '11', DateTime.parse('2023-10-06T11:00:00.000')),
    _Case([DateFormat('K')], '0', DateTime.parse('2023-10-06T00:00:00.000')),
  ]) {
    test('successfully parses ${t.inputString}', () {
      withClock(Clock.fixed(fixedTime), () {
        final result =
            parseDateTime(t.inputString, parserFormats: t.parserFormatters);
        expect(result, t.expectedResult);
      });
    });
  }

  // Negative cases:
  for (final t in [
    // Missing input
    '',
    // Too much input
    '12/31/22 1:23:23.999 am 999',
    // Month invalid
    '13/31',
    '0/31',
    'Jax 31, 2022',
    'Ja 31, 2022',
    // Day invalid
    '12/32',
    '12/0',
    '12/Tue',
    // Year invalid
    '12/22/bad',
    // Hour invalid
    '12/22/22 24:00',
    '12/22/22 25:00',
    // Minute invalid
    '12/22/22 23:60',
    '12/22/22 23:999',
    // Second invalid
    '12/22/22 23:59:60',
    '12/22/22 23:59:999',
    // Fractional second invalid
    '12/22/22 23:59:59.9991',
  ]) {
    test('Fails to parse: $t', () {
      expect(() => parseDateTime(t, parserFormats: dateTimeFmts),
          throwsFormatException);
    });
  }

  test('Does not adjust for ambiguous year based on param', () {
    withClock(Clock.fixed(fixedTime), () {
      final result = parseDateTime(
        '5/2/22',
        parserFormats: [DateFormat('M/d/y')],
        allowAmbiguousYear: false,
      );
      expect(result, DateTime.parse('0022-05-02T00:00:00.000'));
    });
  });

  test('Adjusts for UTC based on param', () {
    withClock(Clock.fixed(fixedTime), () {
      final result = parseDateTime(
        '5/2/22 00:00:00',
        parserFormats: [DateFormat('M/d/y H:m:s')],
        utc: true,
      );
      expect(result, DateTime.parse('2022-05-02T00:00:00.000').toUtc());
    });
  });
}

class _Case {
  List<DateFormat> parserFormatters;
  String inputString;
  DateTime expectedResult;

  _Case(this.parserFormatters, this.inputString, this.expectedResult);
}
