import 'dart:core';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:leancloud_plugin/leancloud_plugin.dart';

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
          Client client = Client(id: randomString());
          await client.open();
          assert(client.id != null);
          assert(client.tag == null);
          await client.close();
        }),
    UnitTestCaseCard(
        title: 'Case: Create Unique Conversation',
        callback: () async {
          String id1 = randomString();
          String id2 = randomString();
          Client client = Client(id: id1);
          // open
          await client.open();
          // create unique conversation
          Conversation conversation1 = await client.createConversation(
            type: ConversationType.normalUnique,
            members: [id1, id2],
          );
          final Map rawData1 = conversation1.rawData;
          assert(rawData1['conv_type'] == 1);
          final String objectId = rawData1['objectId'];
          assert(objectId != null);
          final String uniqueId = rawData1['uniqueId'];
          assert(uniqueId != null);
          List members1 = rawData1['m'];
          assert(members1.length == 2);
          assert(members1.contains(id1));
          assert(members1.contains(id2));
          assert(rawData1['unique'] == true);
          assert(rawData1['name'] == null);
          assert(rawData1['attr'] == null);
          assert(rawData1['c'] == id1);
          final String createdAt = rawData1['createdAt'];
          assert(createdAt != null);
          // query unique conversation from creation
          final String name = randomString();
          final String attrKey = randomString();
          final String attrValue = randomString();
          Conversation conversation2 = await client.createConversation(
            type: ConversationType.normalUnique,
            members: [id1, id2],
            name: name,
            attributes: {attrKey: attrValue},
          );
          assert(conversation2 == conversation1);
          final Map rawData2 = conversation2.rawData;
          assert(rawData2['conv_type'] == 1);
          assert(rawData2['objectId'] == objectId);
          assert(rawData2['uniqueId'] == uniqueId);
          List members2 = rawData2['m'];
          assert(members2.length == 2);
          assert(members2.contains(id1));
          assert(members2.contains(id2));
          assert(rawData2['unique'] == true);
          assert(rawData2['name'] == name);
          final Map attr = rawData2['attr'];
          assert(attr.length == 1);
          assert(attr[attrKey] == attrValue);
          assert(rawData2['c'] == id1);
          assert(rawData2['createdAt'] == createdAt);
          // close
          await client.close();
        }),
    UnitTestCaseCard(
        title: 'Case: Create Non-Unique Conversation',
        callback: () async {
          String id1 = randomString();
          String id2 = randomString();
          Client client = Client(id: id1);
          // open
          await client.open();
          // create non-unique conversation
          final String name = randomString();
          final String attrKey = randomString();
          final String attrValue = randomString();
          Conversation conversation = await client.createConversation(
            type: ConversationType.normal,
            members: [id1, id2],
            name: name,
            attributes: {attrKey: attrValue},
          );
          final Map rawData = conversation.rawData;
          assert(rawData['conv_type'] == 1);
          assert(rawData['objectId'] is String);
          assert(rawData['uniqueId'] is String);
          List members = rawData['m'];
          assert(members.length == 2);
          assert(members.contains(id1));
          assert(members.contains(id2));
          final bool unique = rawData['unique'];
          assert(unique == null || unique == false);
          assert(rawData['name'] == name);
          final Map attr = rawData['attr'];
          assert(attr.length == 1);
          assert(attr[attrKey] == attrValue);
          assert(rawData['c'] == id1);
          assert(rawData['createdAt'] is String);
          // close
          await client.close();
        }),
    UnitTestCaseCard(
        title: 'Case: Create Transient Conversation',
        callback: () async {
          Client client = Client(id: randomString());
          // open
          await client.open();
          // create transient conversation
          final String name = randomString();
          final String attrKey = randomString();
          final String attrValue = randomString();
          Conversation conversation = await client.createConversation(
            type: ConversationType.transient,
            name: name,
            attributes: {attrKey: attrValue},
          );
          final Map rawData = conversation.rawData;
          assert(rawData['conv_type'] == 2);
          assert(rawData['objectId'] is String);
          assert(rawData['tr'] == true);
          assert(rawData['name'] == name);
          final Map attr = rawData['attr'];
          assert(attr.length == 1);
          assert(attr[attrKey] == attrValue);
          assert(rawData['c'] == client.id);
          assert(rawData['createdAt'] is String);
          // close
          await client.close();
        }),
    UnitTestCaseCard(
        title: 'Case: Create Temporary Conversation',
        callback: () async {
          String id1 = randomString();
          String id2 = randomString();
          Client client = Client(id: id1);
          // open
          await client.open();
          // create temporary conversation
          Conversation conversation = await client.createConversation(
            type: ConversationType.temporary,
            members: [id1, id2],
            ttl: 3600,
          );
          final Map rawData = conversation.rawData;
          assert(rawData['conv_type'] == 4);
          String objectId = rawData['objectId'];
          assert(objectId.startsWith('_tmp:'));
          List members = rawData['m'];
          assert(members.length == 2);
          assert(members.contains(id1));
          assert(members.contains(id2));
          assert(rawData['temp'] == true);
          assert(rawData['ttl'] == 3600);
          // close
          await client.close();
        }),
    UnitTestCaseCard(
      title: 'Create Conversation',
      callback: () async {
        String clientId = randomString();
        LC.Client client = LC.Client(id: clientId);
        await client.open();
        await client.createConversation(members: [clientId], name: clientId );
        await client.close();
      },
    ),
    UnitTestCaseCard(
      title: 'Send Message',
      callback: () async {
        String clientId = randomString();
        LC.Client client = LC.Client(id: clientId);
        await client.open();
        LC.Conversation conversation =
          await client.createConversation(members: [clientId], name: clientId );
        LC.Message msg = LC.Message();
        msg.stringContent = "test from Dart";
        await conversation.send(message: msg);
        await client.close();
      },
    ),
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
    } on RTMException catch (e) {
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
