import 'dart:async';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:leancloud_official_plugin/leancloud_plugin.dart';

void main() => runApp(MyApp());

String uuid() => Uuid().generateV4();

Future<void> delay({
  int seconds = 3,
}) async {
  print(
      '\n\n------ Flutter Plugin Unit Test Delay\nwait for $seconds seconds.\n------\n');
  await Future.delayed(Duration(seconds: seconds));
}

void logException(dynamic e, {String? title}) {
  if (title == null) {
    print('[⁉️][Exception]: $e');
  } else {
    print('[⁉️][Exception][$title]: $e');
  }
}

class RegisteredMessage extends TypedMessage {
  @override
  int get type => 1;

  RegisteredMessage() : super();
}

class UnregisteredMessage extends TypedMessage {
  @override
  int get type => 2;

  UnregisteredMessage() : super();
}

UnitTestCase clientOpenThenClose() => UnitTestCase(
    title: 'Case: Client Open then Close',
    testingLogic: (decrease) async {
      // client
      Client client = Client(id: uuid());
      // open
      await client.open();
      assert(client.tag == null);
      // close
      await client.close();
      // reopen
      await client.open();
      // recycle
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
      client1.onInvited = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onInvited = null;
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client1.onMembersJoined = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onMembersJoined = null;
          assert(members!.length == 2);
          assert(members!.contains(client1.id));
          assert(members!.contains(client2.id));
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onInvited = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onInvited = null;
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onMembersJoined = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onMembersJoined = null;
          assert(members!.length == 2);
          assert(members!.contains(client1.id));
          assert(members!.contains(client2.id));
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open
      await client1.open();
      await client2.open();
      // create unique conversation
      Conversation conversation1 = await client1.createConversation(
        members: {client1.id, client2.id},
      );
      assert(conversation1.rawData['conv_type'] == 1);
      assert(conversation1.uniqueID != null);
      assert(conversation1.members!.length == 2);
      assert(conversation1.members!.contains(client1.id));
      assert(conversation1.members!.contains(client2.id));
      assert(conversation1.isUnique == true);
      assert(conversation1.name == null);
      assert(conversation1.attributes == null);
      assert(conversation1.creator == client1.id);
      assert(conversation1.createdAt != null);
      // query unique conversation from creation
      String name = uuid();
      String attrKey = uuid();
      String attrValue = uuid();
      Conversation conversation2 = await client1.createConversation(
        members: {client1.id, client2.id},
        name: name,
        attributes: {attrKey: attrValue},
      );
      assert(conversation2 == conversation1);
      assert(conversation2.rawData['conv_type'] == 1);
      assert(conversation2.id == conversation1.id);
      assert(conversation2.uniqueID == conversation1.uniqueID);
      assert(conversation2.members!.length == 2);
      assert(conversation2.members!.contains(client1.id));
      assert(conversation2.members!.contains(client2.id));
      assert(conversation2.isUnique == true);
      assert(conversation2.name == name);
      assert(conversation2.attributes!.length == 1);
      assert(conversation2.attributes![attrKey] == attrValue);
      assert(conversation2.creator == client1.id);
      assert(conversation2.createdAt == conversation1.createdAt);
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
      Client client0 = Client(id: uuid());
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      String client3id = uuid();
      // event
      int client1OnConversationInvite = 2;
      client1.onInvited = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) async {
        try {
          client1OnConversationInvite -= 1;
          if (client1OnConversationInvite <= 0) {
            client1.onInvited = null;
          }
          assert(atDate != null);
          assert(conversation.members!.length == 3);
          assert(conversation.members!.contains(client0.id));
          assert(conversation.members!.contains(client1.id));
          assert(conversation.members!.contains(client2.id));
          if (client1OnConversationInvite == 1) {
            // join by create
            assert(byClientID == client0.id);
            decrease(1);
          } else if (client1OnConversationInvite == 0) {
            // rejoin
            assert(byClientID == client1.id);
            decrease(1);
          }
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client1.onKicked = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) async {
        try {
          client1.onKicked = null;
          assert(byClientID == client1.id);
          assert(atDate != null);
          assert(conversation.members!.length == 2);
          assert(conversation.members!.contains(client0.id));
          assert(conversation.members!.contains(client2.id));
          decrease(1);
          MemberResult joinResult = await conversation.join();
          assert(joinResult.allSucceeded);
          assert(joinResult.succeededMembers.length == 1);
          assert(joinResult.succeededMembers.contains(client1.id));
          assert(conversation.members!.length == 3);
          assert(conversation.members!.contains(client0.id));
          assert(conversation.members!.contains(client1.id));
          assert(conversation.members!.contains(client2.id));
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      int client1OnConversationMembersJoin = 3;
      client1.onMembersJoined = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) async {
        try {
          client1OnConversationMembersJoin -= 1;
          if (client1OnConversationMembersJoin <= 0) {
            client1.onMembersJoined = null;
          }
          assert(atDate != null);
          if (client1OnConversationMembersJoin == 2) {
            // join by create
            assert(byClientID == client0.id);
            assert(members!.length == 3);
            assert(members!.contains(client0.id));
            assert(members!.contains(client1.id));
            assert(members!.contains(client2.id));
            assert(conversation.members!.length == 3);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client1.id));
            assert(conversation.members!.contains(client2.id));
            decrease(1);
          } else if (client1OnConversationMembersJoin == 1) {
            // rejoin
            assert(byClientID == client1.id);
            assert(members!.length == 1);
            assert(members!.contains(client1.id));
            assert(conversation.members!.length == 3);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client1.id));
            assert(conversation.members!.contains(client2.id));
            decrease(1);
          } else if (client1OnConversationMembersJoin == 0) {
            // add new member
            assert(byClientID == client1.id);
            assert(members!.length == 1);
            assert(members!.contains(client3id));
            assert(conversation.members!.length == 4);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client1.id));
            assert(conversation.members!.contains(client2.id));
            assert(conversation.members!.contains(client3id));
            decrease(1);
          }
          if (client1OnConversationMembersJoin == 2) {
            MemberResult quitResult = await conversation.quit();
            assert(quitResult.allSucceeded);
            assert(quitResult.succeededMembers.length == 1);
            assert(quitResult.succeededMembers.contains(client1.id));
            assert(conversation.members!.length == 2);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client2.id));
            decrease(1);
          } else if (client1OnConversationMembersJoin == 1) {
            MemberResult addMemberResult = await conversation.addMembers(
              members: {client3id},
            );
            assert(addMemberResult.allSucceeded);
            assert(addMemberResult.succeededMembers.length == 1);
            assert(addMemberResult.succeededMembers.contains(client3id));
            assert(conversation.members!.length == 4);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client1.id));
            assert(conversation.members!.contains(client2.id));
            assert(conversation.members!.contains(client3id));
            decrease(1);
          } else if (client1OnConversationMembersJoin == 0) {
            Conversation conversation0 =
                client0.conversationMap[conversation.id]!;
            MemberResult removeMemberResult = await conversation0.removeMembers(
              members: {client3id},
            );
            assert(removeMemberResult.allSucceeded);
            assert(removeMemberResult.succeededMembers.length == 1);
            assert(removeMemberResult.succeededMembers.contains(client3id));
            assert(conversation0.members!.length == 3);
            assert(conversation0.members!.contains(client0.id));
            assert(conversation0.members!.contains(client1.id));
            assert(conversation0.members!.contains(client2.id));
            decrease(1);
          }
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client1.onMembersLeft = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onMembersLeft = null;
          assert(byClientID == client0.id);
          assert(atDate != null);
          assert(members!.length == 1);
          assert(members!.contains(client3id));
          assert(conversation.members!.length == 3);
          assert(conversation.members!.contains(client0.id));
          assert(conversation.members!.contains(client1.id));
          assert(conversation.members!.contains(client2.id));
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onInvited = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onInvited = null;
          assert(byClientID == client0.id);
          assert(atDate != null);
          assert(conversation.members!.length == 3);
          assert(conversation.members!.contains(client0.id));
          assert(conversation.members!.contains(client1.id));
          assert(conversation.members!.contains(client2.id));
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      int client2OnConversationMembersJoin = 3;
      client2.onMembersJoined = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2OnConversationMembersJoin -= 1;
          if (client2OnConversationMembersJoin <= 0) {
            client2.onMembersJoined = null;
          }
          assert(atDate != null);
          if (client2OnConversationMembersJoin == 2) {
            // join by create
            assert(byClientID == client0.id);
            assert(members!.length == 3);
            assert(members!.contains(client0.id));
            assert(members!.contains(client1.id));
            assert(members!.contains(client2.id));
            assert(conversation.members!.length == 3);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client1.id));
            assert(conversation.members!.contains(client2.id));
            decrease(1);
          } else if (client2OnConversationMembersJoin == 1) {
            // rejoin
            assert(byClientID == client1.id);
            assert(members!.length == 1);
            assert(members!.contains(client1.id));
            assert(conversation.members!.length == 3);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client1.id));
            assert(conversation.members!.contains(client2.id));
            decrease(1);
          } else if (client2OnConversationMembersJoin == 0) {
            // add new member
            assert(byClientID == client1.id);
            assert(members!.length == 1);
            assert(members!.contains(client3id));
            assert(conversation.members!.length == 4);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client1.id));
            assert(conversation.members!.contains(client2.id));
            assert(conversation.members!.contains(client3id));
            decrease(1);
          }
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      int client2OnConversationMembersLeave = 2;
      client2.onMembersLeft = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2OnConversationMembersLeave -= 1;
          if (client2OnConversationMembersLeave <= 0) {
            client2.onMembersLeft = null;
          }
          assert(atDate != null);
          if (client2OnConversationMembersLeave == 1) {
            // leave
            assert(byClientID == client1.id);
            assert(members!.length == 1);
            assert(members!.contains(client1.id));
            assert(conversation.members!.length == 2);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client2.id));
            decrease(1);
          } else if (client2OnConversationMembersLeave == 0) {
            // remove new member
            assert(byClientID == client0.id);
            assert(members!.length == 1);
            assert(members!.contains(client3id));
            assert(conversation.members!.length == 3);
            assert(conversation.members!.contains(client0.id));
            assert(conversation.members!.contains(client1.id));
            assert(conversation.members!.contains(client2.id));
            decrease(1);
          }
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open
      await client0.open();
      await client1.open();
      await client2.open();
      // create non-unique conversation
      String name = uuid();
      String attrKey = uuid();
      String attrValue = uuid();
      Conversation conversation = await client0.createConversation(
        isUnique: false,
        members: {client1.id, client2.id},
        name: name,
        attributes: {attrKey: attrValue},
      );
      assert(conversation.rawData['conv_type'] == 1);
      assert(conversation.members!.length == 3);
      assert(conversation.members!.contains(client0.id));
      assert(conversation.members!.contains(client1.id));
      assert(conversation.members!.contains(client2.id));
      assert(conversation.isUnique == false);
      assert(conversation.name == name);
      assert(conversation.attributes!.length == 1);
      assert(conversation.attributes![attrKey] == attrValue);
      assert(conversation.creator == client0.id);
      assert(conversation.createdAt != null);
      // recycle
      await delay();
      return [client0, client1, client2];
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
      ChatRoom chatRoom = await client.createChatRoom(
        name: name,
        attributes: {attrKey: attrValue},
      );
      assert(chatRoom.rawData['conv_type'] == 2);
      assert(chatRoom.name == name);
      assert(chatRoom.attributes!.length == 1);
      assert(chatRoom.attributes![attrKey] == attrValue);
      assert(chatRoom.creator == client.id);
      assert(chatRoom.createdAt != null);
      await delay();
      int count = await chatRoom.countMembers();
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
      client1.onInvited = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onInvited = null;
          assert(conversation is TemporaryConversation);
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client1.onMembersJoined = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onMembersJoined = null;
          assert(conversation is TemporaryConversation);
          assert(members!.length == 2);
          assert(members!.contains(client1.id));
          assert(members!.contains(client2.id));
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onInvited = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onInvited = null;
          assert(conversation is TemporaryConversation);
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onMembersJoined = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onMembersJoined = null;
          assert(conversation is TemporaryConversation);
          assert(members!.length == 2);
          assert(members!.contains(client1.id));
          assert(members!.contains(client2.id));
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open
      await client1.open();
      await client2.open();
      // create temporary conversation
      TemporaryConversation temporaryConversation =
          await client1.createTemporaryConversation(
        members: {client1.id, client2.id},
        timeToLive: 3600,
      );
      assert(temporaryConversation.rawData['conv_type'] == 4);
      assert(temporaryConversation.id.startsWith('_tmp:'));
      assert(temporaryConversation.members!.length == 2);
      assert(temporaryConversation.members!.contains(client1.id));
      assert(temporaryConversation.members!.contains(client2.id));
      assert(temporaryConversation.timeToLive == 3600);
      List<TemporaryConversation> temporaryConversations =
          await client2.conversationQuery().findTemporaryConversations(
        temporaryConversationIDs: [temporaryConversation.id],
      );
      assert(temporaryConversations.length == 1);
      assert(temporaryConversations[0].id == temporaryConversation.id);
      // recycle
      return [client1, client2];
    });

