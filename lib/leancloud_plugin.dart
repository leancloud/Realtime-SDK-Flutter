import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class _Bridge with _Utilities {
  static final _Bridge _singleton = _Bridge._internal();

  factory _Bridge() {
    return _Bridge._singleton;
  }

  final MethodChannel channel = const MethodChannel('leancloud_plugin');
  final Map<String, Client> clientMap = Map();

  _Bridge._internal() {
    this.channel.setMethodCallHandler((call) async {
      final Map args = call.arguments;
      final Client client = this.clientMap[args['clientId']];
      if (client == null) {
        return {};
      }
      switch (call.method) {
        case 'onSessionOpen':
          if (client.onOpen != null) {
            client.onOpen(
              client: client,
            );
          }
          break;
        case 'onSessionResume':
          if (client.onResume != null) {
            client.onResume(
              client: client,
            );
          }
          break;
        case 'onSessionDisconnect':
          if (client.onDisconnect != null) {
            RTMException e;
            if (this.isFailure(args)) {
              e = this.error(args);
            }
            client.onDisconnect(
              client: client,
              e: e,
            );
          }
          break;
        case 'onSessionClose':
          if (client.onClose != null) {
            client.onClose(
              client: client,
              e: this.error(args),
            );
          }
          break;
        case 'onConversationMembersUpdate':
        case 'onConversationDataUpdate':
        case 'onLastMessageUpdate':
        case 'onUnreadMessageCountUpdate':
        case 'onMessageReceive':
        case 'onMessageUpdate':
        case 'onMessageReceipt':
          client._processConversationEvent(
            method: call.method,
            args: args,
          );
          break;
        case 'onSignSessionOpen':
          if (client._signSessionOpen != null) {
            final Signature sign = await client._signSessionOpen(
              client: client,
            );
            return {'sign': sign._toMap()};
          }
          break;
        case 'onSignConversation':
          if (client._signConversation != null) {
            final Conversation conversation = await client._getConversation(
              id: args['conversationId'],
            );
            final Signature sign = await client._signConversation(
              client: client,
              conversation: conversation,
              targetIds: args['targetIds'],
              action: args['action'],
            );
            return {'sign': sign._toMap()};
          }
          break;
        default:
          break;
      }
      return {};
    });
  }
}

mixin _Utilities {
  bool isFailure(Map result) => result['error'] != null;

  RTMException error(Map result) {
    final Map error = result['error'];
    return RTMException(
        code: error['code'].toString(),
        message: error['message'],
        details: error['details']);
  }

  Future<dynamic> call({
    @required String method,
    @required Map arguments,
  }) async {
    assert(method != null && arguments != null);
    final Map result = await _Bridge().channel.invokeMethod(
          method,
          arguments,
        );
    if (this.isFailure(result)) {
      throw this.error(result);
    }
    return result['success'];
  }
}

class RTMException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  RTMException({
    @required this.code,
    this.message,
    this.details,
  }) : assert(code != null);

  @override
  String toString() =>
      'LeanCloud.RTMException(code: $code, message: $message, details: $details)';
}

class Signature {
  final String signature;
  final int timestamp;
  final String nonce;

  Signature({
    @required this.signature,
    @required this.timestamp,
    @required this.nonce,
  })  : assert(signature != null),
        assert(timestamp != null),
        assert(nonce != null);

  @override
  String toString() =>
      'LeanCloud.Signature(s: $signature, t: $timestamp, n: $nonce)';

  Map _toMap() => {
        's': this.signature,
        't': this.timestamp,
        'n': this.nonce,
      };
}

typedef SessionOpenSignatureCallback = Future<Signature> Function({
  Client client,
});

typedef ConversationSignatureCallback = Future<Signature> Function({
  Client client,
  Conversation conversation,
  List targetIds,
  String action,
});

class Client with _Utilities {
  final String id;
  final String tag;

  final SessionOpenSignatureCallback _signSessionOpen;
  final ConversationSignatureCallback _signConversation;

