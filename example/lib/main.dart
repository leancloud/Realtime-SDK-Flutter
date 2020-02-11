import 'dart:core';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leancloud_plugin/leancloud_plugin.dart';

String uuid() => Uuid().generateV4();

Future<void> delay({
  int seconds = 3,
}) async =>
    await Future.delayed(Duration(seconds: seconds));

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

UnitTestCaseCard clientOpenThenClose = UnitTestCaseCard(
    title: 'Case: Client Open then Close',
    testCaseFunc: (decrease) async {
      // client
      Client client = Client(id: uuid());
      // open
      await client.open();
      assert(client.id != null);
      assert(client.tag == null);
      // close
      await client.close();
      // reopen
      await client.open();
      return [client];
    });

UnitTestCaseCard createUniqueConversationAndCountMember = UnitTestCaseCard(
    title: 'Case: Create Unique Conversation & Count Member',
    extraExpectedCount: 4,
    testCaseFunc: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      client1.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) {
        client1.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
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
        assert(byClientId == client1.id);
        assert(atDate != null);
        decrease(1);
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) {
        client2.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
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
        assert(byClientId == client1.id);
        assert(atDate != null);
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
      Map rawData1 = conversation1.rawData;
      assert(rawData1['conv_type'] == 1);
      String objectId = rawData1['objectId'];
      assert(objectId != null);
      String uniqueId = rawData1['uniqueId'];
      assert(uniqueId != null);
      List members1 = rawData1['m'];
      assert(members1.length == 2);
      assert(members1.contains(client1.id));
      assert(members1.contains(client2.id));
      assert(rawData1['unique'] == true);
      assert(rawData1['name'] == null);
      assert(rawData1['attr'] == null);
      assert(rawData1['c'] == client1.id);
      String createdAt = rawData1['createdAt'];
      assert(createdAt != null);
      // query unique conversation from creation
      String name = uuid();
      String attrKey = uuid();
      String attrValue = uuid();
      Conversation conversation2 = await client1.createConversation(
        type: ConversationType.normalUnique,
        members: [client1.id, client2.id],
        name: name,
        attributes: {attrKey: attrValue},
      );
      assert(conversation2 == conversation1);
      Map rawData2 = conversation2.rawData;
      assert(rawData2['conv_type'] == 1);
      assert(rawData2['objectId'] == objectId);
      assert(rawData2['uniqueId'] == uniqueId);
      List members2 = rawData2['m'];
      assert(members2.length == 2);
      assert(members2.contains(client1.id));
      assert(members2.contains(client2.id));
      assert(rawData2['unique'] == true);
      assert(rawData2['name'] == name);
      Map attr = rawData2['attr'];
      assert(attr.length == 1);
      assert(attr[attrKey] == attrValue);
      assert(rawData2['c'] == client1.id);
      assert(rawData2['createdAt'] == createdAt);
      int count = await conversation2.countMembers();
      assert(count == 2);
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard createNonUniqueConversationAndUpdateMember = UnitTestCaseCard(
    title: 'Case: Create Non-Unique Conversation & Update Member',
    extraExpectedCount: 17,
    testCaseFunc: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      String client3id = uuid();
      // event
      int client1OnConversationInvite = 2;
      client1.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) async {
        client1OnConversationInvite -= 1;
        if (client1OnConversationInvite <= 0) {
          client1.onConversationInvite = null;
        }
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
        List m = conversation.rawData['m'];
        assert(m.length == 2);
        assert(m.contains(client1.id));
        assert(m.contains(client2.id));
        if (client1OnConversationInvite == 1) {
          // join by create
          decrease(1);
        } else if (client1OnConversationInvite == 0) {
          // rejoin
          decrease(1);
        }
      };
      client1.onConversationKick = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) async {
        client1.onConversationKick = null;
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
        List m1 = conversation.rawData['m'];
        assert(m1.length == 1);
        assert(m1.contains(client2.id));
        decrease(1);
        Map result = await conversation.updateMembers(
          members: [client1.id],
          op: 'add',
        );
        List allowedPids = result['allowedPids'];
        assert(allowedPids.length == 1);
        assert(allowedPids.contains(client1.id));
        List m2 = conversation.rawData['m'];
        assert(m2.length == 2);
        assert(m2.contains(client1.id));
        assert(m2.contains(client2.id));
        assert(result['udate'] is String);
        decrease(1);
      };
      int client1OnConversationMembersJoin = 3;
      client1.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) async {
        client1OnConversationMembersJoin -= 1;
        if (client1OnConversationMembersJoin <= 0) {
          client1.onConversationMembersJoin = null;
        }
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
        if (client1OnConversationMembersJoin == 2) {
          // join by create
          assert(members.length == 2);
          assert(members.contains(client1.id));
          assert(members.contains(client2.id));
          List m = conversation.rawData['m'];
          assert(m.length == 2);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          decrease(1);
        } else if (client1OnConversationMembersJoin == 1) {
          // rejoin
          assert(members.length == 1);
          assert(members.contains(client1.id));
          List m = conversation.rawData['m'];
          assert(m.length == 2);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          decrease(1);
        } else if (client1OnConversationMembersJoin == 0) {
          // add new member
          assert(members.length == 1);
          assert(members.contains(client3id));
          List m = conversation.rawData['m'];
          assert(m.length == 3);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          assert(m.contains(client3id));
          decrease(1);
        }
        if (client1OnConversationMembersJoin == 2) {
          Map result = await conversation.updateMembers(
            members: [client1.id],
            op: 'remove',
          );
          List allowedPids = result['allowedPids'];
          assert(allowedPids.length == 1);
          assert(allowedPids.contains(client1.id));
          List m = conversation.rawData['m'];
          assert(m.length == 1);
          assert(m.contains(client2.id));
          assert(result['udate'] is String);
          decrease(1);
        } else if (client1OnConversationMembersJoin == 1) {
          Map result = await conversation.updateMembers(
            members: [client3id],
            op: 'add',
          );
          List allowedPids = result['allowedPids'];
          assert(allowedPids.length == 1);
          assert(allowedPids.contains(client3id));
          List m = conversation.rawData['m'];
          assert(m.length == 3);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          assert(m.contains(client3id));
          assert(result['udate'] is String);
          decrease(1);
        } else if (client1OnConversationMembersJoin == 0) {
          Map result = await conversation.updateMembers(
            members: [client3id],
            op: 'remove',
          );
          List allowedPids = result['allowedPids'];
          assert(allowedPids.length == 1);
          assert(allowedPids.contains(client3id));
          List m = conversation.rawData['m'];
          assert(m.length == 2);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          assert(result['udate'] is String);
          decrease(1);
        }
      };
      client1.onConversationMembersLeave = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client1.onConversationMembersLeave = null;
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
        assert(members.length == 1);
        assert(members.contains(client3id));
        List m = conversation.rawData['m'];
        assert(m.length == 2);
        assert(m.contains(client1.id));
        assert(m.contains(client2.id));
        decrease(1);
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) {
        client2.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
        List m = conversation.rawData['m'];
        assert(m.length == 2);
        assert(m.contains(client1.id));
        assert(m.contains(client2.id));
        decrease(1);
      };
      int client2OnConversationMembersJoin = 3;
      client2.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client2OnConversationMembersJoin -= 1;
        if (client2OnConversationMembersJoin <= 0) {
          client2.onConversationMembersJoin = null;
        }
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
        if (client2OnConversationMembersJoin == 2) {
          // join by create
          assert(members.length == 2);
          assert(members.contains(client1.id));
          assert(members.contains(client2.id));
          List m = conversation.rawData['m'];
          assert(m.length == 2);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          decrease(1);
        } else if (client2OnConversationMembersJoin == 1) {
          // rejoin
          assert(members.length == 1);
          assert(members.contains(client1.id));
          List m = conversation.rawData['m'];
          assert(m.length == 2);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          decrease(1);
        } else if (client2OnConversationMembersJoin == 0) {
          // add new member
          assert(members.length == 1);
          assert(members.contains(client3id));
          List m = conversation.rawData['m'];
          assert(m.length == 3);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          assert(m.contains(client3id));
          decrease(1);
        }
      };
      int client2OnConversationMembersLeave = 2;
      client2.onConversationMembersLeave = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        client2OnConversationMembersLeave -= 1;
        if (client2OnConversationMembersLeave <= 0) {
          client2.onConversationMembersLeave = null;
        }
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
        if (client2OnConversationMembersLeave == 1) {
          // leave
          assert(members.length == 1);
          assert(members.contains(client1.id));
          List m = conversation.rawData['m'];
          assert(m.length == 1);
          assert(m.contains(client2.id));
          decrease(1);
        } else if (client2OnConversationMembersLeave == 0) {
          // remove new member
          assert(members.length == 1);
          assert(members.contains(client3id));
          List m = conversation.rawData['m'];
          assert(m.length == 2);
          assert(m.contains(client1.id));
          assert(m.contains(client2.id));
          decrease(1);
        }
      };
      // open
      await client1.open();
      await client2.open();
      // create non-unique conversation
      String name = uuid();
      String attrKey = uuid();
      String attrValue = uuid();
      Conversation conversation = await client1.createConversation(
        type: ConversationType.normal,
        members: [client1.id, client2.id],
        name: name,
        attributes: {attrKey: attrValue},
      );
      Map rawData = conversation.rawData;
      assert(rawData['conv_type'] == 1);
      assert(rawData['objectId'] is String);
      List members = rawData['m'];
      assert(members.length == 2);
      assert(members.contains(client1.id));
      assert(members.contains(client2.id));
      bool unique = rawData['unique'];
      assert(unique == null || unique == false);
      assert(rawData['name'] == name);
      Map attr = rawData['attr'];
      assert(attr.length == 1);
      assert(attr[attrKey] == attrValue);
      assert(rawData['c'] == client1.id);
      assert(rawData['createdAt'] is String);
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard createTransientConversationAndCountMember = UnitTestCaseCard(
    title: 'Case: Create Transient Conversation & Count Member',
    testCaseFunc: (decrease) async {
      // client
      Client client = Client(id: uuid());
      // open
      await client.open();
      // create transient conversation
      String name = uuid();
      String attrKey = uuid();
      String attrValue = uuid();
      Conversation conversation = await client.createConversation(
        type: ConversationType.transient,
        name: name,
        attributes: {attrKey: attrValue},
      );
      Map rawData = conversation.rawData;
      assert(rawData['conv_type'] == 2);
      assert(rawData['objectId'] is String);
      assert(rawData['tr'] == true);
      assert(rawData['name'] == name);
      Map attr = rawData['attr'];
      assert(attr.length == 1);
      assert(attr[attrKey] == attrValue);
      assert(rawData['c'] == client.id);
      assert(rawData['createdAt'] is String);
      int count = await conversation.countMembers();
      assert(count == 1);
      // recycle
      return [client];
    });

