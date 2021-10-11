part of leancloud_plugin;

class _Bridge with _Utilities {
  static final _Bridge _singleton = _Bridge._internal();

  factory _Bridge() {
    return _Bridge._singleton;
  }

  final MethodChannel channel = const MethodChannel('leancloud_plugin');
  final Map<String, Client?> clientMap = <String, Client?>{};

  _Bridge._internal() {
    channel.setMethodCallHandler((call) async {
      final Map args = call.arguments;
      final Client? client = clientMap[args['clientId']!];
      if (client == null) {
        return {};
      }
      switch (call.method) {
        case 'onSessionOpen':
          if (client.onOpened != null) {
            client.onOpened!(
              client: client,
            );
          }
          break;
        case 'onSessionResume':
          if (client.onResuming != null) {
            client.onResuming!(
              client: client,
            );
          }
          break;
        case 'onSessionDisconnect':
          if (client.onDisconnected != null) {
            RTMException? e;
            if (isFailure(args)) {
              e = errorFrom(args);
            }
            client.onDisconnected!(
              client: client,
              exception: e,
            );
          }
          break;
        case 'onSessionClose':
          if (client.onClosed != null) {
            client.onClosed!(
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
            final Signature sign = await client._openSignatureHandler!(
              client: client,
            );
            return {'sign': sign._toMap()};
          }
          break;
        case 'onSignConversation':
          if (client._conversationSignatureHandler != null) {
            Conversation? conversation;
            final String? conversationID = args['conversationId'];
            if (conversationID != null) {
              conversation = await client._getConversation(
                conversationID: conversationID,
              );
            }
            final Signature sign = await client._conversationSignatureHandler!(
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
    required String method,
    required Map arguments,
  }) async {
    final Map result = await _Bridge().channel.invokeMethod(
          method,
          arguments,
        );
    if (isFailure(result)) {
      throw errorFrom(result);
    }
    return result['success'];
  }

  static final DateFormat isoDateFormat = DateFormat(
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    'en_US',
  );

  DateTime? parseIsoString(String? isoString) {
    DateTime? date;
    if (isoString != null) {
      date = _Utilities.isoDateFormat.parseStrict(isoString);
    }
    return date;
  }

  DateTime? parseMilliseconds(int? milliseconds) {
    DateTime? date;
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
  final String? message;

  /// The supplementary information of the [RTMException], it is optional.
  final dynamic details;

  /// To create a [RTMException], [code] is needed.
  RTMException({
    required this.code,
    this.message,
    this.details,
  });

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
    required this.signature,
    required this.timestamp,
    required this.nonce,
  });

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
  final String? tag;

  /// The map of the [Conversation]s which belong to the [Client] in memory, the key is [Conversation.id].
  final Map<String, Conversation> conversationMap = <String, Conversation>{};

  /// The reopened event of the [client].
  void Function({
    required Client client,
  })? onOpened;

  /// The resuming event of the [client].
  void Function({
    required Client client,
  })? onResuming;

  /// The disconnected event of the [client], [exception] is optional.
  ///
  /// This event occurs, for example, when network of local environment unavailable.
  void Function({
    required Client client,
    RTMException? exception,
  })? onDisconnected;

  /// The closed event of the [client], [exception] will never be `null`.
  ///
  /// This event occurs, for example, [client] has been logged off by server.
  void Function({
    required Client client,
    required RTMException exception,
  })? onClosed;

  /// The [client] has been invited to the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    String? byClientID,
    DateTime? atDate,
  })? onInvited;

  /// The [client] has been kicked from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    String? byClientID,
    DateTime? atDate,
  })? onKicked;