  final Map<String, Conversation> conversationMap = Map();

  void Function({
    Client client,
  }) onOpen;
  void Function({
    Client client,
  }) onResume;
  void Function({
    Client client,
    RTMException e,
  }) onDisconnect;
  void Function({
    Client client,
    RTMException e,
  }) onClose;

  void Function({
    Client client,
    Conversation conversation,
    String byClientId,
    String atDate,
  }) onConversationInvite;
  void Function({
    Client client,
    Conversation conversation,
    String byClientId,
    String atDate,
  }) onConversationKick;
  void Function({
    Client client,
    Conversation conversation,
    List members,
    String byClientId,
    String atDate,
  }) onConversationMembersJoin;
  void Function({
    Client client,
    Conversation conversation,
    List members,
    String byClientId,
    String atDate,
  }) onConversationMembersLeave;

  void Function({
    Client client,
    Conversation conversation,
    Map updatingAttributes,
    Map updatedAttributes,
    String byClientId,
    String atDate,
  }) onConversationDataUpdate;

  void Function({
    Client client,
    Conversation conversation,
  }) onConversationLastMessageUpdate;

  void Function({
    Client client,
    Conversation conversation,
  }) onConversationUnreadMessageCountUpdate;

  void Function({
    Client client,
    Conversation conversation,
    Message message,
  }) onMessageReceive;
  void Function({
    Client client,
    Conversation conversation,
    Message message,
    int patchCode,
    String patchReason,
  }) onMessageUpdate;
  void Function({
    Client client,
    Conversation conversation,
    String messageId,
    int messageTimestamp,
    String byClientId,
    bool isRead,
  }) onMessageReceipt;

  Client({
    @required this.id,
    this.tag,
    SessionOpenSignatureCallback signSessionOpen,
    ConversationSignatureCallback signConversation,
  })  : assert(id != null),
        this._signSessionOpen = signSessionOpen,
        this._signConversation = signConversation;

  Future<void> open({
    bool reconnect = false,
  }) async {
    _Bridge().clientMap[this.id] = this;
    var args = {
      'clientId': this.id,
      'r': reconnect,
    };
    if (this.tag != null) {
      args['tag'] = this.tag;
    }
    args['signRegistry'] = {
      'sessionOpen': (this._signSessionOpen != null),
      'conversation': (this._signConversation != null),
    };
    await this.call(
      method: 'openClient',
      arguments: args,
    );
  }

  Future<void> close() async {
    var args = {
      'clientId': this.id,
    };
    await this.call(
      method: 'closeClient',
      arguments: args,
    );
    _Bridge().clientMap.remove(this.id);
  }

  Future<Conversation> createConversation({
    ConversationType type = ConversationType.normalUnique,
    List<String> members,
    String name,
    Map attributes,
    int ttl,
  }) async {
    assert(type != null && type != ConversationType.system);

    final Set memberSet = (members != null) ? Set.from(members) : Set();
    memberSet.add(this.id);

    var args = {
      'clientId': this.id,
      'conv_type': ConversationType.values.indexOf(type),
      'm': List.from(memberSet),
    };
    if (name != null) {
      args['name'] = name;
    }
    if (attributes != null) {
      args['attr'] = attributes;
    }
    if (ttl != null) {
      args['ttl'] = ttl;
    }
    final Map rawData = await this.call(
      method: 'createConversation',
      arguments: args,
    );
    final String conversationId = rawData['objectId'];
    Conversation conversation = this.conversationMap[conversationId];
    if (conversation == null) {
      conversation = Conversation._from(
        id: conversationId,
        client: this,
        rawData: rawData,
      );
      this.conversationMap[conversationId] = conversation;
    } else {
      conversation._rawData = rawData;
    }
    return conversation;
  }

  Future<Conversation> _getConversation({
    @required String id,
  }) async {
    assert(id != null);
    Conversation conversation = this.conversationMap[id];
    if (conversation != null) {
      return conversation;
    }
    var args = {
      'clientId': this.id,
      'conversationId': id,
    };
    final Map rawData = await this.call(
      method: 'getConversation',
      arguments: args,
    );
    conversation = Conversation._from(
      id: rawData['objectId'],
      client: this,
      rawData: rawData,
    );
    this.conversationMap[conversation.id] = conversation;
    return conversation;
  }

