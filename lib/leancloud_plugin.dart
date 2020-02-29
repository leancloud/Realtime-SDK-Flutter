import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class _Bridge with _Utilities {
  static final _Bridge _singleton = _Bridge._internal();

  factory _Bridge() {
    return _Bridge._singleton;
  }

  final MethodChannel channel = const MethodChannel('leancloud_plugin');
  final Map<String, Client> clientMap = <String, Client>{};

  _Bridge._internal() {
    channel.setMethodCallHandler((call) async {
      final Map args = call.arguments;
      final Client client = clientMap[args['clientId']];
      if (client == null) {
        return {};
      }
      switch (call.method) {
        case 'onSessionOpen':
          if (client.onOpened != null) {
            client.onOpened(
              client: client,
            );
          }
          break;
        case 'onSessionResume':
          if (client.onResuming != null) {
            client.onResuming(
              client: client,
            );
          }
          break;
        case 'onSessionDisconnect':
          if (client.onDisconnected != null) {
            RTMException e;
            if (isFailure(args)) {
              e = errorFrom(args);
            }
            client.onDisconnected(
              client: client,
              exception: e,
            );
          }
          break;
        case 'onSessionClose':
          if (client.onClosed != null) {
            client.onClosed(
              client: client,
              exception: errorFrom(args),
            );
          }
          break;
        case 'onConversationMembersUpdate':
        case 'onConversationDataUpdate':
        case 'onUnreadMessageCountUpdate':
        case 'onLastReceiptTimestampUpdate':
        case 'onMessageReceive':
        case 'onMessagePatch':
        case 'onMessageReceipt':
          client._processConversationEvent(
            method: call.method,
            args: args,
          );
          break;
        case 'onSignSessionOpen':
          if (client._openSignatureHandler != null) {
            final Signature sign = await client._openSignatureHandler(
              client: client,
            );
            return {'sign': sign._toMap()};
          }
          break;
        case 'onSignConversation':
          if (client._conversationSignatureHandler != null) {
            Conversation conversation;
            final String conversationID = args['conversationId'];
            if (conversationID != null) {
              conversation = await client._getConversation(
                conversationID: conversationID,
              );
            }
            final Signature sign = await client._conversationSignatureHandler(
              client: client,
              conversation: conversation,
              targetIDs: args['targetIds'],
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

  RTMException errorFrom(Map result) {
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
    if (isFailure(result)) {
      throw errorFrom(result);
    }
    return result['success'];
  }

  static final DateFormat isoDateFormat =
      DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

  DateTime parseIsoString(String isoString) {
    DateTime date;
    if (isoString != null) {
      date = _Utilities.isoDateFormat.parseStrict(isoString);
    }
    return date;
  }

  DateTime parseMilliseconds(int milliseconds) {
    DateTime date;
    if (milliseconds != null) {
      date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return date;
  }
}

/// Exception of RTM Plugin.
class RTMException implements Exception {
  /// The code of the [RTMException], it will never be `null`.
  final String code;

  /// The reason of the [RTMException], it is optional.
  final String message;

  /// The supplementary information of the [RTMException], it is optional.
  final dynamic details;

  /// To create a [RTMException], [code] is needed.
  RTMException({
    @required this.code,
    this.message,
    this.details,
  }) : assert(code != null);

  @override
  String toString() => '\nLC.RTM.Exception('
      '\n  code: $code,'
      '\n  essage: $message,'
      '\n  details: $details,'
      '\n)';
}

/// IM Signature of RTM Plugin.
class Signature {
  /// The signature of the [Signature].
  final String signature;

  /// The timestamp of the [Signature], unit is millisecond.
  final int timestamp;

  /// The nonce of the [Signature].
  final String nonce;

  /// To create a [Signature], the unit of [timestamp] is millisecond.
  Signature({
    @required this.signature,
    @required this.timestamp,
    @required this.nonce,
  })  : assert(signature != null),
        assert(timestamp != null),
        assert(nonce != null);

  @override
  String toString() => '\nLC.RTM.Signature('
      '\n  signature: $signature,'
      '\n  timestamp: $timestamp,'
      '\n  nonce: $nonce'
      '\n)';

  Map _toMap() => {
        's': signature,
        't': timestamp,
        'n': nonce,
      };
}

/// IM Client of RTM Plugin.
class Client with _Utilities {
  /// The ID of the [Client], it should not be `null`.
  final String id;

  /// The tag of the [Client]. it is optional.
  final String tag;

  /// The map of the [Conversation]s which belong to the [Client] in memory, the key is [Conversation.id].
  final Map<String, Conversation> conversationMap = <String, Conversation>{};

  /// The reopened event of the [client].
  void Function({
    Client client,
  }) onOpened;

  /// The resuming event of the [client].
  void Function({
    Client client,
  }) onResuming;

  /// The disconnected event of the [client], [exception] is optional.
  ///
  /// This event occurs, for example, when network of local environment unavailable.
  void Function({
    Client client,
    RTMException exception,
  }) onDisconnected;

  /// The closed event of the [client], [exception] will never be `null`.
  ///
  /// This event occurs, for example, [client] has been logged off by server.
  void Function({
    Client client,
    RTMException exception,
  }) onClosed;

  /// The [client] has been invited to the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    Client client,
    Conversation conversation,
    String byClientID,
    DateTime atDate,
  }) onInvited;

  /// The [client] has been kicked from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    Client client,
    Conversation conversation,
    String byClientID,
    DateTime atDate,
  }) onKicked;

  /// Some [members] have joined to the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    Client client,
    Conversation conversation,
    List members,
    String byClientID,
    DateTime atDate,
  }) onMembersJoined;

  /// Some [members] have left from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    Client client,
    Conversation conversation,
    List members,
    String byClientID,
    DateTime atDate,
  }) onMembersLeft;

  /// The attributes of the [conversation] has been updated.
  ///
  /// [updatingAttributes] means which attributes to be updated.
  /// [updatedAttributes] means result of updating.
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    Client client,
    Conversation conversation,
    Map updatingAttributes,
    Map updatedAttributes,
    String byClientID,
    DateTime atDate,
  }) onInfoUpdated;

  /// The [Conversation.unreadMessageCount] of the [conversation] has been updated.
  void Function({
    Client client,
    Conversation conversation,
  }) onUnreadMessageCountUpdated;

  /// The [Conversation.lastReadAt] of the [conversation] has been updated.
  void Function({
    Client client,
    Conversation conversation,
  }) onLastReadAtUpdated;

  /// The [Conversation.lastDeliveredAt] of the [conversation] has been updated.
  void Function({
    Client client,
    Conversation conversation,
  }) onLastDeliveredAtUpdated;

  /// [conversation] has a [message].
  ///
  /// If [message] is new one, the [Conversation.lastMessage] of [conversation] will be updated.
  void Function({
    Client client,
    Conversation conversation,
    Message message,
  }) onMessage;

  /// The sent message in [conversation] has been updated to [updatedMessage].
  ///
  /// If [patchCode] or [patchReason] not `null`, means the sent message was updated due to special reason.
  void Function({
    Client client,
    Conversation conversation,
    Message updatedMessage,
    int patchCode,
    String patchReason,
  }) onMessageUpdated;

  /// The sent message in the [conversation] has been recalled(updated to [recalledMessage]).
  void Function({
    Client client,
    Conversation conversation,
    RecalledMessage recalledMessage,
  }) onMessageRecalled;

  /// The sent message(ID is [messageID]) that send to [conversation] with [receipt] option, has been delivered to the client(ID is [toClientID]).
  ///
  /// [atDate] means when it occurred.
  void Function({
    Client client,
    Conversation conversation,
    String messageID,
    String toClientID,
    DateTime atDate,
  }) onMessageDelivered;

  /// The sent message(ID is [messageID]) that send to [conversation] with [receipt] option, has been read by the client(ID is [toClientID]).
  ///
  /// [atDate] means when it occurred.
  void Function({
    Client client,
    Conversation conversation,
    String messageID,
    String byClientID,
    DateTime atDate,
  }) onMessageRead;

  final Future<Signature> Function({
    Client client,
  }) _openSignatureHandler;
  final Future<Signature> Function({
    Client client,
    Conversation conversation,
    List targetIDs,
    String action,
  }) _conversationSignatureHandler;

  /// To create an IM [Client] with an [Client.id] and an optional [Client.tag].
  ///
  /// You can implement below signature handlers as required to enable the feature about signature.
  /// * [openSignatureHandler] is a handler for [Client.open].
  /// * [conversationSignatureHandler] is a handler for the functions about [Conversation], details as below:
  ///   * When [action] is `create`, means [Client.createConversation] or [Client.createChatRoom] is invoked.
  ///   * When [action] is `invite`, means [Conversation.join] or [Conversation.addMembers] is invoked.
  ///   * When [action] is `kick`, means [Conversation.quit] or [Conversation.removeMembers] is invoked.
  Client({
    @required this.id,
    this.tag,
    Future<Signature> Function({
      Client client,
    })
        openSignatureHandler,
    Future<Signature> Function({
      Client client,
      Conversation conversation,
      List targetIDs,
      String action,
    })
        conversationSignatureHandler,
  })  : assert(id != null),
        _openSignatureHandler = openSignatureHandler,
        _conversationSignatureHandler = conversationSignatureHandler;

  /// To start IM service.
  ///
  /// If [Client] init with a valid [Client.tag] and open with non-[reconnect], it will force other clients that has the same [Client.id] and [Client.tag] into closed.
  /// If [reconnect] is `true` and this client has been closed by other, the result of this action is a [RTMException], default is `false`.
  Future<void> open({
    bool reconnect = false,
  }) async {
    _Bridge().clientMap[id] = this;
    var args = {
      'clientId': id,
      'r': reconnect,
      'signRegistry': {
        'sessionOpen': (_openSignatureHandler != null),
        'conversation': (_conversationSignatureHandler != null),
      },
    };
    if (tag != null) {
      args['tag'] = tag;
    }
    await call(
      method: 'openClient',
      arguments: args,
    );
  }

  /// To end IM service.
  Future<void> close() async {
    await call(
      method: 'closeClient',
      arguments: {
        'clientId': id,
      },
    );
    _Bridge().clientMap.remove(id);
  }

  /// To create a normal [Conversation].
  ///
  /// [isUnique] is a special parameter, default is `true`, it affects the creation behavior and property [Conversation.isUnique].
  ///   * When it is `true` and the relevant unique [Conversation] not exists in the server, this method will create a new unique [Conversation].
  ///   * When it is `true` and the relevant unique [Conversation] exists in the server, this method will return that existing unique [Conversation].
  ///   * When it is `false`, this method always create a new non-unique [Conversation].
  ///
  /// [members] is the [Conversation.members].
  /// [name] is the [Conversation.name].
  /// [attributes] is the [Conversation.attributes].
  ///
  /// Returns an instance of [Conversation].
  Future<Conversation> createConversation({
    bool isUnique = true,
    Set<String> members,
    String name,
    Map<String, dynamic> attributes,
  }) async {
    return await _createConversation(
      type: _ConversationType.normal,
      isUnique: isUnique,
      members: members,
      name: name,
      attributes: attributes,
    );
  }

  /// To create a new [ChatRoom].
  ///
  /// [name] is the [Conversation.name].
  /// [attributes] is the [Conversation.attributes].
  ///
  /// Returns an instance of [ChatRoom].
  Future<ChatRoom> createChatRoom({
    String name,
    Map<String, dynamic> attributes,
  }) async {
    return await _createConversation(
      type: _ConversationType.transient,
      name: name,
      attributes: attributes,
    );
  }

  /// To create a new [TemporaryConversation].
  ///
  /// [members] is the [Conversation.members].
  /// [timeToLive] is the [TemporaryConversation.timeToLive].
  ///
  /// Returns an instance of [TemporaryConversation].
  Future<TemporaryConversation> createTemporaryConversation({
    Set<String> members,
    int timeToLive,
  }) async {
    return await _createConversation(
      type: _ConversationType.temporary,
      members: members,
      ttl: timeToLive,
    );
  }

  /// To create a new [ConversationQuery].
  ConversationQuery conversationQuery() =>
      ConversationQuery._from(client: this);

  Future<T> _createConversation<T extends Conversation>({
    _ConversationType type,
    bool isUnique,
    Set<String> members,
    String name,
    Map attributes,
    int ttl,
  }) async {
    assert(type != null && type != _ConversationType.system);
    var args = {
      'clientId': id,
      'conv_type': (isUnique ?? false) ? 0 : (type.index + 1),
    };
    if (type != _ConversationType.transient) {
      final Set<String> memberSet = members ?? Set<String>();
      memberSet.add(id);
      args['m'] = memberSet.toList();
    }
    if (name != null) {
      args['name'] = name;
    }
    if (attributes != null) {
      args['attr'] = attributes;
    }
    if (ttl != null) {
      args['ttl'] = ttl;
    }
    final Map rawData = await call(
      method: 'createConversation',
      arguments: args,
    );
    final String conversationID = rawData['objectId'];
    Conversation conversation = conversationMap[conversationID];
    if (conversation != null) {
      conversation._rawData = rawData;
    } else {
      conversation = Conversation._newInstance(
        client: this,
        rawData: rawData,
      );
      conversationMap[conversationID] = conversation;
    }
    return conversation;
  }

  Future<Conversation> _getConversation({
    @required String conversationID,
  }) async {
    assert(conversationID != null);
    Conversation conversation = conversationMap[conversationID];
    if (conversation != null) {
      return conversation;
    }
    var args = {
      'clientId': id,
      'conversationId': conversationID,
    };
    final Map rawData = await call(
      method: 'getConversation',
      arguments: args,
    );
    conversation = Conversation._newInstance(
      client: this,
      rawData: rawData,
    );
    conversationMap[conversation.id] = conversation;
    return conversation;
  }

  Future<void> _processConversationEvent({
    @required String method,
    @required Map args,
  }) async {
    final Conversation conversation = await _getConversation(
      conversationID: args['conversationId'],
    );
    switch (method) {
      case 'onConversationMembersUpdate':
        conversation._membersUpdate(args);
        break;
      case 'onConversationDataUpdate':
        conversation._dataUpdate(args);
        break;
      case 'onUnreadMessageCountUpdate':
        conversation._unreadMessageCountUpdate(args);
        break;
      case 'onLastReceiptTimestampUpdate':
        conversation._lastReceiptTimestampUpdate(args);
        break;
      case 'onMessageReceive':
        conversation._messageReceive(args);
        break;
      case 'onMessagePatch':
        conversation._messagePatch(args);
        break;
      case 'onMessageReceipt':
        conversation._messageReceipt(args);
        break;
      default:
        break;
    }
  }
}

