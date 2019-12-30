import 'package:flutter/material.dart';

import 'package:leancloud_plugin/leancloud_plugin.dart' as LC;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
  }

  Map<String, int> states = {};
  List<String> titles = [
    'Init then Deinit',
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin Unit Test Cases'),
        ),
        body: ListView(padding: const EdgeInsets.all(16.0), children: [
          Divider(),
          ListTile(
              title: Text(this.titles[0],
                  style: TextStyle(
                      color: this.states[this.titles[0]] == null
                          ? Colors.black
                          : (this.states[this.titles[0]] == 1
                              ? Colors.green
                              : Colors.red),
                      fontSize: 18.0)),
              onTap: () async {
                LC.Client client = LC.Client(id: this.titles[0]);
                int success = 0;
                try {
                  await client.initialize();
                  await client.deinitialize();
                  success = 1;
                } on LC.RTMException catch (e) {
                  print(e);
                  success = -1;
                }
                setState(() {
                  this.states[this.titles[0]] = success;
                });
              }),
          Divider(),
        ]),
      ),
    );
  }
}