  Future<List<Conversation>> queryConversation({
    String where,
    String sort,
    int limit,
    int skip,
    int flag,
    List<String> temporaryConversationIds,
  }) async {
    Map args = {
      'clientId': this.id,
    };
    if (where != null) {
      args['where'] = where;
    }
    if (sort != null) {
      args['sort'] = sort;
    }
    if (limit != null) {
      args['limit'] = limit;
    }
    if (skip != null) {
      args['skip'] = skip;
    }
    if (flag != null) {
      args['flag'] = flag;
    }
    if (temporaryConversationIds != null) {
      args['tempConvIds'] = temporaryConversationIds;
    }
    final List results = await this.call(
      method: 'queryConversation',
      arguments: args,
    );
    bool needLastMessage = (flag & 2) == 2;
    List<Conversation> conversations = List();
    results.forEach((item) {
      final String conversationId = item['objectId'];
      if (conversationId != null) {
        Conversation conversation = this.conversationMap[conversationId];
        if (conversation == null) {
          conversation = Conversation._from(
            id: conversationId,
            client: this,
            rawData: item,
          );
          this.conversationMap[conversationId] = conversation;
        } else {
          conversation._rawData = item;
        }
        conversations.add(conversation);
        if (needLastMessage) {
          final Map msgRawData = item['msg'];
          if (msgRawData != null) {
            conversation._lastMessage = Message._instanceFrom(
              msgRawData,
            );
          }
        }
      }
    });
    return conversations;
  }

  Future<void> _processConversationEvent({
    @required method,
    @required args,
  }) async {
    Conversation conversation = await this._getConversation(
      id: args['conversationId'],
    );
    switch (method) {
      case 'onConversationMembersUpdate':
        conversation._membersUpdate(args: args);
        break;
      case 'onConversationDataUpdate':
        conversation._dataUpdate(args: args);
        break;
      case 'onLastMessageUpdate':
        conversation._lastMessageUpdate(args: args);
        break;
      case 'onUnreadMessageCountUpdate':
        conversation._unreadMessageCountUpdate(args: args);
        break;
      case 'onMessageReceive':
        conversation._messageReceive(args: args);
        break;
      case 'onMessageUpdate':
        conversation._messageUpdate(args: args);
        break;
      case 'onMessageReceipt':
        conversation._messageReceipt(args: args);
        break;
      default:
        break;
    }
  }
}

enum ConversationType {
  normalUnique, // 0
  normal, // 1
  transient, // 2
  system, // 3
  temporary, // 4
}

class Conversation with _Utilities {
  final String id;
  final Client client;

  Map _rawData;
  Map get rawData => this._rawData;

  Message _lastMessage;
  Message get lastMessage => this._lastMessage;

  int _unreadMessageCount;
  int get unreadMessageCount => this._unreadMessageCount;

  bool unreadMessageContainMention;

  Conversation._from({
    @required this.id,
    @required this.client,
    @required rawData,
  })  : assert(id != null),
        assert(client != null),
        assert(rawData != null),
        this._rawData = rawData;