/// IM Conversation Query of RTM Plugin.
class ConversationQuery with _Utilities {
  /// Which [Client] that the [ConversationQuery] belongs to.
  final Client client;

  /// The [String] representation of the where condition.
  ///
  /// If you want to query [Conversation] by [Conversation.id], can set it like this:
  /// ```
  /// query.whereString = jsonEncode({
  ///   'objectId': conversationID,
  /// });
  /// ```
  ///
  /// ***Important:***
  /// The default value is `'{"m": clientID}'`, the `clientID` is [ConversationQuery.client.id], it means [Conversation.members] contains `clientID`.
  String whereString;

  /// The order by the key of [Conversation].
  ///
  /// ***Important:***
  /// The default value is `-lm`, means the timestamp of the [Conversation.lastMessage] from newest to oldest.
  String sort;

  /// The max count of the query result, default is `10`.
  int limit;

  /// The offset of the query, default is `0`.
  int skip;

  /// Whether the queried [Conversation]s not contain [Conversation.members], default is `false`.
  bool excludeMembers;

  /// Whether the queried [Conversation]s contain [Conversation.lastMessage], default is `false`.
  bool includeLastMessage;

  ConversationQuery._from({
    @required this.client,
  });

  /// To find the [Conversation].
  ///
  /// Returns a [List] of the [Conversation].
  ///
  /// ***Important:***
  /// If you want to find [TemporaryConversation], should use [ConversationQuery.findTemporaryConversations].
  Future<List<T>> find<T extends Conversation>() async {
    return await _find();
  }