UnitTestCaseCard createAndQueryTemporaryConversation = UnitTestCaseCard(
    title: 'Case: Create & Query Temporary Conversation',
    extraExpectedCount: 4,
    testCaseFunc: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      client1.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) {
        client1.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
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
        assert(byClientId == client1.id);
        assert(atDate != null);
        decrease(1);
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) {
        client2.onConversationInvite = null;
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
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
        assert(byClientId == client1.id);
        assert(atDate != null);
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
      Map rawData = conversation.rawData;
      assert(rawData['conv_type'] == 4);
      String objectId = rawData['objectId'];
      assert(objectId.startsWith('_tmp:'));
      List members = rawData['m'];
      assert(members.length == 2);
      assert(members.contains(client1.id));
      assert(members.contains(client2.id));
      assert(rawData['temp'] == true);
      assert(rawData['ttl'] == 3600);
      List<Conversation> conversations = await client2.queryConversation(
        temporaryConversationIds: [conversation.id],
      );
      assert(conversations.length == 1);
      assert(conversations[0].id == conversation.id);
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard sendAndQueryMessage = UnitTestCaseCard(
    title: 'Case: Send & Query Message',
    extraExpectedCount: 17,
    testCaseFunc: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // string content
      String stringContent = uuid();
      // string message
      Message stringMessage = Message();
      stringMessage.stringContent = stringContent;
      // binary content
      Uint8List binaryContent = Uint8List.fromList(uuid().codeUnits);
      // binary message
      Message binaryMessage = Message();
      binaryMessage.binaryContent = binaryContent;
      // text
      String text = uuid();
      // text message
      TextMessage textMessage = TextMessage();
      textMessage.text = text;
      // image data
      ByteData imageData = await rootBundle.load('assets/test.png');
      // image message
      ImageMessage imageMessage = ImageMessage.from(
        binaryData: imageData.buffer.asUint8List(),
        format: 'png',
        name: 'image.png',
      );
      // audio data
      ByteData audioData = await rootBundle.load('assets/test.mp3');
      // audio message
      AudioMessage audioMessage = AudioMessage.from(
        binaryData: audioData.buffer.asUint8List(),
        format: 'mp3',
      );
      // video data
      ByteData videoData = await rootBundle.load('assets/test.mp4');
      // video message
      VideoMessage videoMessage = VideoMessage.from(
        binaryData: videoData.buffer.asUint8List(),
        format: 'mp4',
      );
      // location message
      LocationMessage locationMessage = LocationMessage.from(
        latitude: 22,
        longitude: 33,
      );
      // file message from external url
      FileMessage fileMessage = FileMessage.from(
        url:
            'http://lc-heQFQ0Sw.cn-n1.lcfile.com/167022c1a77143a3aa48464b236fa00d',
        format: 'zip',
      );
      // sent message list
      List<Message> sentMessages = [
        stringMessage,
        binaryMessage,
        textMessage,
        imageMessage,
        audioMessage,
        videoMessage,
        locationMessage,
        fileMessage,
      ];
      // message assertion
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
      }) async {
        client2OnMessageReceivedCount -= 1;
        if (client2OnMessageReceivedCount <= 0) {
          client2.onMessageReceive = null;
        }
        assert(client != null);
        assert(conversation != null);
        assertMessage(message, conversation);
        if (message.stringContent != null) {
          // receive string
          assert(message.stringContent == stringContent);
          decrease(1);
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
        if (client2OnMessageReceivedCount == 0) {
          await delay();
          List<Message> messages1 = await conversation.queryMessage(
            startTimestamp: textMessage.sentTimestamp,
            startMessageId: textMessage.id,
            startClose: true,
            endTimestamp: fileMessage.sentTimestamp,
            endMessageId: fileMessage.id,
            endClose: false,
            direction: 2,
            limit: 100,
          );
          assert(messages1.length == 5);
          messages1.asMap().forEach((index, value) {
            Message sentMessage = sentMessages[index + 2];
            assert(value.sentTimestamp == sentMessage.sentTimestamp);
            assert(value.id == sentMessage.id);
            assert(value.conversationId == sentMessage.conversationId);
            assert(value.fromClientId == sentMessage.fromClientId);
            assert(value.runtimeType == sentMessage.runtimeType);
          });
          List<Message> messages2 = await conversation.queryMessage(
            limit: 1,
            type: -1,
          );
          assert(messages2.length == 1);
          assert(messages2[0] is TextMessage);
          assert(messages2[0].id == textMessage.id);
          assert(messages2[0].sentTimestamp == textMessage.sentTimestamp);
          assert(messages2[0].conversationId == textMessage.conversationId);
          assert(messages2[0].fromClientId == textMessage.fromClientId);
          decrease(1);
        }
      };
      int client2OnConversationLastMessageUpdate = 8;
      client2.onConversationLastMessageUpdate = ({
        Client client,
        Conversation conversation,
      }) {
        client2OnConversationLastMessageUpdate -= 1;
        if (client2OnConversationLastMessageUpdate <= 0) {
          client2.onConversationLastMessageUpdate = null;
        }
        assert(client != null);
        assert(conversation != null);
        assert(conversation.lastMessage != null);
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
      await conversation.send(message: stringMessage);
      assertMessage(stringMessage, conversation);
      assert(stringMessage.stringContent != null);
      // send binary
      await conversation.send(message: binaryMessage);
      assertMessage(binaryMessage, conversation);
      assert(binaryMessage.binaryContent != null);
      // send text
      await conversation.send(message: textMessage);
      assertMessage(textMessage, conversation);
      assert(textMessage.text != null);
      // send image
      await conversation.send(message: imageMessage);
      assertMessage(imageMessage, conversation);
      assertFileMessage(imageMessage);
      assert(imageMessage.width != null);
      assert(imageMessage.height != null);
      // send audio
      await conversation.send(message: audioMessage);
      assertMessage(audioMessage, conversation);
      assertFileMessage(audioMessage);
      assert(audioMessage.duration != null);
      // send video
      await conversation.send(message: videoMessage);
      assertMessage(videoMessage, conversation);
      assertFileMessage(videoMessage);
      assert(videoMessage.duration != null);
      // send location
      await conversation.send(message: locationMessage);
      assertMessage(locationMessage, conversation);
      assert(locationMessage.latitude == 22);
      assert(locationMessage.longitude == 33);
      // send file
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
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // open client 1
      await client1.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: [client1.id, client2.id],
      );
      // send
      Message message = Message();
      message.stringContent = uuid();
      message.mentionMembers = [client2.id];
      message.mentionAll = true;
      await conversation.send(message: message);
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
        assert(client != null);
        assert(conversation != null);
        if (conversation.unreadMessageCount == 1) {
          assert(conversation.unreadMessageContainMention == true);
          conversation.unreadMessageContainMention = false;
          conversation.read();
          decrease(1);
        } else if (conversation.unreadMessageCount == 0) {
          decrease(1);
        }
      };
      client2.onConversationLastMessageUpdate = ({
        Client client,
        Conversation conversation,
      }) {
        client2.onConversationLastMessageUpdate = null;
        assert(client != null);
        assert(conversation != null);
        Message lastMessage = conversation.lastMessage;
        assert(lastMessage != null);
        assert(lastMessage.id == message.id);
        assert(lastMessage.sentTimestamp == message.sentTimestamp);
        assert(lastMessage.conversationId == message.conversationId);
        decrease(1);
      };
      // open client 2
      await client2.open();
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard updateMessage = UnitTestCaseCard(
    title: 'Case: Update Message',
    extraExpectedCount: 1,
    testCaseFunc: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // old message
      Message oldMessage = Message();
      oldMessage.stringContent = uuid();
      // new message
      ByteData imageData = await rootBundle.load('assets/test.jpg');
      ImageMessage newMessage = ImageMessage.from(
        binaryData: imageData.buffer.asUint8List(),
        format: 'jpg',
        name: 'test.jpg',
      );
      // event
      client2.onMessageUpdate = ({
        Client client,
        Conversation conversation,
        Message message,
        int patchCode,
        String patchReason,
      }) {
        client2.onMessageUpdate = null;
        assert(message.id == newMessage.id);
        assert(message.sentTimestamp == newMessage.sentTimestamp);
        assert(message.conversationId == newMessage.conversationId);
        assert(message.fromClientId == newMessage.fromClientId);
        assert(message.patchedTimestamp == newMessage.patchedTimestamp);
        assert(message is ImageMessage);
        if (message is ImageMessage) {
          assert(message.url == newMessage.url);
        }
        decrease(1);
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: [client1.id, client2.id],
      );
      // send
      await conversation.send(message: oldMessage);
      // update
      await conversation.updateMessage(
        oldMessage: oldMessage,
        newMessage: newMessage,
      );
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard messageReceipt = UnitTestCaseCard(
    title: 'Case: Message Receipt',
    extraExpectedCount: 4,
    testCaseFunc: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // message
      Message message = Message();
      message.stringContent = uuid();
      // event
      int client1OnMessageReceipt = 2;
      int maxReadTimestamp;
      int maxDeliveredTimestamp;
      client1.onMessageReceipt = ({
        Client client,
        Conversation conversation,
        String messageId,
        int timestamp,
        String byClientId,
        bool isRead,
      }) async {
        client1OnMessageReceipt -= 1;
        if (client1OnMessageReceipt <= 0) {
          client1.onMessageReceipt = null;
        }
        assert(client != null);
        assert(conversation != null);
        assert(messageId == message.id);
        assert(timestamp >= message.sentTimestamp);
        assert(byClientId == client2.id);
        if (isRead) {
          maxReadTimestamp = timestamp;
        } else {
          maxDeliveredTimestamp = timestamp;
        }
        decrease(1);
        if (client1OnMessageReceipt == 0) {
          Map rcp = await conversation.getMessageReceipt();
          assert(maxReadTimestamp != null);
          assert(maxDeliveredTimestamp != null);
          assert(rcp['maxReadTimestamp'] is int);
          assert(rcp['maxDeliveredTimestamp'] is int);
          decrease(1);
        }
      };
      client2.onConversationLastMessageUpdate = ({
        Client client,
        Conversation conversation,
      }) {
        client2.onConversationLastMessageUpdate = null;
        assert(client != null);
        assert(conversation != null);
        conversation.read();
        decrease(1);
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: [client1.id, client2.id],
      );
      // send
      await conversation.send(
        message: message,
        receipt: true,
      );
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard muteConversation = UnitTestCaseCard(
    title: 'Case: Mute Conversation',
    testCaseFunc: (decrease) async {
      // client
      Client client = Client(id: uuid());
      // open
      await client.open();
      // create
      Conversation conversation = await client.createConversation(
        members: [client.id, uuid()],
      );
      // mute
      await conversation.muteToggle(op: 'mute');
      assert(conversation.rawData['mu'].contains(client.id));
      String updatedAt = conversation.rawData['updatedAt'];
      assert(updatedAt != null);
      // unmute
      await conversation.muteToggle(op: 'unmute');
      assert(conversation.rawData['mu'].contains(client.id) == false);
      assert(conversation.rawData['updatedAt'] is String);
      assert(conversation.rawData['updatedAt'] != updatedAt);
      // recycle
      return [client];
    });

UnitTestCaseCard updateConversation = UnitTestCaseCard(
    title: 'Case: Update Conversation',
    extraExpectedCount: 1,
    testCaseFunc: (decrease) async {
      String setValue = uuid();
      String unsetValue = uuid();
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      client2.onConversationDataUpdate = ({
        Client client,
        Conversation conversation,
        Map updatingAttributes,
        Map updatedAttributes,
        String byClientId,
        String atDate,
      }) {
        client2.onConversationDataUpdate = null;
        assert(client != null);
        assert(conversation != null);
        assert(byClientId == client1.id);
        assert(atDate != null);
        assert(updatingAttributes.length == 2);
        assert(updatingAttributes['attr.set'] == setValue);
        assert(updatingAttributes['attr.unset']['__op'] == 'Delete');
        assert(updatedAttributes['attr']['set'] == setValue);
        assert(updatedAttributes['attr']['unset'] == null);
        assert(conversation.rawData['attr']['set'] == setValue);
        assert(conversation.rawData['attr']['unset'] == null);
        decrease(1);
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: [client1.id, client2.id],
        attributes: {'unset': unsetValue},
      );
      assert(conversation.rawData['attr']['unset'] == unsetValue);
      await delay();
      await client2.close();
      await delay();
      await conversation.update(data: {
        'attr.set': setValue,
        'attr.unset': {'__op': 'Delete'},
      });
      assert(conversation.rawData['attr']['set'] == setValue);
      assert(conversation.rawData['attr']['unset'] == null);
      await delay();
      await client2.open();
      // recycle
      return [client1, client2];
    });

UnitTestCaseCard queryConversation = UnitTestCaseCard(
    title: 'Case: Query Conversation',
    testCaseFunc: (decrease) async {
      // client
      String clientId = uuid();
      Client client = Client(id: clientId);
      // open
      await client.open();
      // create unique
      await client.createConversation(
        type: ConversationType.normalUnique,
        members: [clientId, uuid()],
      );
      // create non-unique
      Conversation nonUniqueConversation = await client.createConversation(
        type: ConversationType.normal,
        members: [clientId, uuid()],
      );
      List<Conversation> conversations = await client.queryConversation(
        where: '{\"m\":\"$clientId\"}',
        sort: 'createdAt',
        limit: 1,
        skip: 1,
        flag: 1,
      );
      assert(conversations.length == 1);
      assert(conversations[0].id == nonUniqueConversation.id);
      assert(conversations[0].rawData['m'] == null);
      // recycle
      return [client];
    });

class _MyAppState extends State<MyApp> {
  List<UnitTestCaseCard> cases = [
    clientOpenThenClose,
    createUniqueConversationAndCountMember,
    createNonUniqueConversationAndUpdateMember,
    createTransientConversationAndCountMember,
    createAndQueryTemporaryConversation,
    sendAndQueryMessage,
    readMessage,
    // updateMessage,
    messageReceipt,
    muteConversation,
    updateConversation,
    queryConversation,
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
  final UnitTestCaseState state;

  UnitTestCaseCard({
    @required title,
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
