import 'package:flutter/material.dart';
import 'package:vsc_datetime_field/vsc_datetime_field.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VSC Datetime Field Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          counterStyle: TextStyle(),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ValueNotifier<DateTime?> _valueController = ValueNotifier(null);
  final ValueNotifier<DateTime?> _interactiveValueController =
      ValueNotifier(null);

  @override
  void dispose() {
    _valueController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VSC Datetime Field Demo'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                    onPressed: () => _valueController.value = DateTime.now(),
                    child: const Text('Set date/time on fields')),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.date,
                  valueController: _valueController,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text('Date only'),
                  )),
                  onValueChanged: (value) =>
                      print('Date only field value: $value'),
                  minValue: DateTime.parse('2020-02-15'),
                  maxValue: DateTime.parse('2025-12-15'),
                ),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.datetime,
                  valueController: _valueController,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text('Datetime'),
                  )),
                  onValueChanged: (value) =>
                      print('Datetime field value: $value'),
                  minValue: DateTime.parse('2020-02-15 08:00:00'),
                  maxValue: DateTime.parse('2025-12-15 17:00:00'),
                ),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.time,
                  valueController: _valueController,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text('Time only'),
                  )),
                  onValueChanged: (value) => print('Time field value: $value'),
                  minValue: DateTime.parse('1970-01-01 08:00:00'),
                  maxValue: DateTime.parse('2099-01-01 17:00:00'),
                ),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.date,
                  valueController: _valueController,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text('Date - Read-only'),
                  )),
                  readOnly: true,
                ),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.datetime,
                  valueController: _interactiveValueController,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text(
                        'Independent Datetime with interacting valueController'),
                  )),
                  onValueChanged: (dt) =>
                      _interactiveValueController.value = dt,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  child: const Text('Show date picker dialog'),
                  onPressed: () {
                    showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.parse('2000-01-01'),
                      lastDate: DateTime.parse('2026-01-01'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