  /// To find the [TemporaryConversation] by IDs.
  ///
  /// [temporaryConversationIDs] should not be empty and more than `100`.
  ///
  /// Returns a [List] of the [TemporaryConversation].
  Future<List<TemporaryConversation>> findTemporaryConversations({
    @required List<String> temporaryConversationIDs,
  }) async {
    assert(temporaryConversationIDs.isNotEmpty &&
        temporaryConversationIDs.length <= 100);
    return await _find(
      temporaryConversationIDs: temporaryConversationIDs,
    );
  }

  Future<List<T>> _find<T extends Conversation>({
    List<String> temporaryConversationIDs,
  }) async {
    bool isIncludeLastMessage = includeLastMessage ?? false;
    final List results = await call(
      method: 'queryConversation',
      arguments: _parameters(
        temporaryConversationIDs: temporaryConversationIDs,
      ),
    );
    return _handleResults(
      results,
      isIncludeLastMessage,
    );
  }

  Map _parameters({
    List<String> temporaryConversationIDs,
  }) {
    Map args = {
      'clientId': client.id,
    };
    if (temporaryConversationIDs != null) {
      args['tempConvIds'] = temporaryConversationIDs;
      args['limit'] = temporaryConversationIDs.length;
    } else {
      if (whereString != null) {
        args['where'] = whereString;
      }
      if (sort != null) {
        args['sort'] = sort;
      }
      if (skip != null) {
        args['skip'] = skip;
      }
      if (limit != null) {
        args['limit'] = limit;
      }
    }
    int flag = 0;
    if (excludeMembers ?? false) {
      flag ^= 1;
    }
    if (includeLastMessage ?? false) {
      flag ^= 2;
    }
    if (flag > 0) {
      args['flag'] = flag;
    }
    return args;
  }

  List<T> _handleResults<T extends Conversation>(
    List results,
    bool isIncludeLastMessage,
  ) {
    List<T> conversations = <T>[];
    for (var item in results) {
      final String conversationID = item['objectId'];
      if (conversationID != null) {
        Conversation conversation = client.conversationMap[conversationID];
        if (conversation != null) {
          conversation._rawData = item;
        } else {
          conversation = Conversation._newInstance(
            client: client,
            rawData: item,
          );
          client.conversationMap[conversationID] = conversation;
        }
        if (isIncludeLastMessage) {
          dynamic msg = item['msg'];
          if (msg is Map) {
            conversation._updateLastMessage(
              message: Message._instanceFrom(
                msg,
              ),
            );
          }
        }
        conversations.add(conversation);
      }
    }
    return conversations;
  }
}

enum _ConversationType {
  normal,
  transient,
  system,
  temporary,
}

/// The result of operations for [Conversation.members].
class MemberResult with _Utilities {
  /// All targets of the operation are suceeded.
  bool get allSucceeded => failedMembers.isEmpty;

  /// All allowed targets.
  final List succeededMembers;

  /// All not allowed targets and reasons.
  ///
  /// The detail format in [MemberResult.failedMembers] like this:
  /// ```
  /// [{
  /// 'members': [String],
  /// 'error': RTMException,
  /// }]
  /// ```
  final List failedMembers;

  MemberResult._from(Map data)
      : succeededMembers = data['allowedPids'] ?? [],
        failedMembers = [] {
    final List failedPids = data['failedPids'] ?? [];
    for (var item in failedPids) {
      final List pids = item['pids'];
      final RTMException exception = errorFrom(item);
      failedMembers.add({
        'members': pids,
        'error': exception,
      });
    }
  }

  @override
  String toString() => '\nLC.RTM.MemberResult('
      '\n  succeededMembers: $succeededMembers, '
      '\n  failedMembers: $failedMembers,'
      '\n)';
}

/// The priority for sending [Message] in [ChatRoom].
enum MessagePriority {
  /// for [Message] which need high-real-time.
  high,

  /// for [Message] which is normal and non-repetitive-content.
  normal,

  /// for [Message] which no need real-time and can be dropped.
  low,
}

/// The direction for querying the history of [Message].
enum MessageQueryDirection {
  /// from newest to oldest.
  newToOld,

  /// from oldest to newest.
  oldToNew,
}

/// IM Conversation of RTM Plugin.
class Conversation with _Utilities {
  /// The ID of the [Conversation], it will never be `null`.
  final String id;

  /// Which [Client] that the [Conversation] belongs to.
  final Client client;

  /// The raw data of the [Conversation].
  Map get rawData => _rawData;