  Future<Message> send({
    @required Message message,
    bool transient,
    bool receipt,
    bool will,
    int priority,
    Map pushData,
  }) async {
    assert(message != null);
    var options = Map();
    if (receipt == true) {
      options['receipt'] = true;
    }
    if (will == true) {
      options['will'] = true;
    }
    if (priority != null) {
      assert([1, 2, 3].contains(priority));
      options['priority'] = priority;
    }
    if (pushData != null) {
      options['pushData'] = pushData;
    }
    if (transient == true) {
      message._transient = true;
    }
    message._currentClientId = this.client.id;
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
      'message': message._toMap(),
    };
    if (options.isNotEmpty) {
      args['options'] = options;
    }
    if (message is FileMessage) {
      final Map fileMap = Map();
      fileMap['path'] = message._filePath;
      fileMap['data'] = message._fileData;
      fileMap['format'] = message._fileFormat;
      args['file'] = fileMap;
    }
    final Map rawData = await this.call(
      method: 'sendMessage',
      arguments: args,
    );
    message._loadMap(rawData);
    return message;
  }

  Future<void> read() async {
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
    };
    await this.call(
      method: 'readMessage',
      arguments: args,
    );
  }

  Future<Message> updateMessage({
    @required Message oldMessage,
    @required Message newMessage,
  }) async {
    assert(oldMessage != null && newMessage != null);
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
      'oldMessage': oldMessage._toMap(),
      'newMessage': newMessage._toMap(),
    };
    if (newMessage is FileMessage) {
      final Map fileMap = Map();
      fileMap['path'] = newMessage._filePath;
      fileMap['data'] = newMessage._fileData;
      fileMap['format'] = newMessage._fileFormat;
      args['file'] = fileMap;
    }
    final Map rawData = await this.call(
      method: 'readMessage',
      arguments: args,
    );
    newMessage._loadMap(rawData);
    return newMessage;
  }

  Future<Map> getMessageReceipt() async {
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
    };
    return await this.call(
      method: 'getMessageReceipt',
      arguments: args,
    );
  }

  Future<List<Message>> queryMessage({
    int startTimestamp,
    String startMessageId,
    bool startClose,
    int endTimestamp,
    String endMessageId,
    bool endClose,
    int direction,
    int limit,
    int type,
  }) async {
    var start = Map();
    if (startTimestamp != null) {
      start['timestamp'] = startTimestamp;
    }
    if (startMessageId != null) {
      start['id'] = startMessageId;
    }
    if (startClose != null) {
      start['close'] = startClose;
    }
    var end = Map();
    if (endTimestamp != null) {
      end['timestamp'] = endTimestamp;
    }
    if (endMessageId != null) {
      end['id'] = endMessageId;
    }
    if (endClose != null) {
      end['close'] = endClose;
    }
    Map args = {
      'clientId': this.client.id,
      'conversationId': this.id,
    };
    if (start.isNotEmpty) {
      args['start'] = start;
    }
    if (end.isNotEmpty) {
      args['start'] = end;
    }
    if (direction != null) {
      assert(direction == 1 || direction == 2);
      args['direction'] = direction;
    }
    if (limit != null) {
      assert(limit >= 1 && limit <= 100);
      args['limit'] = limit;
    }
    if (type != null) {
      args['type'] = type;
    }
    final List rawDatas = await this.call(
      method: 'queryMessage',
      arguments: args,
    );
    List<Message> messages = List();
    rawDatas.forEach((item) {
      messages.add(
        Message._instanceFrom(item),
      );
    });
    return messages;
  }

  Future<Map> updateMembers({
    @required List<String> members,
    @required String op,
  }) async {
    assert(members.isNotEmpty);
    assert(op == 'add' || op == 'remove');
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
      'm': List.from(members),
      'op': op,
    };
    final Map result = await this.call(
      method: 'updateMembers',
      arguments: args,
    );
    this.rawData['m'] = result['m'];
    this.rawData['updatedAt'] = result['udate'];
    return result;
  }

  Future<void> muteToggle({
    @required String op,
  }) async {
    assert(op == 'mute' || op == 'unmute');
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
      'op': op,
    };
    final Map result = await this.call(
      method: 'muteToggle',
      arguments: args,
    );
    this.rawData['mu'] = result['mu'];
    this.rawData['updatedAt'] = result['udate'];
  }

  Future<void> update({
    @required Map<String, dynamic> data,
  }) async {
    assert(data.isNotEmpty);
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
      'data': data,
    };
    this._rawData = await this.call(
      method: 'updateData',
      arguments: args,
    );
  }

  Future<int> countMembers() async {
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
    };
    return await this.call(
      method: 'countMembers',
      arguments: args,
    );
  }

  void _membersUpdate({
    @required Map args,
  }) {
    final String op = args['op'];
    assert(op == 'joined' ||
        op == 'left' ||
        op == 'members-joined' ||
        op == 'members-left');
    final List m = args['m'];
    final String by = args['initBy'];
    final String udate = args['udate'];
    final List members = args['members'];
    if (members != null) {
      this._rawData['m'] = members;
    }
    if (udate != null) {
      this._rawData['updatedAt'] = udate;
    }
    if (op == 'joined') {
      if (this.client.onConversationInvite != null) {
        this.client.onConversationInvite(
              client: this.client,
              conversation: this,
              byClientId: by,
              atDate: udate,
            );
      }
    } else if (op == 'left') {
      if (this.client.onConversationKick != null) {
        this.client.onConversationKick(
              client: this.client,
              conversation: this,
              byClientId: by,
              atDate: udate,
            );
      }
    } else if (op == 'members-joined') {
      if (this.client.onConversationMembersJoin != null) {
        this.client.onConversationMembersJoin(
              client: this.client,
              conversation: this,
              members: m,
              byClientId: by,
              atDate: udate,
            );
      }
    } else {
      if (this.client.onConversationMembersLeave != null) {
        this.client.onConversationMembersLeave(
              client: this.client,
              conversation: this,
              members: m,
              byClientId: by,
              atDate: udate,
            );
      }
    }
  }

  void _dataUpdate({
    @required Map args,
  }) {
    final Map rawData = args['rawData'];
    if (rawData != null) {
      this._rawData = rawData;
    }
    if (this.client.onConversationDataUpdate != null) {
      final Map attr = args['attr'];
      final Map attrModified = args['attrModified'];
      final String by = args['initBy'];
      final String udate = args['udate'];
      this.client.onConversationDataUpdate(
            client: this.client,
            conversation: this,
            updatingAttributes: attr,
            updatedAttributes: attrModified,
            byClientId: by,
            atDate: udate,
          );
    }
  }

  void _lastMessageUpdate({
    @required Map args,
  }) {
    this._lastMessage = Message._instanceFrom(
      args['message'],
    );
    if (this.client.onConversationLastMessageUpdate != null) {
      this.client.onConversationLastMessageUpdate(
            client: this.client,
            conversation: this,
          );
    }
  }

  void _unreadMessageCountUpdate({
    @required Map args,
  }) {
    this._unreadMessageCount = args['count'];
    final bool mention = args['mention'];
    if (mention != null) {
      this.unreadMessageContainMention = mention;
    }
    if (this.client.onConversationUnreadMessageCountUpdate != null) {
      this.client.onConversationUnreadMessageCountUpdate(
            client: this.client,
            conversation: this,
          );
    }
  }

  void _messageReceive({
    @required Map args,
  }) {
    if (this.client.onMessageReceive != null) {
      this.client.onMessageReceive(
            client: this.client,
            conversation: this,
            message: Message._instanceFrom(
              args['message'],
            ),
          );
    }
  }

  void _messageUpdate({
    @required Map args,
  }) {
    if (this.client.onMessageUpdate != null) {
      this.client.onMessageUpdate(
            client: this.client,
            conversation: this,
            message: Message._instanceFrom(
              args['message'],
            ),
            patchCode: args['patchCode'],
            patchReason: args['patchReason'],
          );
    }
  }

  void _messageReceipt({
    @required Map args,
  }) {
    if (this.client.onMessageReceipt != null) {
      this.client.onMessageReceipt(
            client: this.client,
            conversation: this,
            messageId: args['id'],
            messageTimestamp: args['t'],
            byClientId: args['from'],
            isRead: args['read'],
          );
    }
  }
}

