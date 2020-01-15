import 'dart:core';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:leancloud_plugin/leancloud_plugin.dart';

String uuid() => Uuid().generateV4();

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<UnitTestCaseCard> cases = [
    UnitTestCaseCard(
        title: 'Case: Client Open then Close',
        testCaseFunc: (decrease) async {
          Client client = Client(id: uuid());
          // open
          await client.open();
          assert(client.id != null);
          assert(client.tag == null);
          // close
          await client.close();
          return [];
        }),
    UnitTestCaseCard(
        title: 'Case: Create Unique Conversation',
        testCaseFunc: (decrease) async {
          String id1 = uuid();
          String id2 = uuid();
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
          final String name = uuid();
          final String attrKey = uuid();
          final String attrValue = uuid();
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
          // recycle
          return [client];
        }),
    UnitTestCaseCard(
        title: 'Case: Create Non-Unique Conversation',
        testCaseFunc: (decrease) async {
          String id1 = uuid();
          String id2 = uuid();
          Client client = Client(id: id1);
          // open
          await client.open();
          // create non-unique conversation
          final String name = uuid();
          final String attrKey = uuid();
          final String attrValue = uuid();
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
          // recycle
          return [client];
        }),
    UnitTestCaseCard(
        title: 'Case: Create Transient Conversation',
        testCaseFunc: (decrease) async {
          Client client = Client(id: uuid());
          // open
          await client.open();
          // create transient conversation
          final String name = uuid();
          final String attrKey = uuid();
          final String attrValue = uuid();
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
          // recycle
          return [client];
        }),
    UnitTestCaseCard(
        title: 'Case: Create Temporary Conversation',
        testCaseFunc: (decrease) async {
          String id1 = uuid();
          String id2 = uuid();
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
          // recycle
          return [client];
        }),
    UnitTestCaseCard(
      title: 'Case: Send Message',
      testCaseFunc: (decrease) async {
        String clientId = uuid();
        Client client = Client(id: clientId);
        // open
        await client.open();
        // create
        Conversation conversation = await client
            .createConversation(members: [clientId], name: clientId);
        Message msg = Message();
        msg.stringContent = "test from Dart";
        // send
        await conversation.send(message: msg);
        // recycle
        return [client];
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
                      extraExpectedCount: this.cases.length,
                      testCaseFunc: (decrease) async {
                        for (var i = 0; i < this.cases.length; i++) {
                          await this.cases[i].state.run();
                          decrease(1);
                        }
                        return [];
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
    int extraExpectedCount = 0,
    @required Future<List<Client>> Function(void Function(int)) testCaseFunc,
  }) : this.state = UnitTestCaseState(
          title: title,
          extraExpectedCount: extraExpectedCount,
          testCaseFunc: testCaseFunc,
        );

  @override
  UnitTestCaseState createState() => this.state;
}

class UnitTestCaseState extends State<UnitTestCaseCard> {
  String title;
  int expectedCount;
  int state;
  Future<List<Client>> Function(void Function(int)) testCaseFunc;
  void Function(int) decreaseExpectedCountFunc;

  List<Client> clients = List();

  UnitTestCaseState({
    @required this.title,
    int extraExpectedCount = 0,
    @required this.testCaseFunc,
  }) : assert(title != null) {
    this.expectedCount = (extraExpectedCount + 1);
    this.state = this.expectedCount;
    this.decreaseExpectedCountFunc = (int count) {
      if (count > 0) {
        setState(() {
          this.state -= count;
        });
      } else {
        setState(() {
          this.state = -1;
        });
      }
      if (this.state <= 0) {
        this.clients.forEach((item) {
          item.close();
        });
      }
    };
  }

  Future<void> run() async {
    setState(() {
      this.state = this.expectedCount;
    });
    bool hasException = false;
    try {
      this.clients = await this.testCaseFunc(
        this.decreaseExpectedCountFunc,
      );
    } on RTMException catch (e) {
      print(e);
      hasException = true;
    }
    if (hasException) {
      setState(() {
        this.state = -1;
      });
    } else {
      setState(() {
        this.state -= 1;
      });
    }
    if (this.state <= 0) {
      this.clients.forEach((item) {
        item.close();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ListTile child = ListTile(
        title: Text(
            (this.state == this.expectedCount)
                ? this.title
                : ((this.state == 0)
                    ? '✅ ' + this.title
                    : ((this.state == -1)
                        ? '❌ ' + this.title
                        : '💤 ' + this.title)),
            style: TextStyle(
                color: (this.state == this.expectedCount)
                    ? Colors.black
                    : ((this.state == 0)
                        ? Colors.green
                        : ((this.state == -1) ? Colors.red : Colors.blue)),
                fontSize: 16.0,
                fontWeight: FontWeight.bold)),
        onTap: () async {
          await this.run();
        });
    return Card(child: child);
  }
}

class Uuid {
  final Random _random = Random();

  /// Generate a version 4 (random) uuid. This is a uuid scheme that only uses
  /// random numbers as the source of the generated uuid.
  String generateV4() {
    // Generate xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx / 8-4-4-4-12.
    var special = 8 + _random.nextInt(4);

    return '${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}-'
        '${_bitsDigits(16, 4)}-'
        '4${_bitsDigits(12, 3)}-'
        '${_printDigits(special, 1)}${_bitsDigits(12, 3)}-'
        '${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}${_bitsDigits(16, 4)}';
  }

  String _bitsDigits(int bitCount, int digitCount) =>
      _printDigits(_generateBits(bitCount), digitCount);

  int _generateBits(int bitCount) => _random.nextInt(1 << bitCount);

  String _printDigits(int value, int count) =>
      value.toRadixString(16).padLeft(count, '0');
}
