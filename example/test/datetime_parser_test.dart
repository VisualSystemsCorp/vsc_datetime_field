import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vsc_datetime_field/datetime_parser.dart';

final dateFmts = <DateFormat>[
  DateFormat('M/d/y'),
  DateFormat('y-M-d'),
];

final dateTimeFmts = <DateFormat>[
  DateFormat('M/d/y h a'),
  DateFormat('M/d/y H'),
  DateFormat('M/d/y h:m a'),
  DateFormat('M/d/y H:m'),
  DateFormat('M/d/y h:m:s a'),
  DateFormat('M/d/y H:m:s'),
];

final currentYear = DateTime.now().year;

main() {
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
    _Case(dateFmts, 'May 2, 2022', DateTime.parse('2022-05-02T00:00:00.000')),
    _Case(dateFmts, 'Feb 2, 2022', DateTime.parse('2022-02-02T00:00:00.000')),
    _Case(dateFmts, 'September 2 2022',
        DateTime.parse('2022-09-02T00:00:00.000')),
    _Case(dateFmts, '5/2/2022', DateTime.parse('2022-05-02T00:00:00.000')),
    // Alternate format
    _Case(dateFmts, '2022-05-10', DateTime.parse('2022-05-10T00:00:00.000')),

    // --- Datetime formats
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
    _Case(dateTimeFmts, '12/31/22 1pm',
        DateTime.parse('2022-12-31T13:00:00.000')),
  ]) {
    test('successfully parses ${t.inputString}', () {
      final result =
          parseDateTime(t.inputString, parserFormats: t.parserFormatters);
      expect(result, t.expectedResult);
    });
  }

  // for (final t in ['13/31', '12/32', '']) {
  //   test('Fails to parse $t', () {
  //     final result =
  //         parseDateTime(t, parserFormats: dateTimeFmts);
  //     expect(result, t.expectedResult);
  //   });
  // }
}

class _Case {
  List<DateFormat> parserFormatters;
  String inputString;
  DateTime expectedResult;

  _Case(this.parserFormatters, this.inputString, this.expectedResult);
}