  /// Indicates whether the [Conversation] is normal and unique, The uniqueness is based on the members when creating.
  bool get isUnique => _rawData['unique'] ?? false;

  /// If the [Conversation.isUnique] is `true`, then it will have an unique-ID.
  String get uniqueID => _rawData['uniqueId'];

  /// Custom field, generally use it to show the name of the [Conversation].
  String get name => _rawData['name'];

  /// Custom field, no strict limit, can store any valid data.
  Map get attributes => _rawData['attr'];

  /// The members of the [Conversation].
  List get members => _rawData['m'];

  /// Indicates whether the [Conversation.client] has muted offline notifications about this [Conversation].
  bool get isMuted => _rawData['mu']?.contains(client.id) ?? false;

  /// The creator of the [Conversation].
  String get creator => _rawData['c'];

  /// The created date of the [Conversation].
  DateTime get createdAt => parseIsoString(_rawData['createdAt']);

  /// The last updated date of the [Conversation].
  DateTime get updatedAt => parseIsoString(_rawData['updatedAt']);

  /// The last [Message] in the [Conversation].
  Message get lastMessage => _lastMessage;

  /// The last date of the [Message] which has been delivered to other [Client].
  DateTime get lastDeliveredAt => parseMilliseconds(_lastDeliveredTimestamp);

  /// The last date of the [Message] which has been read by other [Client].
  DateTime get lastReadAt => parseMilliseconds(_lastReadTimestamp);

  /// The count of the unread [Message] for the [Conversation.client].
  int get unreadMessageCount => _unreadMessageCount;

  /// Indicates whether the unread [Message] list contians any message that mentions the [Conversation.client].
  bool get unreadMessageMentioned => _unreadMessageMentioned ?? false;

  _ConversationType _type;
  Map _rawData;
  Message _lastMessage;
  int _lastDeliveredTimestamp;
  int _lastReadTimestamp;
  int _unreadMessageCount;
  bool _unreadMessageMentioned;

  static Conversation _newInstance({
    @required Client client,
    @required Map rawData,
  }) {
    final String conversationID = rawData['objectId'];
    int typeNumber = rawData['conv_type'];
    _ConversationType type = _ConversationType.normal;
    if (typeNumber != null &&
        typeNumber > 0 &&
        typeNumber <= _ConversationType.values.length) {
      type = _ConversationType.values[typeNumber - 1];
    } else {
      if (rawData['tr'] == true) {
        type = _ConversationType.transient;
      } else if (rawData['sys'] == true) {
        type = _ConversationType.system;
      } else if (rawData['temp'] == true ||
          conversationID.startsWith('_tmp:')) {
        type = _ConversationType.temporary;
      }
    }
    Conversation conversation;
    switch (type) {
      case _ConversationType.normal:
        conversation = Conversation._from(
          id: conversationID,
          client: client,
          type: type,
          rawData: rawData,
        );
        break;
      case _ConversationType.transient:
        conversation = ChatRoom._from(
          id: conversationID,
          client: client,
          type: type,
          rawData: rawData,
        );
        break;
      case _ConversationType.system:
        conversation = ServiceConversation._from(
          id: conversationID,
          client: client,
          type: type,
          rawData: rawData,
        );
        break;
      case _ConversationType.temporary:
        conversation = TemporaryConversation._from(
          id: conversationID,
          client: client,
          type: type,
          rawData: rawData,
        );
        break;
      default:
        conversation = Conversation._from(
          id: conversationID,
          client: client,
          type: type,
          rawData: rawData,
        );
    }
    return conversation;
  }

  Conversation._from({
    @required this.id,
    @required this.client,
    @required _ConversationType type,
    @required Map rawData,
  })  : assert(id != null),
        assert(client != null),
        assert(type != null),
        assert(rawData != null),
        _type = type,
        _rawData = rawData;

  /// To send a [Message] in the [Conversation].
  ///
  /// Set [transient] with `true` means [message] will not be stored, default is `false`.
  /// Set [receipt] with `true` means [Client.onMessageDelivered] and [Client.onMessageRead] will be invoked when other [Client] receive and read the [message], default is `false`.
  /// Set [will] with `true` means other [Client] will receive the [message] when [Conversation.client] is offline, default is `false`.
  /// [priority] only be used for the [Message] which send in the [ChatRoom], default is [MessagePriority.high].
  /// [pushData] is used for customizing offline-notification-content, default is `null`.
  ///
  /// Returns the sent [Message] which has [Message.id] and [Message.sentTimestamp].
  Future<Message> send({
    @required Message message,
    bool transient,
    bool receipt,
    bool will,
    MessagePriority priority,
    Map pushData,
  }) async {
    assert(message != null);
    var options = {};
    if (receipt ?? false) {
      options['receipt'] = true;
    }
    if (will ?? false) {
      options['will'] = true;
    }
    if (_type == _ConversationType.transient && priority != null) {
      options['priority'] = priority.index + 1;
    }
    if (pushData != null) {
      options['pushData'] = pushData;
    }
    if (transient ?? false) {
      message._transient = true;
    }
    message._currentClientID = client.id;
    var args = {
      'clientId': client.id,
      'conversationId': id,
      'message': message._toMap(),
    };
    if (options.isNotEmpty) {
      args['options'] = options;
    }
    if (message is FileMessage) {
      var fileMap = {};
      fileMap['path'] = message._filePath;
      fileMap['data'] = message._fileData;
      fileMap['url'] = message._fileUrl;
      fileMap['format'] = message._fileFormat;
      fileMap['name'] = message._fileName;
      args['file'] = fileMap;
    }
    final Map rawData = await call(
      method: 'sendMessage',
      arguments: args,
    );
    message._loadMap(rawData);
    _updateLastMessage(
      message: message,
    );
    return message;
  }

  /// To read [Conversation.lastMessage] in the [Conversation].
  Future<void> read() async {
    var args = {
      'clientId': client.id,
      'conversationId': id,
    };
    await call(
      method: 'readMessage',
      arguments: args,
    );
  }

  /// To update content of a sent [Message].
  ///
  /// [oldMessage] is the sent [Message].
  /// [newMessage] is the [Message] with new content.
  ///
  /// Returns the updated [Message] which has [Message.patchedTimestamp].
  Future<Message> updateMessage({
    @required Message oldMessage,
    @required Message newMessage,
  }) async {
    assert(newMessage != null);
    return await _patchMessage(
      oldMessage: oldMessage,
      newMessage: newMessage,
    );
  }

  /// To recall a sent [Message].
  ///
  /// [message] is the sent [Message].
  ///
  /// Returns the recalled [Message] which has [Message.patchedTimestamp].
  Future<RecalledMessage> recallMessage({
    @required Message message,
  }) async {
    return await _patchMessage(
      oldMessage: message,
      recall: true,
    );
  }