UnitTestCase sendAndQueryMessage() => UnitTestCase(
    title: 'Case: Send & Query Message',
    extraExpectedCount: 9,
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
        assert(message.conversationID == conversation.id);
        assert(message.fromClientID == client1.id);
        assert(MessageStatus.values.indexOf(message.status) >=
            MessageStatus.sent.index);
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
      client2.onMessage = ({
        required Client client,
        required Conversation conversation,
        required Message message,
      }) async {
        try {
          client2OnMessageReceivedCount -= 1;
          if (client2OnMessageReceivedCount <= 0) {
            client2.onMessage = null;
          }
          assertMessage(message, conversation);
          if (message.stringContent != null) {
            // receive string
            assert(message.stringContent == stringContent);
            decrease(1);
          } else if (message.binaryContent != null) {
            // receive binary
            int index = 0;
            message.binaryContent!.forEach((item) {
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
            assert(message.url!.endsWith('/image.png'));
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
              startMessageID: textMessage.id,
              startClosed: true,
              endTimestamp: fileMessage.sentTimestamp,
              endMessageID: fileMessage.id,
              endClosed: false,
              direction: MessageQueryDirection.oldToNew,
              limit: 100,
            );
            assert(messages1.length == 5);
            messages1.asMap().forEach((index, value) {
              Message sentMessage = sentMessages[index + 2];
              assert(value.sentTimestamp == sentMessage.sentTimestamp);
              assert(value.id == sentMessage.id);
              assert(value.conversationID == sentMessage.conversationID);
              assert(value.fromClientID == sentMessage.fromClientID);
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
            assert(messages2[0].conversationID == textMessage.conversationID);
            assert(messages2[0].fromClientID == textMessage.fromClientID);
            decrease(1);
          }
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id},
      );
      // send string
      assert(stringMessage.status == MessageStatus.none);
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

UnitTestCase sendAndReceiveCustomMessage() => UnitTestCase(
    title: 'Case: Send & Receive Custom Message',
    extraExpectedCount: 2,
    testingLogic: (decrease) async {
      // register custom message
      TypedMessage.register(() => RegisteredMessage());
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      int client2OnMessageCount = 2;
      client2.onMessage = ({
        required Client client,
        required Conversation conversation,
        required Message message,
      }) {
        try {
          client2OnMessageCount -= 1;
          if (client2OnMessageCount <= 0) {
            client2.onMessage = null;
          }
          assert(conversation.lastMessageTimestamp != null);
          assert(conversation.lastMessageTimestamp! > 0);
          assert(conversation.lastMessageDate != null);
          if (client2OnMessageCount == 1) {
            assert(message.runtimeType == RegisteredMessage);
            decrease(1);
          } else if (client2OnMessageCount == 0) {
            assert(message.runtimeType == Message);
            assert(message.stringContent != null);
            assert(message.stringContent!.contains('_lctype'));
            decrease(1);
          }
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open clients
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id},
      );
      await delay();
      // send registered custom message
      RegisteredMessage registeredMessage = RegisteredMessage();
      registeredMessage.text = uuid();
      registeredMessage.attributes = {"random": uuid()};
      await conversation.send(message: registeredMessage);
      // send unregistered custom message
      UnregisteredMessage unregisteredMessage = UnregisteredMessage();
      unregisteredMessage.text = uuid();
      unregisteredMessage.attributes = {"random": uuid()};
      await conversation.send(message: unregisteredMessage);

      // recycle
      return [client1, client2];
    });

UnitTestCase sendMessageToUnrelatedConversation() => UnitTestCase(
    title: 'Case: Send Message to Unrelated Conversation',
    extraExpectedCount: 1,
    testingLogic: (decrease) async {
      // client
      Client client0 = Client(id: uuid());
      Client client1 = Client(id: uuid());
      // open
      await client0.open();
      await client1.open();
      // create conversation
      Conversation conversation = await client0.createConversation(
        members: {client1.id, uuid()},
      );
      await delay();
      Conversation conversation1 = client1.conversationMap[conversation.id]!;
      // quit
      MemberResult result = await conversation1.quit();
      assert(result.allSucceeded);
      // send message
      TextMessage textMessage = TextMessage();
      textMessage.text = uuid();
      try {
        await conversation1.send(message: textMessage);
      } catch (e) {
        decrease(1);
        assert(e is RTMException);
      }
      // recycle
      return [client1];
    });

UnitTestCase sendAndReceiveTransientMessage() => UnitTestCase(
    title: 'Case: Send & Receive Transient Message',
    extraExpectedCount: 1,
    testingLogic: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // event
      client2.onUnreadMessageCountUpdated = ({
        required Client client,
        required Conversation conversation,
      }) {
        throw Exception("should never happen");
      };
      client2.onMessage = ({
        required Client client,
        required Conversation conversation,
        required Message message,
      }) {
        try {
          client2.onMessage = null;
          if (Platform.isIOS) {
            // In Java/Android SDK, transient is not message's character, it is just an option of send action,
            // with transient option, RTM server can deliver the message as many as possible, even dropping the message at all is allowed.
            // From the client perspective, developer could not do any thing else for a 'transient' message,
            // he should use message type to distinguish different purposes.
            assert(conversation.lastMessage == null);
            assert(message.isTransient);
          }
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open clients
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id},
      );
      // send transient custom message
      Message transientMessage = Message();
      transientMessage.stringContent = uuid();
      await conversation.send(
        message: transientMessage,
        transient: true,
      );
      if (Platform.isIOS) {
        assert(transientMessage.isTransient);
        assert(conversation.lastMessage == null);
      }
      // recycle
      return [client1, client2];
    });

UnitTestCase readMessage() => UnitTestCase(
    title: 'Case: Read Message',
    extraExpectedCount: 4,
    testingLogic: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // open client 1
      await client1.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id},
      );
      await delay();
      // send
      Message message = Message();
      message.stringContent = uuid();
      message.mentionMembers = [client2.id];
      message.mentionAll = true;
      await conversation.send(message: message);
      await delay();
      // event
      client1.onUnreadMessageCountUpdated = ({
        required Client client,
        required Conversation conversation,
      }) {
        try {
          assert(conversation.unreadMessageCount == 1);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client1.onMessage = ({
        required Client client,
        required Conversation conversation,
        required Message message,
      }) {
        try {
          assert(conversation.unreadMessageCount == 1);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      int client2OnConversationUnreadMessageCountUpdateCount = 2;
      client2.onUnreadMessageCountUpdated = ({
        required Client client,
        required Conversation conversation,
      }) async {
        try {
          client2OnConversationUnreadMessageCountUpdateCount -= 1;
          if (client2OnConversationUnreadMessageCountUpdateCount <= 0) {
            client2.onUnreadMessageCountUpdated = null;
          }
          if (conversation.unreadMessageCount == 1) {
            assert(conversation.unreadMessageMentioned == true);
            assert(conversation.lastMessage != null);
            Message lastMessage = conversation.lastMessage!;
            assert(lastMessage.id == message.id);
            assert(lastMessage.sentTimestamp == message.sentTimestamp);
            assert(lastMessage.conversationID == message.conversationID);
            assert(lastMessage.fromClientID == message.fromClientID);
            conversation.read();
            decrease(1);
          } else if (conversation.unreadMessageCount == 0) {
            assert(conversation.unreadMessageMentioned == false);
            Message message = Message();
            message.stringContent = uuid();
            await conversation.send(message: message);
            decrease(1);
          }
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open client 2
      await client2.open();
      // recycle
      return [client1, client2];
    });

UnitTestCase updateAndRecallMessage() => UnitTestCase(
    title: 'Case: Update & Recall Message',
    extraExpectedCount: 2,
    testingLogic: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // old message
      Message oldMessage = Message();
      oldMessage.stringContent = uuid();
      // event
      client2.onMessageUpdated = ({
        required Client client,
        required Conversation conversation,
        required Message updatedMessage,
        int? patchCode,
        String? patchReason,
      }) {
        try {
          client2.onMessageUpdated = null;
          assert(updatedMessage.id == oldMessage.id);
          assert(updatedMessage.sentTimestamp == oldMessage.sentTimestamp);
          assert(updatedMessage.conversationID == oldMessage.conversationID);
          assert(updatedMessage.fromClientID == oldMessage.fromClientID);
          assert(updatedMessage.patchedTimestamp != null);
          assert(updatedMessage is ImageMessage);
          if (updatedMessage is ImageMessage) {
            assert(updatedMessage.url != null);
            assert(updatedMessage.url!.endsWith('/test.jpg'));
          }
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onMessageRecalled = ({
        required Client client,
        required Conversation conversation,
        required RecalledMessage recalledMessage,
      }) {
        try {
          client2.onMessageRecalled = null;
          assert(recalledMessage.id == oldMessage.id);
          assert(recalledMessage.sentTimestamp == oldMessage.sentTimestamp);
          assert(recalledMessage.conversationID == oldMessage.conversationID);
          assert(recalledMessage.fromClientID == oldMessage.fromClientID);
          assert(recalledMessage.patchedTimestamp != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id},
      );
      // send
      await conversation.send(message: oldMessage);
      await delay();
      // update
      ByteData imageData = await rootBundle.load('assets/test.jpg');
      ImageMessage newMessage = ImageMessage.from(
        binaryData: imageData.buffer.asUint8List(),
        format: 'jpg',
        name: 'test.jpg',
      );
      Message updatedMessage = await conversation.updateMessage(
        oldMessage: oldMessage,
        newMessage: newMessage,
      );
      assert(updatedMessage == newMessage);
      assert(newMessage.id == oldMessage.id);
      assert(newMessage.sentTimestamp == oldMessage.sentTimestamp);
      assert(newMessage.conversationID == oldMessage.conversationID);
      assert(newMessage.fromClientID == oldMessage.fromClientID);
      assert(newMessage.patchedTimestamp != null);
      assert(newMessage.url != null);
      assert(newMessage.url!.endsWith('/test.jpg'));
      await delay();
      // recall
      RecalledMessage recalledMessage = await conversation.recallMessage(
        message: newMessage,
      );
      assert(recalledMessage.id == oldMessage.id);
      assert(recalledMessage.sentTimestamp == oldMessage.sentTimestamp);
      assert(recalledMessage.conversationID == oldMessage.conversationID);
      assert(recalledMessage.fromClientID == oldMessage.fromClientID);
      assert(recalledMessage.patchedTimestamp != null);
      // recall with msg-id and msg-timestamp.
      await delay();
      Message oldMessage2 = Message();
      oldMessage2.stringContent = uuid();
      await conversation.send(message: oldMessage2);
      await delay();
      await conversation.recallMessage(
        messageID: oldMessage2.id,
        messageTimestamp: oldMessage2.sentTimestamp,
      );
      // recycle
      return [client1, client2];
    });

UnitTestCase messageReceipt() => UnitTestCase(
    title: 'Case: Message Receipt',
    extraExpectedCount: 5,
    testingLogic: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      // message
      Message message = Message();
      message.stringContent = uuid();
      // event
      client1.onMessageDelivered = ({
        required Client client,
        required Conversation conversation,
        String? messageID,
        String? toClientID,
        DateTime? atDate,
      }) async {
        try {
          if (message.id != null) {
            assert(messageID == message.id);
          }
          if (message.sentTimestamp != null) {
            int deliveredTimestamp = atDate!.millisecondsSinceEpoch;
            assert(deliveredTimestamp >= message.sentTimestamp!);
            message.deliveredTimestamp = deliveredTimestamp;
            assert(MessageStatus.values.indexOf(message.status) >=
                MessageStatus.delivered.index);
          }
          assert(toClientID == client2.id);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client1.onMessageRead = ({
        required Client client,
        required Conversation conversation,
        String? messageID,
        String? byClientID,
        DateTime? atDate,
      }) async {
        try {
          if (message.id != null) {
            assert(messageID == message.id);
          }
          if (message.sentTimestamp != null) {
            int readTimestamp = atDate!.millisecondsSinceEpoch;
            assert(readTimestamp >= message.sentTimestamp!);
            message.readTimestamp = readTimestamp;
            assert(MessageStatus.values.indexOf(message.status) >=
                MessageStatus.read.index);
          }
          assert(byClientID == client2.id);
          await conversation.fetchReceiptTimestamps();
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client1.onLastDeliveredAtUpdated = ({
        required Client client,
        required Conversation conversation,
      }) {
        try {
          client1.onLastDeliveredAtUpdated = null;
          assert(conversation.lastDeliveredAt != null);
          assert(conversation.lastDeliveredAt!.millisecondsSinceEpoch >=
              message.sentTimestamp!);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client1.onLastReadAtUpdated = ({
        required Client client,
        required Conversation conversation,
      }) {
        try {
          client1.onLastReadAtUpdated = null;
          assert(conversation.lastReadAt != null);
          assert(conversation.lastReadAt!.millisecondsSinceEpoch >=
              message.sentTimestamp!);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onMessage = ({
        required Client client,
        required Conversation conversation,
        required Message message,
      }) async {
        try {
          client2.onMessage = null;
          await delay();
          await conversation.read();
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onUnreadMessageCountUpdated = ({
        required Client client,
        required Conversation conversation,
      }) {
        if (Platform.isAndroid) {
          // only works for android sdk.
          decrease(1);
        }
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id},
      );
      // send
      await conversation.send(
        message: message,
        receipt: true,
      );
      await delay();
      // recycle
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
        members: {client.id, uuid()},
      );
      // mute
      await conversation.mute();
      assert(conversation.isMuted);
      DateTime? updatedAt = conversation.updatedAt;
      assert(updatedAt != null);
      await delay(seconds: 1);
      // unmute
      await delay(seconds: 1);
      await conversation.unmute();
      assert(conversation.isMuted == false);
      assert(conversation.updatedAt != null);
      assert(conversation.updatedAt != updatedAt);
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
      Conversation? conversationTestingMessageSendFailed;
      // event
      client2.onInvited = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        conversationTestingMessageSendFailed = conversation;
      };
      client2.onInfoUpdated = ({
        required Client client,
        required Conversation conversation,
        Map? updatingAttributes,
        Map? updatedAttributes,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onInfoUpdated = null;
          assert(byClientID == client1.id);
          assert(atDate != null);
          assert(updatingAttributes!.length == 2);
          assert(updatingAttributes!['attr.set'] == setValue);
          assert(updatingAttributes!['attr.unset']['__op'] == 'Delete');
          assert(updatedAttributes!['attr']['set'] == setValue);
          assert(updatedAttributes!['attr']['unset'] == null);
          assert(conversation.attributes!['set'] == setValue);
          assert(conversation.attributes!['unset'] == null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open
      await client1.open();
      await client2.open();
      // create
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id},
        attributes: {'unset': unsetValue},
      );
      assert(conversation.attributes!['unset'] == unsetValue);
      await delay();
      await client2.close();
      TextMessage failedMessage = TextMessage.from(text: 'failed');
      try {
        await conversationTestingMessageSendFailed?.send(
            message: failedMessage);
      } catch (e) {}
      assert(failedMessage.status == MessageStatus.failed);
      await delay();
      await conversation.updateInfo(
        attributes: {
          'attr.set': setValue,
          'attr.unset': {'__op': 'Delete'},
        },
      );
      assert(conversation.attributes!['set'] == setValue);
      assert(conversation.attributes!['unset'] == null);
      await delay();
      await client2.open();
      if (Platform.isAndroid) {
        // Android SDK doesn't support reliable notification yet.
        decrease(1);
      }
      // recycle
      await delay();
      return [client1, client2];
    });

UnitTestCase queryConversation() => UnitTestCase(
    title: 'Case: Query Conversation',
    testingLogic: (decrease) async {
      String clientId = 'b4add8ea-1443-48d0-87ef-057760e4d17c';
      Client client = Client(id: clientId);
      // open
      await client.open();
      ConversationQuery query = client.conversationQuery();
      query.whereContainedIn(
        'm',
        [clientId],
      ).orderByAscending(
        'createdAt',
      );
      query.limit = 1;
      query.skip = 1;
      query.excludeMembers = true;
      query.includeLastMessage = true;
      List<Conversation> conversations = await query.find();
      assert(conversations.length == 1);
      assert(conversations[0].members == null);
      // recycle
      return [client];
    });

UnitTestCase blockConversationMembers() => UnitTestCase(
    title: 'Case: Block Conversation Members',
    extraExpectedCount: 4,
    testingLogic: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      Client client3 = Client(id: uuid());
      Client client4 = Client(id: uuid());

      // event
      client2.onBlocked = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onBlocked = null;
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onUnblocked = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onUnblocked = null;
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client3.onMembersBlocked = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onMembersBlocked = null;
          assert(members!.length == 1);
          assert(members!.contains(client2.id));
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client3.onMembersUnBlocked = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onMembersUnBlocked = null;
          assert(members!.length == 1);
          assert(members!.contains(client2.id));
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };

      // open
      await client1.open();
      await client2.open();
      await client3.open();
      await client4.open();

      // create unique conversation
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id, client3.id},
      );
      // block member
      MemberResult blockMemberResult =
          await conversation.blockMembers(members: {client2.id});
      assert(blockMemberResult.allSucceeded);
      assert(blockMemberResult.succeededMembers.length == 1);
      assert(blockMemberResult.succeededMembers.contains(client2.id));
      await delay();
      assert(conversation.members!.length == 2);
      assert(conversation.members!.contains(client1.id));
      assert(conversation.members!.contains(client3.id));
      // unblock member
      MemberResult unBlockMemberResult =
          await conversation.unblockMembers(members: {client2.id});
      assert(unBlockMemberResult.allSucceeded);
      assert(unBlockMemberResult.succeededMembers.length == 1);
      assert(unBlockMemberResult.succeededMembers.contains(client2.id));

      //query blocked members
      Conversation blockConversation = await client1.createConversation(
        members: {client1.id, client4.id},
      );
      await blockConversation.blockMembers(members: {client4.id});
      QueryMemberResult memberResult =
          await blockConversation.queryBlockedMembers(limit: 10, next: "0");
      assert(memberResult.members.contains(client4.id));

      // recycle
      return [client1, client2, client3];
    });

UnitTestCase muteConversationMembers() => UnitTestCase(
    title: 'Case: Mute Conversation Members',
    extraExpectedCount: 4,
    testingLogic: (decrease) async {
      // client
      Client client1 = Client(id: uuid());
      Client client2 = Client(id: uuid());
      Client client3 = Client(id: uuid());
      Client client4 = Client(id: uuid());

      // event
      client2.onMuted = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onMuted = null;
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client2.onUnmuted = ({
        required Client client,
        required Conversation conversation,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client2.onUnmuted = null;
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client3.onMembersMuted = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onMembersMuted = null;
          assert(members!.length == 1);
          assert(members!.contains(client2.id));
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      client3.onMembersUnMuted = ({
        required Client client,
        required Conversation conversation,
        List? members,
        String? byClientID,
        DateTime? atDate,
      }) {
        try {
          client1.onMembersUnMuted = null;
          assert(members!.length == 1);
          assert(members!.contains(client2.id));
          assert(byClientID == client1.id);
          assert(atDate != null);
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };

      // open
      await client1.open();
      await client2.open();
      await client3.open();
      await client4.open();

      // create unique conversation
      Conversation conversation = await client1.createConversation(
        members: {client1.id, client2.id, client3.id},
      );
      MemberResult muteMemberResult =
          await conversation.muteMembers(members: {client2.id});
      assert(muteMemberResult.allSucceeded);
      assert(muteMemberResult.succeededMembers.length == 1);
      assert(muteMemberResult.succeededMembers.contains(client2.id));
      assert(conversation.members!.length == 3);
      assert(conversation.members!.contains(client1.id));
      assert(conversation.members!.contains(client2.id));
      assert(conversation.members!.contains(client3.id));

      MemberResult unMuteMemberResult =
          await conversation.unmuteMembers(members: {client2.id});
      assert(unMuteMemberResult.allSucceeded);
      assert(unMuteMemberResult.succeededMembers.length == 1);
      assert(unMuteMemberResult.succeededMembers.contains(client2.id));
      assert(conversation.members!.length == 3);
      assert(conversation.members!.contains(client1.id));
      assert(conversation.members!.contains(client2.id));
      assert(conversation.members!.contains(client3.id));

      // query muted members
      Conversation muteConversation = await client1.createConversation(
        members: {client1.id, client4.id},
      );
      await muteConversation.muteMembers(members: {client4.id});
      QueryMemberResult memberResult =
          await muteConversation.queryMutedMembers(limit: 10, next: "0");
      assert(memberResult.members.contains(client4.id));

      // recycle
      return [client1, client2, client3];
    });

String aID = 's0g5kxj7ajtf6n2wt8fqty18p25gmvgrh7b430iuugsde212';
String mKey = 'f7m5491orhbdquahbz57wf3zmnrlqnt6kage2ueumagfyosh';

String signWithHMACSHA1(String str) {
  var key = utf8.encode(mKey);
  var bytes = utf8.encode(str);
  var hmacSha1 = new Hmac(sha1, key);
  var digest = hmacSha1.convert(bytes);
  return '$digest';
}

UnitTestCase signClientOpenAndConversationOperation() => UnitTestCase(
    title: 'Signature Case: Client Open & Conversation Operation',
    testingLogic: (decrease) async {
      String clientId = uuid();
      String clientId1 = clientId + '1';
      String clientId2 = clientId + '2';
      String appid = aID;
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      String nonce = uuid();
      String? conversationId;
      // client
      Client client = Client(
        id: clientId,
        openSignatureHandler: ({
          required Client client,
        }) async {
          return Signature(
            nonce: nonce,
            timestamp: timestamp,
            signature: signWithHMACSHA1('$appid:$clientId::$timestamp:$nonce'),
          );
        },
        conversationSignatureHandler: ({
          String? action,
          required Client client,
          Conversation? conversation,
          List? targetIDs,
        }) async {
          if (action == 'invite' || action == 'kick') {
            assert(conversation != null);
            assert(targetIDs!.length == 1);
            assert(targetIDs!.contains(clientId2));
            return Signature(
              nonce: nonce,
              timestamp: timestamp,
              signature: signWithHMACSHA1(
                  '$appid:$clientId:$conversationId:$clientId2:$timestamp:$nonce:$action'),
            );
          } else {
            assert(action == 'create');
            assert(targetIDs!.length == 2);
            assert(targetIDs!.contains(clientId));
            assert(targetIDs!.contains(clientId1));
            return Signature(
              nonce: nonce,
              timestamp: timestamp,
              signature: signWithHMACSHA1(
                  '$appid:$clientId:$clientId:$clientId1:$timestamp:$nonce'),
            );
          }
        },
      );
      // open
      await client.open();
      // check application
      ConversationQuery query = client.conversationQuery();
      query.whereEqualTo(
        'objectId',
        '5e54967490aef5aa842ad327',
      );
      query.limit = 1;
      List<Conversation> conversations = await query.find();
      assert(conversations.length == 1,
          'maybe you should test with app id: $appid');
      // create
      Conversation conversation = await client.createConversation(
        members: {clientId, clientId1},
      );
      conversationId = conversation.id;
      // add
      MemberResult addResult = await conversation.addMembers(
        members: {clientId2},
      );
      assert(addResult.allSucceeded);
      assert(addResult.succeededMembers.length == 1);
      assert(addResult.succeededMembers.contains(clientId2));
      // remove
      MemberResult removeResult = await conversation.removeMembers(
        members: {clientId2},
      );
      assert(removeResult.allSucceeded);
      assert(removeResult.succeededMembers.length == 1);
      assert(removeResult.succeededMembers.contains(clientId2));
      // recycle
      return [client];
    });

UnitTestCase clientSessionClosed() => UnitTestCase(
    title: 'Signature Case: Client Session Closed',
    extraExpectedCount: 1,
    testingLogic: (decrease) async {
      String clientId = uuid();
      String appid = aID;
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      String nonce = uuid();
      // client
      Client client = Client(
        id: clientId,
        openSignatureHandler: ({
          required Client client,
        }) async {
          return Signature(
            nonce: nonce,
            timestamp: timestamp,
            signature: signWithHMACSHA1('$appid:$clientId::$timestamp:$nonce'),
          );
        },
      );
      // event
      client.onClosed = ({
        required Client client,
        required RTMException exception,
      }) async {
        try {
          client.onClosed = null;
          assert(exception.code == '4115');
          // reopen
          await client.open();
          decrease(1);
        } catch (e) {
          decrease(-1, e: e);
        }
      };
      // open
      await client.open();
      // check application
      ConversationQuery query = client.conversationQuery();
      query.whereEqualTo(
        'objectId',
        '5e54967490aef5aa842ad327',
      );
      List<Conversation> conversations = await query.find();
      assert(conversations.length == 1,
          'maybe you should test with app id: $appid');
      // kick
      http.Response response = await http.post(
        Uri.parse(
            'https://s0g5kxj7.lc-cn-n1-shared.com/1.2/rtm/clients/$clientId/kick'),
        headers: {
          'X-LC-Id': appid,
          'X-LC-Key': '$mKey,master',
          'Content-Type': 'application/json',
        },
        body: '{"reason":"test"}',
      );
      assert(response.statusCode == 200);
      // recycle
      return [client];
    });

class UnitTestCase {
  final String title;
  final int expectedCount;
  final int timeout;
  final Future<List<Client>> Function(
    void Function(
      int, {
      dynamic e,
    }),
  ) testingLogic;

  void Function(int)? stateCountWillChange;
  void Function(int)? stateCountDidChange;

  int _stateCount = 0;
  int get stateCount => this._stateCount;
  set stateCount(int value) {
    this._stateCount = value;
    if (this.stateCountDidChange != null) {
      this.stateCountDidChange!(value);
      if (value <= 0 && this._timer != null) {
        this._timer!.cancel();
        this._timer = null;
      }
    }
  }

  List<Client> _clients = [];
  Timer? _timer;

  UnitTestCase({
    required this.title,
    int extraExpectedCount = 0,
    int timeout = 60,
    required this.testingLogic,
  })  : this.expectedCount = (extraExpectedCount + 2),
        this.timeout = timeout {
    this._stateCount = this.expectedCount;
  }

  Future<void> run({
    void Function(int)? stateCountDidChange,
  }) async {
    this.stateCountDidChange = stateCountDidChange;
    if (this.stateCountWillChange != null) {
      this.stateCountWillChange!(this.expectedCount - 1);
    }
    if (this._timer != null) {
      this._timer?.cancel();
      this._timer = null;
    }
    if (this.timeout > 0) {
      this._timer = Timer(Duration(seconds: this.timeout), () {
        this._timer = null;
        if (this._stateCount > 0) {
          logException('Timeout', title: this.title);
          if (this.stateCountWillChange != null) {
            this.stateCountWillChange!(-1);
          }
          this.tearDown();
        }
      });
    }
    bool hasException = false;
    try {
      this._clients = await this.testingLogic((
        int count, {
        dynamic e,
      }) {
        if (e != null) {
          logException(e, title: this.title);
        }
        if (this.stateCountWillChange != null) {
          if (count > 0) {
            this.stateCountWillChange!(this._stateCount - count);
          } else {
            this.stateCountWillChange!(-1);
          }
        }
        this.tearDown();
      });
    } catch (e) {
      logException(e, title: this.title);
      hasException = true;
    }
    if (this.stateCountWillChange != null) {
      if (hasException) {
        this.stateCountWillChange!(-1);
      } else {
        this.stateCountWillChange!(this._stateCount - 1);
      }
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
    client.onOpened = null;
    client.onResuming = null;
    client.onDisconnected = null;
    client.onClosed = null;
    // conversation
    client.onInvited = null;
    client.onKicked = null;
    client.onMembersJoined = null;
    client.onMembersLeft = null;
    client.onInfoUpdated = null;
    client.onUnreadMessageCountUpdated = null;
    client.onLastReadAtUpdated = null;
    client.onLastDeliveredAtUpdated = null;
    client.onBlocked = null;
    client.onUnblocked = null;
    client.onMuted = null;
    client.onUnmuted = null;
    // message
    client.onMessage = null;
    client.onMessageUpdated = null;
    client.onMessageRecalled = null;
    client.onMessageDelivered = null;
    client.onMessageRead = null;
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
    sendAndReceiveCustomMessage(),
    sendMessageToUnrelatedConversation(),
    sendAndReceiveTransientMessage(),
    readMessage(),
    updateAndRecallMessage(),
    messageReceipt(),
    muteConversation(),
    updateConversation(),
    queryConversation(),
    blockConversationMembers(),
    muteConversationMembers(),
  ];
  List<UnitTestCase> signatureUnitCases = [
    signClientOpenAndConversationOperation(),
    clientSessionClosed(),
  ];
  List<UnitTestCase> allUnitCases = [];

  @override
  void initState() {
    super.initState();
    this.allUnitCases = [
          UnitTestCase(
              title: 'Run all unit cases (exclude signature cases)',
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
    required this.model,
  });

  @override
  UnitTestCaseCardState createState() =>
      UnitTestCaseCardState(model: this.model);
}

class UnitTestCaseCardState extends State<UnitTestCaseCard> {
  final UnitTestCase model;

  UnitTestCaseCardState({
    required this.model,
  });

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
