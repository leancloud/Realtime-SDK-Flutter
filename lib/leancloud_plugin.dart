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
    this.channel.setMethodCallHandler((call) {
      final Map args = call.arguments;
      final Client client = this.clientMap[args['clientId']];
      if (client == null) {
        return;
      }
      switch (call.method) {
        case 'onSessionOpen':
          if (client.onSessionOpen != null) {
            client.onSessionOpen(
              client: client,
            );
          }
          break;
        case 'onSessionResume':
          if (client.onSessionResume != null) {
            client.onSessionResume(
              client: client,
            );
          }
          break;
        case 'onSessionDisconnect':
          if (client.onSessionDisconnect != null) {
            RTMException e;
            if (this.isFailure(args)) {
              e = this.error(args);
            }
            client.onSessionDisconnect(
              client: client,
              e: e,
            );
          }
          break;
        case 'onSessionClose':
          if (client.onSessionClose != null) {
            client.onSessionClose(
              client: client,
              e: this.error(args),
            );
          }
          break;
        case 'onConversationMembersUpdate':
          client._processConversationEvent(
            method: call.method,
            args: args,
          );
          break;
        default:
          assert(false, 'should not happen.');
      }
      return;
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

  Map<String, dynamic> _toMap() => {
        's': this.signature,
        't': this.timestamp,
        'n': this.nonce,
      };
}

enum SignatureAction {
  create,
  invite,
  kick,
}

typedef SessionOpenSignatureCallback = Future<Signature> Function({
  Client client,
});

typedef ConversationSignatureCallback = Future<Signature> Function({
  Client client,
  Conversation conversation,
  Set<String> targetIds,
  SignatureAction action,
});

class Client with _Utilities {
  final String id;
  final String tag;

  final SessionOpenSignatureCallback _signSessionOpen;
  final ConversationSignatureCallback _signConversation;

  final Map<String, Conversation> conversationMap = Map();

  Function({
    Client client,
  }) onSessionOpen;
  Function({
    Client client,
  }) onSessionResume;
  Function({
    Client client,
    RTMException e,
  }) onSessionDisconnect;
  Function({
    Client client,
    RTMException e,
  }) onSessionClose;

  Function({
    Client client,
    Conversation conversation,
    String byClientId,
    String atDate,
  }) onConversationInvite;
  Function({
    Client client,
    Conversation conversation,
    String byClientId,
    String atDate,
  }) onConversationKick;
  Function({
    Client client,
    Conversation conversation,
    List members,
    String byClientId,
    String atDate,
  }) onConversationMembersJoin;
  Function({
    Client client,
    Conversation conversation,
    List members,
    String byClientId,
    String atDate,
  }) onConversationMembersLeave;

  Client({
    @required this.id,
    this.tag,
    SessionOpenSignatureCallback signSessionOpen,
    ConversationSignatureCallback signConversation,
  })  : assert(id != null),
        this._signSessionOpen = signSessionOpen,
        this._signConversation = signConversation;

  Future<void> open({
    bool force = true,
  }) async {
    _Bridge().clientMap[this.id] = this;
    var args = {
      'clientId': this.id,
      'force': force,
    };
    if (this.tag != null) {
      args['tag'] = this.tag;
    }
    if (this._signSessionOpen != null) {
      final Signature sign = await this._signSessionOpen(
        client: this,
      );
      args['sign'] = sign._toMap();
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
    Set<String> members,
    String name,
    Map attributes,
    int ttl,
  }) async {
    assert(type != null && type != ConversationType.system);

    Set<String> m = (members != null) ? Set.from(members) : Set();
    m.add(this.id);

    var args = {
      'clientId': this.id,
      'conv_type': ConversationType.values.indexOf(type),
      'm': m,
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
    if (this._signConversation != null) {
      final Signature sign = await this._signConversation(
        client: this,
        targetIds: Set.from(m),
        action: SignatureAction.create,
      );
      args['sign'] = sign._toMap();
    }
    final Map rawData = await this.call(
      method: 'createConversation',
      arguments: args,
    );
    final Conversation conversation = Conversation._from(
      id: rawData['objectId'],
      client: this,
      rawData: rawData,
    );
    this.conversationMap[conversation.id] = conversation;
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

  Future<void> _processConversationEvent({
    @required method,
    @required args,
  }) async {
    final String conversationId = args['cid'];
    assert(conversationId != null);
    Conversation conversation = await this._getConversation(id: conversationId);
    switch (method) {
      case 'onConversationMembersUpdate':
        conversation._membersUpdate(args: args);
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
      'message': message._toMap(),
    };
    if (options.isNotEmpty) {
      args['options'] = options;
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
      'oldMessage': oldMessage._toMap(),
      'newMessage': newMessage._toMap(),
    };
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
    var args = Map();
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
    final List<Map> rawDatas = await this.call(
      method: 'queryMessage',
      arguments: args,
    );
    List<Message> messages = List();
    rawDatas.forEach((item) {
      var message = Message();
      message._loadMap(item);
      messages.add(message);
    });
    return messages;
  }

  Future<Map> _updateMembers({
    @required Set<String> members,
    @required String op,
  }) async {
    assert(members.isNotEmpty);
    assert(op == 'add' || op == 'remove');
    var m = List<String>.from(members);
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
      'm': m,
      'op': op,
    };
    if (this.client._signConversation != null) {
      final Signature sign = await this.client._signConversation(
            client: this.client,
            conversation: this,
          );
      args['sign'] = sign._toMap();
    }
    final Map result = await this.call(
      method: 'updateMembers',
      arguments: args,
    );
    this.rawData['m'] = result['m'];
    this.rawData['updatedAt'] = result['udate'];
    return result;
  }

  Future<void> _muteToggle({
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

  Future<int> getOnlineMembersCount() async {
    var args = {
      'clientId': this.client.id,
      'conversationId': this.id,
    };
    return await this.call(
      method: 'getOnlineMembersCount',
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
}

class Message {
  String _currentClientId;

  String _id;
  int _timestamp;
  String _conversationId;
  String _fromClientId;
  int _patchedTimestamp;
  bool _transient;

  String get id => this._id;
  int get sentTimestamp => this._timestamp;
  String get conversationId => this._conversationId;
  String get fromClientId => this._fromClientId;
  int get patchedTimestamp => this._patchedTimestamp;
  bool get isTransient => this._transient;

  int deliveredTimestamp;
  int readTimestamp;
  bool mentionAll;
  List<String> mentionMembers;

  String stringContent;
  Uint8List binaryContent;

  Map<String, dynamic> _toMap() {
    var map = Map<String, dynamic>();
    if (this._currentClientId != null) {
      map['clientId'] = this._currentClientId;
    }
    if (this._id != null) {
      map['id'] = this._id;
    }
    if (this._conversationId != null) {
      map['cid'] = this._conversationId;
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
    if (this.stringContent != null) {
      map['msg'] = this.stringContent;
    }
    if (this.binaryContent != null) {
      map['binaryMsg'] = this.binaryContent;
    }
    return map;
  }

  void _loadMap(Map data) {
    this._currentClientId = data['clientId'];
    this._conversationId = data['cid'];
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
  }
}