  /// Some [members] have joined to the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    List? members,
    String? byClientID,
    DateTime? atDate,
  })? onMembersJoined;

  /// Some [members] have left from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    List? members,
    String? byClientID,
    DateTime? atDate,
  })? onMembersLeft;

  /// Current client be blocked from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    String? byClientID,
    DateTime? atDate,
  })? onBlocked;

  /// Current client be unblocked from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    String? byClientID,
    DateTime? atDate,
  })? onUnblocked;

  /// Some [members] have blocked from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    List? members,
    String? byClientID,
    DateTime? atDate,
  })? onMembersBlocked;

  /// Some [members] have unblocked from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    List? members,
    String? byClientID,
    DateTime? atDate,
  })? onMembersUnBlocked;

  /// Current client be muted from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    String? byClientID,
    DateTime? atDate,
  })? onMuted;

  /// Current client be unmuted from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    String? byClientID,
    DateTime? atDate,
  })? onUnmuted;

  /// Some [members] have muted from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    List? members,
    String? byClientID,
    DateTime? atDate,
  })? onMembersMuted;

  /// Some [members] have unmuted from the [conversation].
  ///
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    List? members,
    String? byClientID,
    DateTime? atDate,
  })? onMembersUnMuted;

  /// The attributes of the [conversation] has been updated.
  ///
  /// [updatingAttributes] means which attributes to be updated.
  /// [updatedAttributes] means result of updating.
  /// [byClientID] means who did it.
  /// [atDate] means when did it.
  void Function({
    required Client client,
    required Conversation conversation,
    Map? updatingAttributes,
    Map? updatedAttributes,
    String? byClientID,
    DateTime? atDate,
  })? onInfoUpdated;

  /// The [Conversation.unreadMessageCount] of the [conversation] has been updated.
  void Function({
    required Client client,
    required Conversation conversation,
  })? onUnreadMessageCountUpdated;

  /// The [Conversation.lastReadAt] of the [conversation] has been updated.
  void Function({
    required Client client,
    required Conversation conversation,
  })? onLastReadAtUpdated;

  /// The [Conversation.lastDeliveredAt] of the [conversation] has been updated.
  void Function({
    required Client client,
    required Conversation conversation,
  })? onLastDeliveredAtUpdated;

  /// [conversation] has a [message].
  ///
  /// If [message] is new one, the [Conversation.lastMessage] of [conversation] will be updated.
  void Function({
    required Client client,
    required Conversation conversation,
    required Message message,
  })? onMessage;

  /// The sent message in [conversation] has been updated to [updatedMessage].
  ///
  /// If [patchCode] or [patchReason] not `null`, means the sent message was updated due to special reason.
  void Function({
    required Client client,
    required Conversation conversation,
    required Message updatedMessage,
    int? patchCode,
    String? patchReason,
  })? onMessageUpdated;

  /// The sent message in the [conversation] has been recalled(updated to [recalledMessage]).
  void Function({
    required Client client,
    required Conversation conversation,
    required RecalledMessage recalledMessage,
  })? onMessageRecalled;

  /// The sent message(ID is [messageID]) that send to [conversation] with [receipt] option, has been delivered to the client(ID is [toClientID]).
  ///
  /// [atDate] means when it occurred.
  void Function({
    required Client client,
    required Conversation conversation,
    String? messageID,
    String? toClientID,
    DateTime? atDate,
  })? onMessageDelivered;

  /// The sent message(ID is [messageID]) that send to [conversation] with [receipt] option, has been read by the client(ID is [toClientID]).
  ///
  /// [atDate] means when it occurred.
  void Function({
    required Client client,
    required Conversation conversation,
    String? messageID,
    String? byClientID,
    DateTime? atDate,
  })? onMessageRead;

  final Future<Signature> Function({
    required Client client,
  })? _openSignatureHandler;

  final Future<Signature> Function({
    required Client client,
    Conversation? conversation,
    List? targetIDs,
    String? action,
  })? _conversationSignatureHandler;

  /// To create an IM [Client] with an [Client.id] and an optional [Client.tag].
  ///
  /// You can implement below signature handlers as required to enable the feature about signature.
  /// * [openSignatureHandler] is a handler for [Client.open].
  /// * [conversationSignatureHandler] is a handler for the functions about [Conversation], details as below:
  ///   * When [action] is `create`, means [Client.createConversation] or [Client.createChatRoom] is invoked.
  ///   * When [action] is `invite`, means [Conversation.join] or [Conversation.addMembers] is invoked.
  ///   * When [action] is `kick`, means [Conversation.quit] or [Conversation.removeMembers] is invoked.
  Client({
    required this.id,
    this.tag,
    Future<Signature> Function({
      required Client client,
    })?
        openSignatureHandler,
    Future<Signature> Function({
      required Client client,
      Conversation? conversation,
      List? targetIDs,
      String? action,
    })?
        conversationSignatureHandler,
  })  : _openSignatureHandler = openSignatureHandler,
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
      args['tag'] = tag!;
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
    required Set<String> members,
    String? name,
    Map<String, dynamic>? attributes,
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
    String? name,
    Map<String, dynamic>? attributes,
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
    required Set<String> members,
    int? timeToLive,
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
    required _ConversationType type,
    bool? isUnique,
    Set<String>? members,
    String? name,
    Map? attributes,
    int? ttl,
  }) async {
    assert(type != _ConversationType.system);
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
    Conversation? conversation = conversationMap[conversationID];
    if (conversation != null) {
      conversation._rawData = rawData;
    } else {
      conversation = Conversation._newInstance(
        client: this,
        rawData: rawData,
      );
      conversationMap[conversationID] = conversation;
    }
    return conversation as T;
  }

  Future<Conversation> _getConversation({
    required String conversationID,
  }) async {
    Conversation? existedConversation = conversationMap[conversationID];
    if (existedConversation != null) {
      return existedConversation;
    }
    var args = {
      'clientId': id,
      'conversationId': conversationID,
    };
    final Map rawData = await call(
      method: 'getConversation',
      arguments: args,
    );
    Conversation? conversation = conversationMap[conversationID];
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

  Future<void> _processConversationEvent({
    required String method,
    required Map args,
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
