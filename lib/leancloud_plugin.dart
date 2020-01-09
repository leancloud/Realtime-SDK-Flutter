import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class _Bridge {
  static const MethodChannel _channel = const MethodChannel('leancloud_plugin');

  static Future<Map> invokeMethod({
    String method,
    Map arguments,
  }) async {
    Map result = await _channel.invokeMethod(
      method,
      arguments,
    );
    return result;
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

  Map<String, dynamic> _toJSON() => {
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
      args['sign'] = sign._toJSON();
    }
    args['signRegistry'] = {
      'sessionOpen': (this._signSessionOpen != null),
      'conversation': (this._signConversation != null),
    };
    final Map result = await _Bridge.invokeMethod(
      method: 'openClient',
      arguments: args,
    );
    if (isFailure(result)) {
      throw error(result);
    } else {
      return;
    }
  }

  Future<void> close() async {
    var args = {
      'clientId': this.id,
    };
    final Map result = await _Bridge.invokeMethod(
      method: 'closeClient',
      arguments: args,
    );
    if (isFailure(result)) {
      throw error(result);
    } else {
      return;
    }
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
      args['sign'] = sign._toJSON();
    }
    final Map result = await _Bridge.invokeMethod(
      method: 'createConversation',
      arguments: args,
    );
    if (isFailure(result)) {
      throw error(result);
    } else {
      Map rawData = result['success'];
      Conversation conversation = Conversation._from(
        id: rawData['objectId'],
        client: this,
        rawData: rawData,
      );
      return conversation;
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
  final Map rawData;

  Conversation._from({
    @required this.id,
    @required this.client,
    @required this.rawData,
  })  : assert(id != null),
        assert(client != null),
        assert(rawData != null);
}
