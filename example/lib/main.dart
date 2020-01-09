import 'dart:core';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:leancloud_plugin/leancloud_plugin.dart' as LC;

const __chars = "abcdefghijklmnopqrstuvwxyz";
String randomString({int strlen = 32}) {
  Random rnd = new Random(new DateTime.now().millisecondsSinceEpoch);
  String result = "";
  for (var i = 0; i < strlen; i++) {
    result += __chars[rnd.nextInt(__chars.length)];
  }
  return result;
}

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<UnitTestCaseCard> cases = [
    UnitTestCaseCard(
        title: 'Case: Client Open then Close',
        callback: () async {
          LC.Client client = LC.Client(id: randomString());
          await client.open();
          await client.close();
        }),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin Unit Test Cases'),
        ),
        body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
                  UnitTestCaseCard(
                      title: 'Run All Cases',
                      callback: () async {
                        for (var i = 0; i < this.cases.length; i++) {
                          await this.cases[i].state.run();
                        }
                      }),
                ] +
                this.cases),
      ),
    );
  }
}

class UnitTestCaseCard extends StatefulWidget {
  final String title;
  final UnitTestCaseState state;

  UnitTestCaseCard({
    @required this.title,
    @required Future<void> Function() callback,
  }) : this.state = UnitTestCaseState(title: title, callback: callback);

  @override
  UnitTestCaseState createState() => this.state;
}

class UnitTestCaseState extends State<UnitTestCaseCard> {
  String title;
  int state = 0;
  Future<void> Function() callback;

  UnitTestCaseState({
    @required this.title,
    @required this.callback,
  }) : assert(title != null);

  Future<void> run() async {
    int success = 0;
    try {
      await this.callback();
      success = 1;
    } on LC.RTMException catch (e) {
      print(e);
      success = -1;
    }
    setState(() {
      this.state = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    ListTile child = ListTile(
        title: Text(
            this.state == 0
                ? this.title
                : (this.state == 1 ? '✅ ' + this.title : '❌ ' + this.title),
            style: TextStyle(
                color: this.state == 0
                    ? Colors.black
                    : (this.state == 1 ? Colors.green : Colors.red),
                fontSize: 16.0,
                fontWeight: FontWeight.bold)),
        onTap: () async {
          await this.run();
        });
    return Card(child: child);
  }
}