  /// To fetch last receipt timestamps of the [Message].
  ///
  /// After invoked this method, [Client.onLastDeliveredAtUpdated] and [Client.onLastReadAtUpdated] may will be invoked if the cached timestamp has been updated.
  Future<void> fetchReceiptTimestamps() async {
    var args = {
      'clientId': client.id,
      'conversationId': id,
    };
    return await call(
      method: 'fetchReceiptTimestamp',
      arguments: args,
    );
  }

  /// To query the history of the [Message] which has been sent.
  ///
  /// [startTimestamp]'s default is `null`, unit is millisecond.
  /// [startMessageID]'s default is `null`.
  /// [startClosed]'s default is `false`.
  /// [endTimestamp]'s default is `null`, unit is millisecond.
  /// [endMessageID]'s default is `null`.
  /// [endClosed]'s default is `false`.
  /// [direction]'s default is [MessageQueryDirection.newToOld].
  /// [limit]'s default is `20`, should not more than `100`.
  /// [type]'s default is `null`.
  ///
  /// * you can query message in the specified timestamp interval with [startTimestamp] and [endTimestamp].
  ///   * if you want a more precise interval, provide with [startMessageID] and [endMessageID].
  ///   * if [startClosed] is `true`, that means the query result will contain the [Message] whose [Message.sentTimestamp] is [startTimestamp] and [Message.id] is [startMessageID]. [endClosed] has the same effect on [endTimestamp] and [endMessageID].
  ///   * if the count of messages in the interval is more than [limit], the the query result will be a list of message that length is [limit] from start-endpoint.
  /// * you can query message by vector with one endpoint and [direction].
  ///   * If provide [startTimestamp] or [startTimestamp] with [startMessageID], means provide the start-endpoint of the query vector.
  ///   * If provide [endTimestamp] or [endTimestamp] with [endMessageID], means provide end-endpoint of the query vector.
  /// * you can query message only with [direction].
  ///   * If [direction] is [MessageQueryDirection.newToOld], means query from current timestamp to oldest timestamp.
  ///   * If [direction] is [MessageQueryDirection.oldToNew], means query from oldest timestamp to current timestamp.
  /// * you can query message with [type], it will filter [Message] except the specified [type].
  ///
  /// Returns a list of [Message], the order is from old to new.
  Future<List<Message>> queryMessage({
    int startTimestamp,
    String startMessageID,
    bool startClosed,
    int endTimestamp,
    String endMessageID,
    bool endClosed,
    MessageQueryDirection direction,
    int limit = 20,
    int type,
  }) async {
    var start = {};
    if (startTimestamp != null) {
      start['timestamp'] = startTimestamp;
    }
    if (startMessageID != null) {
      start['id'] = startMessageID;
    }
    if (startClosed != null) {
      start['close'] = startClosed;
    }
    var end = {};
    if (endTimestamp != null) {
      end['timestamp'] = endTimestamp;
    }
    if (endMessageID != null) {
      end['id'] = endMessageID;
    }
    if (endClosed != null) {
      end['close'] = endClosed;
    }
    var args = <dynamic, dynamic>{
      'clientId': client.id,
      'conversationId': id,
    };
    if (start.isNotEmpty) {
      args['start'] = start;
    }
    if (end.isNotEmpty) {
      args['end'] = end;
    }
    if (direction != null) {
      args['direction'] = direction.index + 1;
    }
    if (limit != null) {
      assert(limit >= 1 && limit <= 100);
      args['limit'] = limit;
    }
    if (type != null) {
      args['type'] = type;
    }
    final List rawDatas = await call(
      method: 'queryMessage',
      arguments: args,
    );
    List<Message> messages = [];
    for (var item in rawDatas) {
      messages.add(
        Message._instanceFrom(
          item,
        ),
      );
    }
    return messages;
  }

  /// To let the [Conversation.client] join to the [Conversation].
  ///
  /// Returns a [MemberResult].
  Future<MemberResult> join() async {
    return await _updateMembers(
      members: [client.id],
      op: 'add',
    );
  }

  /// To let the [Conversation.client] quit from the [Conversation].
  ///
  /// Returns a [MemberResult].
  Future<MemberResult> quit() async {
    return await _updateMembers(
      members: [client.id],
      op: 'remove',
    );
  }

  /// To add [members] to the [Conversation].
  ///
  /// [members] should not be empty.
  ///
  /// Returns a [MemberResult].
  Future<MemberResult> addMembers({
    @required Set<String> members,
  }) async {
    return await _updateMembers(
      members: members.toList(),
      op: 'add',
    );
  }

  /// To remove [members] from the [Conversation].
  ///
  /// [members] should not be empty.
  ///
  /// Returns a [MemberResult].
  Future<MemberResult> removeMembers({
    @required Set<String> members,
  }) async {
    return await _updateMembers(
      members: members.toList(),
      op: 'remove',
    );
  }

  /// To turn off the offline notifications for [Conversation.client] about this [Conversation].
  ///
  /// If success, [Conversation.isMuted] will be `true`.
  Future<void> mute() async {
    await _muteToggle(op: 'mute');
  }

  /// To turn on the offline notifications for [Conversation.client] about this [Conversation].
  ///
  /// If success, [Conversation.isMuted] will be `false`.
  Future<void> unmute() async {
    await _muteToggle(op: 'unmute');
  }

  /// To update attributes of the [Conversation].
  ///
  /// [attributes] should not be empty.
  Future<void> updateInfo({
    @required Map<String, dynamic> attributes,
  }) async {
    assert(attributes.isNotEmpty);
    var args = {
      'clientId': client.id,
      'conversationId': id,
      'data': attributes,
    };
    _rawData = await call(
      method: 'updateData',
      arguments: args,
    );
  }

  /// To get the count of the [Conversation.members].
  Future<int> countMembers() async {
    var args = {
      'clientId': client.id,
      'conversationId': id,
    };
    return await call(
      method: 'countMembers',
      arguments: args,
    );
  }

  Future<Message> _patchMessage({
    @required Message oldMessage,
    Message newMessage,
    bool recall = false,
  }) async {
    assert(oldMessage != null);
    var args = {
      'clientId': client.id,
      'conversationId': id,
      'oldMessage': oldMessage._toMap(),
    };
    if (newMessage != null) {
      args['newMessage'] = newMessage._toMap();
      if (newMessage is FileMessage) {
        var fileMap = {};
        fileMap['path'] = newMessage._filePath;
        fileMap['data'] = newMessage._fileData;
        fileMap['url'] = newMessage._fileUrl;
        fileMap['format'] = newMessage._fileFormat;
        fileMap['name'] = newMessage._fileName;
        args['file'] = fileMap;
      }
    }
    if (recall) {
      args['recall'] = true;
    }
    final Map rawData = await call(
      method: 'patchMessage',
      arguments: args,
    );
    Message patchedMessage;
    if (newMessage != null) {
      patchedMessage = newMessage;
    } else if (recall) {
      patchedMessage = RecalledMessage();
    }
    patchedMessage._loadMap(rawData);
    _updateLastMessage(
      message: patchedMessage,
    );
    return patchedMessage;
  }