class Message {
  String _currentClientId;

  String _id;
  String get id => this._id;

  int _timestamp;
  int get sentTimestamp => this._timestamp;

  String _conversationId;
  String get conversationId => this._conversationId;

  String _fromClientId;
  String get fromClientId => this._fromClientId;

  int _patchedTimestamp;
  int get patchedTimestamp => this._patchedTimestamp;

  bool _transient;

  int deliveredTimestamp;
  int readTimestamp;
  bool mentionAll;
  List mentionMembers;

  String stringContent;
  Uint8List binaryContent;

  Message();

  static Message _instanceFrom(
    Map rawData,
  ) {
    Message message;
    final Map typeMsgData = rawData['typeMsgData'];
    if (typeMsgData != null) {
      TypeableMessage Function() constructor =
          TypeableMessage._classMap[typeMsgData['_lctype']];
      message = constructor();
    } else {
      message = Message();
    }
    message._loadMap(rawData);
    return message;
  }

  Map _toMap() {
    var map = Map<String, dynamic>();
    if (this._currentClientId != null) {
      map['clientId'] = this._currentClientId;
    }
    if (this._conversationId != null) {
      map['conversationId'] = this._conversationId;
    }
    if (this._id != null) {
      map['id'] = this._id;
    }
    if (this._fromClientId != null) {
      map['from'] = this._fromClientId;
    }
    if (this._timestamp != null) {
      map['timestamp'] = this._timestamp;
    }
    if (this._patchedTimestamp != null) {
      map['patchTimestamp'] = this._patchedTimestamp;
    }
    if (this._transient != null) {
      map['transient'] = this._transient;
    }
    if (this.deliveredTimestamp != null) {
      map['ackAt'] = this.deliveredTimestamp;
    }
    if (this.readTimestamp != null) {
      map['readAt'] = this.readTimestamp;
    }
    if (this.mentionAll != null) {
      map['mentionAll'] = this.mentionAll;
    }
    if (this.mentionMembers != null) {
      map['mentionPids'] = this.mentionMembers;
    }
    if (this.binaryContent != null) {
      map['binaryMsg'] = this.binaryContent;
    } else if (this.stringContent != null) {
      map['msg'] = this.stringContent;
    } else if (this is TypeableMessage) {
      final Map typeableMessageData = (this as TypeableMessage).rawData;
      typeableMessageData['_lctype'] = (this as TypeableMessage).type;
      map['typeMsgData'] = typeableMessageData;
    }
    return map;
  }

