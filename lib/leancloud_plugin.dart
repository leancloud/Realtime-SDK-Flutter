import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class _Bridge {
  static const MethodChannel _channel = const MethodChannel('leancloud_plugin');
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
    final Map result = await _Bridge._channel.invokeMethod(
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
  String clientId,
});

typedef ConversationSignatureCallback = Future<Signature> Function({
  String clientId,
  String conversationId,
  Set<String> targetIds,
  SignatureAction action,
});

class Client with _Utilities {
  final String id;
  final String tag;

  final SessionOpenSignatureCallback _signSessionOpen;
  final ConversationSignatureCallback _signConversation;

  final Map<String, Conversation> conversations = Map();

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
    var args = {
      'clientId': this.id,
      'force': force,
    };
    if (this.tag != null) {
      args['tag'] = this.tag;
    }
    if (this._signSessionOpen != null) {
      final Signature sign = await this._signSessionOpen(
        clientId: this.id,
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
        clientId: this.id,
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
    this.conversations[conversation.id] = conversation;
    return conversation;
  }

  Future<Conversation> _getConversation({
    @required String id,
  }) async {
    assert(id != null);
    Conversation conversation = this.conversations[id];
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
    this.conversations[conversation.id] = conversation;
    return conversation;
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
  final Map rawData;

  Conversation._from({
    @required this.id,
    @required this.client,
    @required this.rawData,
  })  : assert(id != null),
        assert(client != null),
        assert(rawData != null);

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

  Future<Message> update({
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