  Future<MemberResult> _updateMembers({
    @required List<String> members,
    @required String op,
  }) async {
    assert(members.isNotEmpty);
    assert(op == 'add' || op == 'remove');
    var args = {
      'clientId': client.id,
      'conversationId': id,
      'm': members,
      'op': op,
    };
    final Map result = await call(
      method: 'updateMembers',
      arguments: args,
    );
    _rawData['m'] = result['m'];
    _rawData['updatedAt'] = result['udate'];
    return MemberResult._from(result);
  }

  Future<void> _muteToggle({
    @required String op,
  }) async {
    assert(op == 'mute' || op == 'unmute');
    var args = {
      'clientId': client.id,
      'conversationId': id,
      'op': op,
    };
    final Map result = await call(
      method: 'muteToggle',
      arguments: args,
    );
    _rawData['mu'] = result['mu'];
    _rawData['updatedAt'] = result['udate'];
  }

  void _membersUpdate(
    Map args,
  ) {
    final String op = args['op'];
    assert(op == 'joined' ||
        op == 'left' ||
        op == 'members-joined' ||
        op == 'members-left');
    final List m = args['m'];
    final String initBy = args['initBy'];
    final String udate = args['udate'];
    final List members = args['members'];
    if (members != null) {
      _rawData['m'] = members;
    }
    if (udate != null) {
      _rawData['updatedAt'] = udate;
    }
    switch (op) {
      case 'joined':
        if (client.onInvited != null) {
          client.onInvited(
            client: client,
            conversation: this,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'left':
        if (client.onKicked != null) {
          client.onKicked(
            client: client,
            conversation: this,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'members-joined':
        if (client.onMembersJoined != null) {
          client.onMembersJoined(
            client: client,
            conversation: this,
            members: m,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'members-left':
        if (client.onMembersLeft != null) {
          client.onMembersLeft(
            client: client,
            conversation: this,
            members: m,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      default:
        break;
    }
  }

  void _dataUpdate(
    Map args,
  ) {
    final Map rawData = args['rawData'];
    if (rawData != null) {
      _rawData = rawData;
    }
    if (client.onInfoUpdated != null) {
      client.onInfoUpdated(
        client: client,
        conversation: this,
        updatingAttributes: args['attr'],
        updatedAttributes: args['attrModified'],
        byClientID: args['initBy'],
        atDate: parseIsoString(args['udate']),
      );
    }
  }

  void _unreadMessageCountUpdate(
    Map args,
  ) {
    _unreadMessageCount = args['count'];
    final bool mention = args['mention'];
    if (mention != null) {
      _unreadMessageMentioned = mention;
    }
    final Map messageRawData = args['message'];
    if (messageRawData != null) {
      _updateLastMessage(
        message: Message._instanceFrom(
          messageRawData,
        ),
      );
    }
    if (client.onUnreadMessageCountUpdated != null) {
      client.onUnreadMessageCountUpdated(
        client: client,
        conversation: this,
      );
    }
  }

  void _lastReceiptTimestampUpdate(
    Map args,
  ) {
    final int maxReadTimestamp = args['maxReadTimestamp'];
    final int maxAckTimestamp = args['maxAckTimestamp'];
    if (maxReadTimestamp != null) {
      if (_lastReadTimestamp == null ||
          (maxReadTimestamp > _lastReadTimestamp)) {
        _lastReadTimestamp = maxReadTimestamp;
        if (client.onLastReadAtUpdated != null) {
          client.onLastReadAtUpdated(
            client: client,
            conversation: this,
          );
        }
      }
    }
    if (maxAckTimestamp != null) {
      if (_lastDeliveredTimestamp == null ||
          (maxAckTimestamp > _lastDeliveredTimestamp)) {
        _lastDeliveredTimestamp = maxAckTimestamp;
        if (client.onLastDeliveredAtUpdated != null) {
          client.onLastDeliveredAtUpdated(
            client: client,
            conversation: this,
          );
        }
      }
    }
  }

  void _messageReceive(
    Map args,
  ) {
    final Message message = Message._instanceFrom(
      args['message'],
    );
    _updateLastMessage(
      message: message,
    );
    if (client.onMessage != null) {
      client.onMessage(
        client: client,
        conversation: this,
        message: message,
      );
    }
  }

  void _messagePatch(
    Map args,
  ) {
    final Message message = Message._instanceFrom(
      args['message'],
    );
    _updateLastMessage(
      message: message,
    );
    final bool recall = args['recall'] ?? false;
    if (recall) {
      if ((message is RecalledMessage) && client.onMessageRecalled != null) {
        client.onMessageRecalled(
          client: client,
          conversation: this,
          recalledMessage: message,
        );
      }
    } else {
      if (client.onMessageUpdated != null) {
        client.onMessageUpdated(
          client: client,
          conversation: this,
          updatedMessage: message,
          patchCode: args['patchCode'],
          patchReason: args['patchReason'],
        );
      }
    }
  }

  void _messageReceipt(
    Map args,
  ) {
    final bool isRead = args['read'] ?? false;
    final String messageID = args['id'];
    final String from = args['from'];
    final int timestamp = args['t'];
    if (isRead) {
      if (client.onMessageRead != null) {
        client.onMessageRead(
          client: client,
          conversation: this,
          messageID: messageID,
          byClientID: from,
          atDate: parseMilliseconds(timestamp),
        );
      }
    } else {
      if (client.onMessageDelivered != null) {
        client.onMessageDelivered(
          client: client,
          conversation: this,
          messageID: messageID,
          toClientID: from,
          atDate: parseMilliseconds(timestamp),
        );
      }
    }
  }

  void _updateLastMessage({
    @required Message message,
  }) {
    if (lastMessage == null) {
      _lastMessage = message;
    } else if (lastMessage.sentTimestamp != null &&
        message.sentTimestamp != null &&
        message.sentTimestamp >= lastMessage.sentTimestamp) {
      _lastMessage = message;
    }
  }
}

/// IM Chat Room of RTM Plugin.
class ChatRoom extends Conversation {
  ChatRoom._from({
    @required String id,
    @required Client client,
    @required _ConversationType type,
    @required Map rawData,
  }) : super._from(
          id: id,
          client: client,
          type: type,
          rawData: rawData,
        );
}

/// IM Service Conversation of RTM Plugin.
class ServiceConversation extends Conversation {
  /// Indicates whether the [ServiceConversation] has been subscribed by the [Conversation.client].
  bool get isSubscribed => _rawData['joined'] ?? false;

  ServiceConversation._from({
    @required String id,
    @required Client client,
    @required _ConversationType type,
    @required Map rawData,
  }) : super._from(
          id: id,
          client: client,
          type: type,
          rawData: rawData,
        );
}

/// IM Temporary Conversation of RTM Plugin.
class TemporaryConversation extends Conversation {
  /// The living time of the [TemporaryConversation].
  int get timeToLive => _rawData['ttl'];

  TemporaryConversation._from({
    @required String id,
    @required Client client,
    @required _ConversationType type,
    @required Map rawData,
  }) : super._from(
          id: id,
          client: client,
          type: type,
          rawData: rawData,
        );
}

/// IM Message of RTM Plugin.
class Message with _Utilities {
  /// The [Conversation.id] of the [Conversation] which the [Message] belong to.
  String get conversationID => _conversationID;

  /// The ID of the [Message].
  String get id => _id;

  /// The timestamp when send the [Message], unit is millisecond.
  int get sentTimestamp => _timestamp;

  /// The date representation of the [Message.sentTimestamp].
  DateTime get sentDate => parseMilliseconds(_timestamp);

  /// The [Client.id] of the [Client] who send the [Message].
  String get fromClientID => _fromClientID;

  /// The timestamp when update the [Message], unit is millisecond.
  int get patchedTimestamp => _patchedTimestamp;

  /// The date representation of the [Message.patchedTimestamp].
  DateTime get patchedDate => parseMilliseconds(_patchedTimestamp);

  /// The timestamp when the [Message] has been delivered to other.
  int deliveredTimestamp;

  /// The date representation of the [Message.deliveredTimestamp].
  DateTime get deliveredDate => parseMilliseconds(deliveredTimestamp);

  /// The timestamp when the [Message] has been read by other.
  int readTimestamp;

  /// The date representation of the [Message.readTimestamp].
  DateTime get readDate => parseMilliseconds(readTimestamp);

  /// Whether all members in the [Conversation] are mentioned by the [Message].
  bool mentionAll;

  /// The members in the [Conversation] are mentioned by the [Message].
  List mentionMembers;

  /// The string content of the [Message].
  ///
  /// If [Message.binaryContent] exists, [Message.stringContent] will be covered by it.
  String stringContent;

  /// The binary content of the [Message].
  Uint8List binaryContent;

  String _conversationID;
  String _id;
  String _fromClientID;
  String _currentClientID;
  int _timestamp;
  int _patchedTimestamp;
  bool _transient;

  /// To create a new [Message].
  Message();

  static Message _instanceFrom(
    Map rawData,
  ) {
    Message message = Message();
    final Map typeMsgData = rawData['typeMsgData'];
    String jsonString;
    if (typeMsgData != null) {
      final int typeIndex = typeMsgData['_lctype'];
      final TypedMessage Function() constructor =
          TypedMessage._classMap[typeIndex];
      if (constructor != null) {
        message = constructor();
      } else {
        jsonString = jsonEncode(typeMsgData);
      }
    }
    message._loadMap(rawData);
    if (jsonString != null) {
      message.stringContent = jsonString;
    }
    return message;
  }

  Map _toMap() {
    var map = <String, dynamic>{};
    if (_currentClientID != null) {
      map['clientId'] = _currentClientID;
    }
    if (_conversationID != null) {
      map['conversationId'] = _conversationID;
    }
    if (_id != null) {
      map['id'] = _id;
    }
    if (_fromClientID != null) {
      map['from'] = _fromClientID;
    }
    if (_timestamp != null) {
      map['timestamp'] = _timestamp;
    }
    if (_patchedTimestamp != null) {
      map['patchTimestamp'] = _patchedTimestamp;
    }
    if (_transient != null) {
      map['transient'] = _transient;
    }
    if (deliveredTimestamp != null) {
      map['ackAt'] = deliveredTimestamp;
    }
    if (readTimestamp != null) {
      map['readAt'] = readTimestamp;
    }
    if (mentionAll != null) {
      map['mentionAll'] = mentionAll;
    }
    if (mentionMembers != null) {
      map['mentionPids'] = mentionMembers;
    }
    if (binaryContent != null) {
      map['binaryMsg'] = binaryContent;
    } else if (stringContent != null) {
      map['msg'] = stringContent;
    } else if (this is TypedMessage) {
      final Map typedMessageRawData = (this as TypedMessage).rawData;
      typedMessageRawData['_lctype'] = (this as TypedMessage).type;
      map['typeMsgData'] = typedMessageRawData;
    }
    return map;
  }

  void _loadMap(Map data) {
    _currentClientID = data['clientId'];
    _conversationID = data['conversationId'];
    _id = data['id'];
    _fromClientID = data['from'];
    _timestamp = data['timestamp'];
    _patchedTimestamp = data['patchTimestamp'];
    final int ackAt = data['ackAt'];
    if (ackAt != null) {
      deliveredTimestamp = ackAt;
    }
    final int readAt = data['readAt'];
    if (readAt != null) {
      readTimestamp = readAt;
    }
    mentionAll = data['mentionAll'];
    mentionMembers = data['mentionPids'];
    _transient = data['transient'];
    stringContent = data['msg'];
    binaryContent = data['binaryMsg'];
    if (this is TypedMessage) {
      (this as TypedMessage)._rawData = data['typeMsgData'];
    }
  }
}

/// IM Typed Message of RTM Plugin.
class TypedMessage extends Message {
  /// Using [int] to enumerate type of the [TypedMessage].
  int get type => 0;

  /// The custom typed message should be registered before use it.
  ///
  /// You can register constructor of your custom typed message like this:
  /// ```
  /// class YourCustomTypedMessage extends TypedMessage {
  ///   @override
  ///   int get type => 1;
  ///
  ///   YourCustomTypedMessage() : super();
  /// }
  ///
  /// TypedMessage.register(() => YourCustomTypedMessage());
  /// ```
  ///
  /// ***Important:***
  /// [TypedMessage.type] of your custom typed message should be a positive number.
  static void register(
    TypedMessage Function() constructor,
  ) {
    var instance = constructor();
    assert(instance.type > 0);
    TypedMessage._classMap[instance.type] = constructor;
  }

  static final Map<int, TypedMessage Function()> _classMap = {
    TypedMessage().type: () => TypedMessage(),
    TextMessage().type: () => TextMessage(),
    ImageMessage().type: () => ImageMessage(),
    AudioMessage().type: () => AudioMessage(),
    VideoMessage().type: () => VideoMessage(),
    LocationMessage().type: () => LocationMessage(),
    FileMessage().type: () => FileMessage(),
    RecalledMessage().type: () => RecalledMessage(),
  };

  /// To create a new [TypedMessage].
  TypedMessage() : super();

  /// The raw data of the [TypedMessage].
  Map get rawData => _rawData;

  /// The default getter for text of the [TypedMessage].
  String get text => rawData['_lctext'];

  /// The default setter for text of the [TypedMessage].
  set text(String value) => rawData['_lctext'] = value;

  /// The default getter for attributes of the [TypedMessage].
  Map get attributes => rawData['_lcattrs'];

  /// The default setter for attributes of the [TypedMessage].
  set attributes(Map<String, dynamic> value) => rawData['_lcattrs'] = value;

  Map _rawData = {};
}

/// IM Text Message of RTM Plugin.
class TextMessage extends TypedMessage {
  @override
  int get type => -1;

  /// To create a new [TextMessage].
  TextMessage() : super();

  /// To create a new [TextMessage] with [text] content.
  TextMessage.from({
    @required text,
  }) {
    this.text = text;
  }
}

/// IM Image Message of RTM Plugin.
class ImageMessage extends FileMessage {
  @override
  int get type => -2;

  /// The width of the image file, unit is pixel.
  double get width {
    double width;
    final Map metaDataMap = _metaDataMap;
    if (metaDataMap != null) {
      width = metaDataMap['width']?.toDouble();
    }
    return width;
  }

  /// The height of the image file, unit is pixel.
  double get height {
    double height;
    final Map metaDataMap = _metaDataMap;
    if (metaDataMap != null) {
      height = metaDataMap['height']?.toDouble();
    }
    return height;
  }

  /// To create a new [ImageMessage].
  ImageMessage() : super();

  /// To create a new [ImageMessage] from [path] or [binaryData] or [url].
  ///
  /// [path] is for the local path of the local image file.
  /// [binaryData] is for the binary data of the local image file.
  /// [url] is for the URL of the remote image file.
  /// [format] is for the [FileMessage.format], it is optional.
  /// [name] is optional, if provide, the [FileMessage.url] will has a [name] suffix.
  ///
  /// ***Important:***
  /// You must provide only one of parameters in [path], [binaryData] and [url].
  ImageMessage.from({
    String path,
    Uint8List binaryData,
    String url,
    String format,
    String name,
  }) : super.from(
          path: path,
          binaryData: binaryData,
          url: url,
          format: format,
          name: name,
        );
}

/// IM Audio Message of RTM Plugin.
class AudioMessage extends FileMessage {
  @override
  int get type => -3;

  /// The duration of the audio file, unit is second.
  double get duration {
    double duration;
    final Map metaDataMap = _metaDataMap;
    if (metaDataMap != null) {
      duration = metaDataMap['duration']?.toDouble();
    }
    return duration;
  }

  /// To create a new [AudioMessage].
  AudioMessage() : super();

  /// To create a new [AudioMessage] from [path] or [binaryData] or [url].
  ///
  /// [path] is for the local path of the local audio file.
  /// [binaryData] is for the binary data of the local audio file.
  /// [url] is for the URL of the remote audio file.
  /// [format] is for the [FileMessage.format], it is optional.
  /// [name] is optional, if provide, the [FileMessage.url] will has a [name] suffix.
  ///
  /// ***Important:***
  /// You must provide only one of parameters in [path], [binaryData] and [url].
  AudioMessage.from({
    String path,
    Uint8List binaryData,
    String url,
    String format,
    String name,
  }) : super.from(
          path: path,
          binaryData: binaryData,
          url: url,
          format: format,
          name: name,
        );
}

/// IM Video Message of RTM Plugin.
class VideoMessage extends FileMessage {
  @override
  int get type => -4;

  /// The duration of the video file, unit is second.
  double get duration {
    double duration;
    final Map metaDataMap = _metaDataMap;
    if (metaDataMap != null) {
      duration = metaDataMap['duration']?.toDouble();
    }
    return duration;
  }

  /// To create a new [VideoMessage].
  VideoMessage() : super();

  /// To create a new [VideoMessage] from [path] or [binaryData] or [url].
  ///
  /// [path] is for the local path of the local video file.
  /// [binaryData] is for the binary data of the local video file.
  /// [url] is for the URL of the remote video file.
  /// [format] is for the [FileMessage.format], it is optional.
  /// [name] is optional, if provide, the [FileMessage.url] will has a [name] suffix.
  ///
  /// ***Important:***
  /// You must provide only one of parameters in [path], [binaryData] and [url].
  VideoMessage.from({
    String path,
    Uint8List binaryData,
    String url,
    String format,
    String name,
  }) : super.from(
          path: path,
          binaryData: binaryData,
          url: url,
          format: format,
          name: name,
        );
}

/// IM Location Message of RTM Plugin.
class LocationMessage extends TypedMessage {
  @override
  int get type => -5;

  /// The latitude of the geolocation.
  double get latitude {
    double latitude;
    final Map locationMap = _locationMap;
    if (locationMap != null) {
      latitude = locationMap['latitude']?.toDouble();
    }
    return latitude;
  }

  /// The longitude of the geolocation.
  double get longitude {
    double longitude;
    final Map locationMap = _locationMap;
    if (locationMap != null) {
      longitude = locationMap['longitude']?.toDouble();
    }
    return longitude;
  }

  /// To create a new [LocationMessage].
  LocationMessage() : super();

  /// To create a new [LocationMessage] with [latitude] and [longitude].
  LocationMessage.from({
    @required double latitude,
    @required double longitude,
  }) {
    assert(latitude != null && longitude != null);
    _locationMap = {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Map get _locationMap => rawData['_lcloc'];
  set _locationMap(Map value) => rawData['_lcloc'] = value;
}

/// IM File Message of RTM Plugin.
class FileMessage extends TypedMessage {
  @override
  int get type => -6;

  /// The URL of the file.
  String get url {
    String url;
    final Map fileMap = _fileMap;
    if (fileMap != null) {
      url = fileMap['url'];
    }
    return url;
  }

  /// The format extension of the file.
  String get format {
    String format;
    final Map metaDataMap = _metaDataMap;
    if (metaDataMap != null) {
      format = metaDataMap['format'];
    }
    return format;
  }

  /// The size of the file, unit is byte.
  double get size {
    double size;
    final Map metaDataMap = _metaDataMap;
    if (metaDataMap != null) {
      size = metaDataMap['size']?.toDouble();
    }
    return size;
  }

  /// To create a new [FileMessage].
  FileMessage() : super();

  /// To create a new [FileMessage] from [path] or [binaryData] or [url].
  ///
  /// [path] is for the local path of the local file.
  /// [binaryData] is for the binary data of the local file.
  /// [url] is for the URL of the remote file.
  /// [format] is for the [FileMessage.format], it is optional.
  /// [name] is optional, if provide, the [FileMessage.url] will has a [name] suffix.
  ///
  /// ***Important:***
  /// You must provide only one of parameters in [path], [binaryData] and [url].
  FileMessage.from({
    String path,
    Uint8List binaryData,
    String url,
    String format,
    String name,
  }) {
    assert(path != null || binaryData != null || url != null);
    _filePath = path;
    _fileData = binaryData;
    _fileUrl = url;
    _fileFormat = format;
    _fileName = name;
  }

  String _filePath;
  Uint8List _fileData;
  String _fileUrl;
  String _fileFormat;
  String _fileName;

  Map get _fileMap => rawData['_lcfile'];

  Map get _metaDataMap {
    Map metaData;
    final Map fileMap = _fileMap;
    if (fileMap != null) {
      metaData = fileMap['metaData'];
    }
    return metaData;
  }
}

/// IM Recalled Message of RTM Plugin.
class RecalledMessage extends TypedMessage {
  @override
  int get type => -127;

  /// To create a new [RecalledMessage].
  RecalledMessage() : super();
}
