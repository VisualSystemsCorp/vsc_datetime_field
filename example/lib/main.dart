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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VSC Datetime Field Demo'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 30, 0, 30),
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                    onPressed: () {}, child: const Text('Focus test')),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.date,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text('Date only'),
                  )),
                  onDatetimeSelected: (value) {},
                ),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.date,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text('Datetime'),
                  )),
                  onDatetimeSelected: (value) {},
                ),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.time,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text('Time only'),
                  )),
                  onDatetimeSelected: (value) {},
                ),
                const SizedBox(height: 30),
                VscDatetimeField(
                  type: VscDatetimeFieldType.date,
                  textFieldConfiguration: const TextFieldConfiguration(
                      decoration: InputDecoration(
                    label: Text('Date - Read-only'),
                  )),
                  readOnly: true,
                  onDatetimeSelected: (value) {},
                  initialValue: DateTime.parse('2012-12-31'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