  void _loadMap(Map data) {
    this._currentClientId = data['clientId'];
    this._conversationId = data['conversationId'];
    this._id = data['id'];
    this._fromClientId = data['from'];
    this._timestamp = data['timestamp'];
    this._patchedTimestamp = data['patchTimestamp'];
    if (data['ackAt'] != null) {
      this.deliveredTimestamp = data['ackAt'];
    }
    if (data['readAt'] != null) {
      this.readTimestamp = data['readAt'];
    }
    this.mentionAll = data['mentionAll'];
    this.mentionMembers = data['mentionPids'];
    this._transient = data['transient'];
    this.stringContent = data['msg'];
    this.binaryContent = data['binaryMsg'];
    if (this is TypeableMessage) {
      (this as TypeableMessage)._rawData = data['typeMsgData'];
    }
  }
}

class TypeableMessage extends Message {
  int get type => 0;

  static void register(
    TypeableMessage Function() constructor,
  ) {
    var instance = constructor();
    assert(instance.type > 0);
    TypeableMessage._classMap[instance.type] = constructor;
  }

  static final Map<int, TypeableMessage Function()> _classMap = {
    TextMessage().type: () => TextMessage(),
    ImageMessage().type: () => ImageMessage(),
    AudioMessage().type: () => AudioMessage(),
    VideoMessage().type: () => VideoMessage(),
    LocationMessage().type: () => LocationMessage(),
    FileMessage().type: () => FileMessage(),
    RecalledMessage().type: () => RecalledMessage(),
  };

  TypeableMessage() : super();

  Map _rawData = Map();
  Map get rawData => this._rawData;

  String get text => this.rawData['_lctext'];
  set text(String value) => this.rawData['_lctext'] = value;

