import 'dart:async';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leancloud_plugin/leancloud_plugin.dart';

void main() => runApp(MyApp());

String uuid() => Uuid().generateV4();

Future<void> delay({
  int seconds = 3,
}) async {
  print(
      '\n\n------ Flutter Plugin Unit Test Delay\nwait for $seconds seconds.\n------\n');
  await Future.delayed(Duration(seconds: seconds));
}

void logException(dynamic e, {String title}) {
  if (title == null) {
    print('[⁉️][Exception]: $e');
  } else {
    print('[⁉️][Exception][$title]: $e');
  }
}

UnitTestCase clientOpenThenClose() => UnitTestCase(
    title: 'Case: Client Open then Close',
    testingLogic: (decrease) async {
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

UnitTestCase createUniqueConversationAndCountMember() => UnitTestCase(
    title: 'Case: Create Unique Conversation & Count Member',
    extraExpectedCount: 4,
    testingLogic: (decrease) async {
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
        try {
          client1.onConversationInvite = null;
          assert(client != null);
          assert(conversation != null);
          assert(byClientId == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client1.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        try {
          client1.onConversationMembersJoin = null;
          assert(client != null);
          assert(conversation != null);
          assert(members.length == 2);
          assert(members.contains(client1.id));
          assert(members.contains(client2.id));
          assert(byClientId == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) {
        try {
          client2.onConversationInvite = null;
          assert(client != null);
          assert(conversation != null);
          assert(byClientId == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client2.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        try {
          client2.onConversationMembersJoin = null;
          assert(client != null);
          assert(conversation != null);
          assert(members.length == 2);
          assert(members.contains(client1.id));
          assert(members.contains(client2.id));
          assert(byClientId == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
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

UnitTestCase createNonUniqueConversationAndUpdateMember() => UnitTestCase(
    title: 'Case: Create Non-Unique Conversation & Update Member',
    extraExpectedCount: 17,
    testingLogic: (decrease) async {
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
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client1.onConversationKick = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) async {
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      int client1OnConversationMembersJoin = 3;
      client1.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) async {
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client1.onConversationMembersLeave = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) {
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      int client2OnConversationMembersJoin = 3;
      client2.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
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
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
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
      await delay();
      return [client1, client2];
    });

UnitTestCase createTransientConversationAndCountMember() => UnitTestCase(
    title: 'Case: Create Transient Conversation & Count Member',
    testingLogic: (decrease) async {
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
      await delay();
      int count = await conversation.countMembers();
      assert(count == 1);
      // recycle
      return [client];
    });

UnitTestCase createAndQueryTemporaryConversation() => UnitTestCase(
    title: 'Case: Create & Query Temporary Conversation',
    extraExpectedCount: 4,
    testingLogic: (decrease) async {
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
        try {
          client1.onConversationInvite = null;
          assert(client != null);
          assert(conversation != null);
          assert(byClientId == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client1.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        try {
          client1.onConversationMembersJoin = null;
          assert(client != null);
          assert(conversation != null);
          assert(members.length == 2);
          assert(members.contains(client1.id));
          assert(members.contains(client2.id));
          assert(byClientId == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client2.onConversationInvite = ({
        Client client,
        Conversation conversation,
        String byClientId,
        String atDate,
      }) {
        try {
          client2.onConversationInvite = null;
          assert(client != null);
          assert(conversation != null);
          assert(byClientId == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client2.onConversationMembersJoin = ({
        Client client,
        Conversation conversation,
        List members,
        String byClientId,
        String atDate,
      }) {
        try {
          client2.onConversationMembersJoin = null;
          assert(client != null);
          assert(conversation != null);
          assert(members.length == 2);
          assert(members.contains(client1.id));
          assert(members.contains(client2.id));
          assert(byClientId == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
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

UnitTestCase sendAndQueryMessage() => UnitTestCase(
    title: 'Case: Send & Query Message',
    extraExpectedCount: 17,
    testingLogic: (decrease) async {
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
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      int client2OnConversationLastMessageUpdate = 8;
      client2.onConversationLastMessageUpdate = ({
        Client client,
        Conversation conversation,
      }) {
        try {
          client2OnConversationLastMessageUpdate -= 1;
          if (client2OnConversationLastMessageUpdate <= 0) {
            client2.onConversationLastMessageUpdate = null;
          }
          assert(client != null);
          assert(conversation != null);
          assert(conversation.lastMessage != null);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
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
      await delay();
      return [client1, client2];
    });

UnitTestCase readMessage() => UnitTestCase(
    title: 'Case: Read Message',
    extraExpectedCount: 3,
    testingLogic: (decrease) async {
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
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client2.onConversationLastMessageUpdate = ({
        Client client,
        Conversation conversation,
      }) {
        try {
          client2.onConversationLastMessageUpdate = null;
          assert(client != null);
          assert(conversation != null);
          Message lastMessage = conversation.lastMessage;
          assert(lastMessage != null);
          assert(lastMessage.id == message.id);
          assert(lastMessage.sentTimestamp == message.sentTimestamp);
          assert(lastMessage.conversationId == message.conversationId);
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      // open client 2
      await client2.open();
      // recycle
      return [client1, client2];
    });

UnitTestCase updateMessage() => UnitTestCase(
    title: 'Case: Update Message',
    extraExpectedCount: 1,
    testingLogic: (decrease) async {
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
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
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

UnitTestCase messageReceipt() => UnitTestCase(
    title: 'Case: Message Receipt',
    extraExpectedCount: 4,
    testingLogic: (decrease) async {
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
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
      };
      client2.onConversationLastMessageUpdate = ({
        Client client,
        Conversation conversation,
      }) async {
        try {
          client2.onConversationLastMessageUpdate = null;
          assert(client != null);
          assert(conversation != null);
          await delay();
          conversation.read();
          decrease(1);
        } catch (e) {
          logException(e);
          decrease(-1);
        }
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
      await delay(seconds: 5);
      return [client1, client2];
    });

UnitTestCase muteConversation() => UnitTestCase(
    title: 'Case: Mute Conversation',
    testingLogic: (decrease) async {
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

UnitTestCase updateConversation() => UnitTestCase(
    title: 'Case: Update Conversation',
    extraExpectedCount: 1,
    testingLogic: (decrease) async {
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
        try {
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
        } catch (e) {
          logException(e);
          decrease(-1);
        }
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

UnitTestCase queryConversation() => UnitTestCase(
    title: 'Case: Query Conversation',
    testingLogic: (decrease) async {
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

class UnitTestCase {
  final String title;
  final int expectedCount;
  final int timeout;
  final Future<List<Client>> Function(void Function(int)) testingLogic;

  void Function(int) stateCountWillChange;
  void Function(int) stateCountDidChange;

  int _stateCount;
  int get stateCount => this._stateCount;
  set stateCount(int value) {
    this._stateCount = value;
    if (this.stateCountDidChange != null) {
      this.stateCountDidChange(value);
      if (value <= 0 && this._timer != null) {
        this._timer.cancel();
        this._timer = null;
      }
    }
  }

  List<Client> _clients = [];
  Timer _timer;

  UnitTestCase({
    @required this.title,
    int extraExpectedCount = 0,
    int timeout = 60,
    @required this.testingLogic,
  })  : assert(title != null),
        this.expectedCount = (extraExpectedCount + 2),
        this.timeout = timeout {
    this._stateCount = this.expectedCount;
  }

  Future<void> run({
    void Function(int) stateCountDidChange,
  }) async {
    this.stateCountDidChange = stateCountDidChange;
    this.stateCountWillChange(this.expectedCount - 1);
    if (this._timer != null) {
      this._timer.cancel();
      this._timer = null;
    }
    if (this.timeout > 0) {
      this._timer = Timer(Duration(seconds: this.timeout), () {
        this._timer = null;
        if (this._stateCount > 0) {
          logException('Timeout', title: this.title);
          this.stateCountWillChange(-1);
          this.tearDown();
        }
      });
    }
    bool hasException = false;
    try {
      this._clients = await this.testingLogic((int count) {
        if (count > 0) {
          this.stateCountWillChange(this._stateCount - count);
        } else {
          this.stateCountWillChange(-1);
        }
        this.tearDown();
      });
    } catch (e) {
      logException(e, title: this.title);
      hasException = true;
    }
    if (hasException) {
      this.stateCountWillChange(-1);
    } else {
      this.stateCountWillChange(this._stateCount - 1);
    }
    this.tearDown();
  }

  void tearDown() {
    if (this._stateCount <= 0) {
      this._clients.forEach((item) {
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
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<UnitTestCase> unitCases = [
    clientOpenThenClose(),
    createUniqueConversationAndCountMember(),
    createNonUniqueConversationAndUpdateMember(),
    createTransientConversationAndCountMember(),
    createAndQueryTemporaryConversation(),
    sendAndQueryMessage(),
    readMessage(),
    // updateMessage(),
    messageReceipt(),
    muteConversation(),
    updateConversation(),
    queryConversation(),
  ];
  List<UnitTestCase> signatureUnitCases = [];
  List<UnitTestCase> allUnitCases = [];

  @override
  void initState() {
    super.initState();
    this.allUnitCases = [
          UnitTestCase(
              title: 'Run all unit cases',
              extraExpectedCount: this.unitCases.length,
              timeout: 0,
              testingLogic: (decrease) async {
                for (var i = 0; i < this.unitCases.length; i++) {
                  await this.unitCases[i].run(stateCountDidChange: (count) {
                    if (count == 0) {
                      decrease(1);
                    } else if (count < 0) {
                      decrease(-1);
                    }
                  });
                }
                return [];
              }),
        ] +
        this.unitCases +
        [
          // UnitTestCase(
          //     title: 'Run all signature unit cases',
          //     extraExpectedCount: this.signatureUnitCases.length,
          //     timeout: 0,
          //     testingLogic: (decrease) async {
          //       for (var i = 0; i < this.signatureUnitCases.length; i++) {
          //         await this.signatureUnitCases[i].run(
          //             stateCountDidChange: (count) {
          //           if (count == 0) {
          //             decrease(1);
          //           } else if (count < 0) {
          //             decrease(-1);
          //           }
          //         });
          //       }
          //       return [];
          //     }),
        ] +
        this.signatureUnitCases;
    this.allUnitCases.forEach((item) {
      item.stateCountWillChange = (count) {
        this.setState(() {
          item.stateCount = count;
        });
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin Unit Test Cases'),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: this.allUnitCases.length,
          itemBuilder: (context, index) {
            return UnitTestCaseCard(model: this.allUnitCases[index]);
          },
        ),
      ),
    );
  }
}

class UnitTestCaseCard extends StatefulWidget {
  final UnitTestCase model;

  UnitTestCaseCard({
    @required this.model,
  }) : assert(model != null);

  @override
  UnitTestCaseCardState createState() =>
      UnitTestCaseCardState(model: this.model);
}

class UnitTestCaseCardState extends State<UnitTestCaseCard> {
  final UnitTestCase model;

  UnitTestCaseCardState({
    @required this.model,
  }) : assert(model != null);

  @override
  Widget build(BuildContext context) {
    return Card(
        child: ListTile(
            title: Text(
                (this.model.stateCount == this.model.expectedCount
                        ? ''
                        : (this.model.stateCount == 0
                            ? '✅ '
                            : (this.model.stateCount <= -1 ? '❌ ' : '💤 '))) +
                    this.model.title,
                style: TextStyle(
                    color: (this.model.stateCount == this.model.expectedCount)
                        ? Colors.black
                        : ((this.model.stateCount == 0)
                            ? Colors.green
                            : ((this.model.stateCount <= -1)
                                ? Colors.red
                                : Colors.blue)),
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold)),
            onTap: () async {
              if (this.model.stateCount == this.model.expectedCount ||
                  this.model.stateCount <= 0) {
                await this.model.run();
              }
            }));
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
