import 'dart:core';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leancloud_plugin/leancloud_plugin.dart';

String uuid() => Uuid().generateV4();

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

UnitTestCaseCard clientOpenThenClose = UnitTestCaseCard(
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
    });

UnitTestCaseCard createUniqueConversation = UnitTestCaseCard(
    title: 'Case: Create Unique Conversation',
    extraExpectedCount: 4,
    testCaseFunc: (decrease) async {
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      client1.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String atDate,
        String byClientId,
      }) {
        client1.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client1.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client1.onConversationMembersJoin = null;
        assert(client != null);
        assert(conversation != null);
        assert(members.length == 2);
        assert(members.contains(client1.id));
        assert(members.contains(client2.id));
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String atDate,
        String byClientId,
      }) {
        client2.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client2.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client2.onConversationMembersJoin = null;
        assert(client != null);
        assert(conversation != null);
        assert(members.length == 2);
        assert(members.contains(client1.id));
        assert(members.contains(client2.id));
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      // open
      await client1.open();
      await client2.open();
      // create unique conversation
      Conversation conversation1 = await client1.createConversation(
        type: ConversationType.normalUnique,
        members: [client1.id, client2.id],
      );
      final Map rawData1 = conversation1.rawData;
      assert(rawData1['conv_type'] == 1);
      final String objectId = rawData1['objectId'];
      assert(objectId != null);
      final String uniqueId = rawData1['uniqueId'];
      assert(uniqueId != null);
      List members1 = rawData1['m'];
      assert(members1.length == 2);
      assert(members1.contains(client1.id));
      assert(members1.contains(client2.id));
      assert(rawData1['unique'] == true);
      assert(rawData1['name'] == null);
      assert(rawData1['attr'] == null);
      assert(rawData1['c'] == client1.id);
      final String createdAt = rawData1['createdAt'];
      assert(createdAt != null);
      // query unique conversation from creation
      final String name = uuid();
      final String attrKey = uuid();
      final String attrValue = uuid();
      Conversation conversation2 = await client1.createConversation(
        type: ConversationType.normalUnique,
        members: [client1.id, client2.id],
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
      assert(members2.contains(client1.id));
      assert(members2.contains(client2.id));
      assert(rawData2['unique'] == true);
      assert(rawData2['name'] == name);
      final Map attr = rawData2['attr'];
      assert(attr.length == 1);
      assert(attr[attrKey] == attrValue);
      assert(rawData2['c'] == client1.id);
      assert(rawData2['createdAt'] == createdAt);
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard createNonUniqueConversation = UnitTestCaseCard(
    title: 'Case: Create Non-Unique Conversation',
    extraExpectedCount: 4,
    testCaseFunc: (decrease) async {
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      client1.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String atDate,
        String byClientId,
      }) {
        client1.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client1.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client1.onConversationMembersJoin = null;
        assert(client != null);
        assert(conversation != null);
        assert(members.length == 2);
        assert(members.contains(client1.id));
        assert(members.contains(client2.id));
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String atDate,
        String byClientId,
      }) {
        client2.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client2.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client2.onConversationMembersJoin = null;
        assert(client != null);
        assert(conversation != null);
        assert(members.length == 2);
        assert(members.contains(client1.id));
        assert(members.contains(client2.id));
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      // open
      await client1.open();
      await client2.open();
      // create non-unique conversation
      final String name = uuid();
      final String attrKey = uuid();
      final String attrValue = uuid();
      Conversation conversation = await client1.createConversation(
        type: ConversationType.normal,
        members: [client1.id, client2.id],
        name: name,
        attributes: {attrKey: attrValue},
      );
      final Map rawData = conversation.rawData;
      assert(rawData['conv_type'] == 1);
      assert(rawData['objectId'] is String);
      List members = rawData['m'];
      assert(members.length == 2);
      assert(members.contains(client1.id));
      assert(members.contains(client2.id));
      final bool unique = rawData['unique'];
      assert(unique == null || unique == false);
      assert(rawData['name'] == name);
      final Map attr = rawData['attr'];
      assert(attr.length == 1);
      assert(attr[attrKey] == attrValue);
      assert(rawData['c'] == client1.id);
      assert(rawData['createdAt'] is String);
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard createTransientConversation = UnitTestCaseCard(
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
    });

UnitTestCaseCard createTemporaryConversation = UnitTestCaseCard(
    title: 'Case: Create Temporary Conversation',
    extraExpectedCount: 4,
    testCaseFunc: (decrease) async {
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      client1.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String atDate,
        String byClientId,
      }) {
        client1.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client1.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client1.onConversationMembersJoin = null;
        assert(client != null);
        assert(conversation != null);
        assert(members.length == 2);
        assert(members.contains(client1.id));
        assert(members.contains(client2.id));
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String atDate,
        String byClientId,
      }) {
        client2.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      client2.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client2.onConversationMembersJoin = null;
        assert(client != null);
        assert(conversation != null);
        assert(members.length == 2);
        assert(members.contains(client1.id));
        assert(members.contains(client2.id));
        assert(atDate != null);
        assert(byClientId != null);
        decrease(1);
      };
      // open
      await client1.open();
      await client2.open();
      // create temporary conversation
      Conversation conversation = await client1.createConversation(
        type: ConversationType.temporary,
        members: [client1.id, client2.id],
        ttl: 3600,
      );
      final Map rawData = conversation.rawData;
      assert(rawData['conv_type'] == 4);
      String objectId = rawData['objectId'];
      assert(objectId.startsWith('_tmp:'));
      List members = rawData['m'];
      assert(members.length == 2);
      assert(members.contains(client1.id));
      assert(members.contains(client2.id));
      assert(rawData['temp'] == true);
      assert(rawData['ttl'] == 3600);
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard sendMessage = UnitTestCaseCard(
    title: 'Case: Send Message',
    extraExpectedCount: 8,
    testCaseFunc: (decrease) async {
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      String stringContent = uuid();
      Uint8List binaryContent = Uint8List.fromList(uuid().codeUnits);
      String text = uuid();
      void Function(
        Message,
        Conversation,
      ) assertMessage = (
        Message message,
        Conversation conversation,
      ) {
        assert(message.id != null);
        assert(message.sentTimestamp != null);
        assert(message.conversationId == conversation.id);
        assert(message.fromClientId == client1.id);
      };
      void Function(
        FileMessage,
      ) assertFileMessage = (
        FileMessage fileMessage,
      ) {
        assert(fileMessage.url != null);
        assert(fileMessage.format != null);
        assert(fileMessage.size != null);
      };
      // event
      int client2OnMessageReceivedCount = 8;
      client2.onMessageReceive = ({
        Client client,
        Conversation conversation,
        Message message,
      }) {
        assert(client != null);
        assert(conversation != null);
        assertMessage(message, conversation);
        client2OnMessageReceivedCount -= 1;
        if (client2OnMessageReceivedCount <= 0) {
          client2.onMessageReceive = null;
        }
        if (message.stringContent != null) {
          // receive string
          assert(message.stringContent == stringContent);
          decrease(1);
          print('receive string');
        } else if (message.binaryContent != null) {
          // receive binary
          int index = 0;
          message.binaryContent.forEach((item) {
            assert(item == binaryContent[index]);
            index += 1;
          });
          decrease(1);
        } else if (message is TextMessage) {
          // receive text
          assert(message.text == text);
          decrease(1);
        } else if (message is ImageMessage) {
          // receive image
          assertFileMessage(message);
          assert(message.url.endsWith('/image.png'));
          assert(message.width != null);
          assert(message.height != null);
          decrease(1);
        } else if (message is AudioMessage) {
          // receive audio
          assertFileMessage(message);
          assert(message.duration != null);
          decrease(1);
        } else if (message is VideoMessage) {
          // receive video
          assertFileMessage(message);
          assert(message.duration != null);
          decrease(1);
        } else if (message is LocationMessage) {
          // receive location
          assert(message.latitude == 22);
          assert(message.longitude == 33);
          decrease(1);
        } else if (message is FileMessage) {
          // receive file
          assert(message.url != null);
          decrease(1);
        }
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: [client1.id, client2.id],
      );
      // send string
      Message stringMessage = Message();
      stringMessage.stringContent = stringContent;
      await conversation.send(message: stringMessage);
      assertMessage(stringMessage, conversation);
      assert(stringMessage.stringContent != null);
      // send binary
      Message binaryMessage = Message();
      binaryMessage.binaryContent = binaryContent;
      await conversation.send(message: binaryMessage);
      assertMessage(binaryMessage, conversation);
      assert(binaryMessage.binaryContent != null);
      // send text
      TextMessage textMessage = TextMessage();
      textMessage.text = text;
      await conversation.send(message: textMessage);
      assertMessage(textMessage, conversation);
      assert(textMessage.text != null);
      // send image
      ByteData imageData = await rootBundle.load('assets/test.png');
      ImageMessage imageMessage = ImageMessage.from(
        binaryData: imageData.buffer.asUint8List(),
        format: 'png',
        name: 'image.png',
      );
      await conversation.send(message: imageMessage);
      assertMessage(imageMessage, conversation);
      assertFileMessage(imageMessage);
      assert(imageMessage.width != null);
      assert(imageMessage.height != null);
      // send audio
      ByteData audioData = await rootBundle.load('assets/test.mp3');
      AudioMessage audioMessage = AudioMessage.from(
        binaryData: audioData.buffer.asUint8List(),
        format: 'mp3',
      );
      await conversation.send(message: audioMessage);
      assertMessage(audioMessage, conversation);
      assertFileMessage(audioMessage);
      assert(audioMessage.duration != null);
      // send video
      ByteData videoData = await rootBundle.load('assets/test.mp4');
      VideoMessage videoMessage = VideoMessage.from(
        binaryData: videoData.buffer.asUint8List(),
        format: 'mp3',
      );
      await conversation.send(message: videoMessage);
      assertMessage(videoMessage, conversation);
      assertFileMessage(videoMessage);
      assert(videoMessage.duration != null);
      // send location
      LocationMessage locationMessage = LocationMessage.from(
        latitude: 22,
        longitude: 33,
      );
      await conversation.send(message: locationMessage);
      assertMessage(locationMessage, conversation);
      assert(locationMessage.latitude == 22);
      assert(locationMessage.longitude == 33);
      // send file
      FileMessage fileMessage = FileMessage.from(
        url:
            'http://lc-heQFQ0Sw.cn-n1.lcfile.com/167022c1a77143a3aa48464b236fa00d',
        format: 'zip',
      );
      await conversation.send(message: fileMessage);
      assertMessage(locationMessage, conversation);
      assert(fileMessage.url != null);
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard readMessage = UnitTestCaseCard(
    title: 'Case: Read Message',
    extraExpectedCount: 3,
    testCaseFunc: (decrease) async {
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      int client2OnConversationUnreadMessageCountUpdateCount = 2;
      client2.onConversationUnreadMessageCountUpdate = ({
        Client client,
        Conversation conversation,
      }) {
        client2OnConversationUnreadMessageCountUpdateCount -= 1;
        if (client2OnConversationUnreadMessageCountUpdateCount <= 0) {
          client2.onConversationUnreadMessageCountUpdate = null;
        }
        if (conversation.unreadMessageCount == 1) {
          conversation.read();
          decrease(1);
        } else if (conversation.unreadMessageCount == 0) {
          decrease(1);
        }
      };
      client2.onMessageReceive = ({
        Client client,
        Conversation conversation,
        Message message,
      }) {
        client2.onMessageReceive = null;
        decrease(1);
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: [client1.id, client2.id],
      );
      // send string
      Message stringMessage = Message();
      stringMessage.stringContent = uuid();
      await conversation.send(message: stringMessage);
      // recycle
      return [client1, client2];
    });

class _MyAppState extends State<MyApp> {
  List<UnitTestCaseCard> cases = [
    clientOpenThenClose,
    createUniqueConversation,
    createNonUniqueConversation,
    createTransientConversation,
    createTemporaryConversation,
    sendMessage,
    readMessage,
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
        this.setState(() {
          this.state -= count;
        });
      } else {
        this.setState(() {
          this.state = -1;
        });
      }
      this.tearDown();
    };
  }

  Future<void> run() async {
    this.setState(() {
      this.state = this.expectedCount;
    });
    bool hasException = false;
    try {
      this.clients = await this.testCaseFunc(
        this.decreaseExpectedCountFunc,
      );
    } catch (e) {
      print('[⁉️][Exception]: $e');
      hasException = true;
    }
    if (hasException) {
      this.setState(() {
        this.state = -1;
      });
    } else {
      this.setState(() {
        this.state -= 1;
      });
    }
    this.tearDown();
  }

  void tearDown() {
    if (this.state <= 0) {
      this.clients.forEach((item) {
        this.close(item);
      });
    }
  }

  void close(
    Client client,
  ) {
    // session event
    client.onOpen = null;
    client.onResume = null;
    client.onDisconnect = null;
    client.onClose = null;
    // conversation
    client.onConversationInvite = null;
    client.onConversationKick = null;
    client.onConversationMembersJoin = null;
    client.onConversationMembersLeave = null;
    client.onConversationDataUpdate = null;
    client.onConversationLastMessageUpdate = null;
    client.onConversationUnreadMessageCountUpdate = null;
    // message
    client.onMessageReceive = null;
    client.onMessageUpdate = null;
    client.onMessageReceive = null;
    client.close();
  }

  @override
  Widget build(BuildContext context) {
    ListTile child = ListTile(
        title: Text(
            (this.state == this.expectedCount)
                ? this.title
                : ((this.state == 0)
                    ? '✅ ' + this.title
                    : ((this.state <= -1)
                        ? '❌ ' + this.title
                        : '💤 ' + this.title)),
            style: TextStyle(
                color: (this.state == this.expectedCount)
                    ? Colors.black
                    : ((this.state == 0)
                        ? Colors.green
                        : ((this.state <= -1) ? Colors.red : Colors.blue)),
                fontSize: 16.0,
                fontWeight: FontWeight.bold)),
        onTap: () async {
          if (this.state == this.expectedCount || this.state <= 0) {
            await this.run();
          }
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