  Map get attributes => this.rawData['_lcattrs'];
  set attributes(Map value) => this.rawData['_lcattrs'] = value;
}

class TextMessage extends TypeableMessage {
  @override
  int get type => -1;

  TextMessage() : super();
}

class ImageMessage extends FileMessage {
  @override
  int get type => -2;

  double get width {
    final Map metaDataMap = this._metaDataMap;
    if (metaDataMap != null) {
      var width = metaDataMap['width'];
      return width.toDouble();
    } else {
      return null;
    }
  }

  double get height {
    final Map metaDataMap = this._metaDataMap;
    if (metaDataMap != null) {
      var height = metaDataMap['height'];
      return height.toDouble();
    } else {
      return null;
    }
  }

  ImageMessage() : super();

  ImageMessage.from({
    String path,
    Uint8List binaryData,
    String format,
  }) : super.from(
          path: path,
          binaryData: binaryData,
          format: format,
        );
}

class AudioMessage extends FileMessage {
  @override
  int get type => -3;

  double get duration {
    final Map metaDataMap = this._metaDataMap;
    if (metaDataMap != null) {
      var duration = metaDataMap['duration'];
      return duration.toDouble();
    } else {
      return null;
    }
  }

  AudioMessage() : super();

  AudioMessage.from({
    String path,
    Uint8List binaryData,
    String format,
  }) : super.from(
          path: path,
          binaryData: binaryData,
          format: format,
        );
}

class VideoMessage extends FileMessage {
  @override
  int get type => -4;

  double get duration {
    final Map metaDataMap = this._metaDataMap;
    if (metaDataMap != null) {
      var duration = metaDataMap['duration'];
      return duration.toDouble();
    } else {
      return null;
    }
  }

  VideoMessage() : super();

  VideoMessage.from({
    String path,
    Uint8List binaryData,
    String format,
  }) : super.from(
          path: path,
          binaryData: binaryData,
          format: format,
        );
}

class LocationMessage extends TypeableMessage {
  @override
  int get type => -5;

  Map get _locationMap => this.rawData['_lcloc'];
  set _locationMap(Map value) => this.rawData['_lcloc'] = value;

  double get latitude {
    final Map locationMap = this._locationMap;
    if (locationMap != null) {
      var latitude = locationMap['latitude'];
      return latitude.toDouble();
    }
    return null;
  }

  double get longitude {
    final Map locationMap = this._locationMap;
    if (locationMap != null) {
      var longitude = locationMap['longitude'];
      return longitude.toDouble();
    }
    return null;
  }

  LocationMessage() : super();

  LocationMessage.from({
    @required double latitude,
    @required double longitude,
  }) {
    assert(latitude != null && longitude != null);
    this._locationMap = {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class FileMessage extends TypeableMessage {
  @override
  int get type => -6;

  String _filePath;
  Uint8List _fileData;
  String _fileFormat;

  Map get _fileMap {
    return this.rawData['_lcfile'];
  }

  Map get _metaDataMap {
    final Map fileMap = this._fileMap;
    if (fileMap != null) {
      return fileMap['metaData'];
    } else {
      return null;
    }
  }

  String get url {
    final Map fileMap = this._fileMap;
    if (fileMap != null) {
      return fileMap['url'];
    } else {
      return null;
    }
  }

  String get format {
    final Map metaDataMap = this._metaDataMap;
    if (metaDataMap != null) {
      return metaDataMap['format'];
    } else {
      return null;
    }
  }

  double get size {
    final Map metaDataMap = this._metaDataMap;
    if (metaDataMap != null) {
      var size = metaDataMap['size'];
      return size.toDouble();
    } else {
      return null;
    }
  }

  FileMessage() : super();

  FileMessage.from({
    String path,
    Uint8List binaryData,
    String format,
  }) {
    assert(path != null || binaryData != null);
    this._filePath = path;
    this._fileData = binaryData;
    this._fileFormat = format;
  }
}

class RecalledMessage extends TypeableMessage {
  @override
  int get type => -127;

  RecalledMessage() : super();
}
