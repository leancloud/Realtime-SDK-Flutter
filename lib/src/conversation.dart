part of leancloud_plugin;

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

/// The result of operations for [Conversation.queryBlockedMembers] and [Conversation.queryMutedMembers].
class QueryMemberResult with _Utilities {
  final List members;
  final String? next;

  QueryMemberResult._from(Map data)
      : members = data['client_ids'] ?? [],
        next = data['next'] ?? null;

  @override
  String toString() => '\nLC.RTM.QueryMemberResult('
      '\n  members: $members, '
      '\n  next: $next,'
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

  /// Indicates whether the [Conversation] is normal and unique. The uniqueness is based on the members when creating.
  bool get isUnique => _rawData['unique'] ?? false;

  /// If the [Conversation.isUnique] is `true`, then it will have a unique-ID.
  String? get uniqueID => _rawData['uniqueId'];

  /// Custom field, generally use it to show the name of the [Conversation].
  String? get name => _rawData['name'];

  /// Custom field, no strict limit, can store any valid data.
  Map? get attributes => _rawData['attr'];

  /// The members of the [Conversation].
  List? get members => _rawData['m'];

  /// Indicates whether the [Conversation.client] has muted offline notifications about this [Conversation].
  bool get isMuted => _rawData['mu']?.contains(client.id) ?? false;

  /// The creator of the [Conversation].
  String? get creator => _rawData['c'];

  /// The created date of the [Conversation].
  DateTime? get createdAt => parseIsoString(_rawData['createdAt']);

  /// The last updated date of the [Conversation].
  DateTime? get updatedAt => parseIsoString(_rawData['updatedAt']);

  /// The last [Message] in the [Conversation].
  Message? get lastMessage => _lastMessage;

  /// The timestamp of the last [Message] in the [Conversation].
  int? get lastMessageTimestamp => _lastMessage?.sentTimestamp;

  /// The date of the last [Message] in the [Conversation].
  DateTime? get lastMessageDate => _lastMessage?.sentDate;

  /// The last date of the [Message] which has been delivered to other [Client].
  DateTime? get lastDeliveredAt => parseMilliseconds(_lastDeliveredTimestamp);

  /// The last date of the [Message] which has been read by other [Client].
  DateTime? get lastReadAt => parseMilliseconds(_lastReadTimestamp);

  /// The count of the unread [Message] for the [Conversation.client].
  int get unreadMessageCount => _unreadMessageCount;

  /// Indicates whether the unread [Message] list contians any message that mentions the [Conversation.client].
  bool get unreadMessageMentioned => _unreadMessageMentioned;

  _ConversationType _type;
  Map _rawData = {};
  Message? _lastMessage;
  int? _lastDeliveredTimestamp;
  int? _lastReadTimestamp;
  int _unreadMessageCount = 0;
  bool _unreadMessageMentioned = false;

  static Conversation _newInstance({
    required Client client,
    required Map rawData,
  }) {
    final String conversationID = rawData['objectId'];
    int typeNumber = rawData['conv_type'] ?? -1;
    _ConversationType type = _ConversationType.normal;
    if (typeNumber > 0 && typeNumber <= _ConversationType.values.length) {
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
    required this.id,
    required this.client,
    required _ConversationType type,
    required Map rawData,
  })  : _type = type,
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
    required Message message,
    bool? transient,
    bool? receipt,
    bool? will,
    MessagePriority? priority,
    Map? pushData,
  }) async {
    var options = {};
    if (receipt ?? false) {
      options['receipt'] = true;
    }
    if (will ?? false) {
      options['will'] = true;
      message._will = true;
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
    message._status = MessageStatus.sending;
    try {
      final Map rawData = await call(
        method: 'sendMessage',
        arguments: args,
      );
      message._loadMap(rawData);
      message._status = MessageStatus.sent;
    } catch (e) {
      message._status = MessageStatus.failed;
      rethrow;
    }
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
  /// [oldMessageID] is the [Message.id] of the sent [Message].
  /// [oldMessageTimestamp] is the [Message.sentTimestamp] of the sent [Message].
  /// [newMessage] is the [Message] with new content.
  ///
  /// You can provide either [oldMessage] or [oldMessageID] with [oldMessageTimestamp] to represent the sent [Message];
  /// If provide [oldMessage], then [oldMessageID] with [oldMessageTimestamp] will be ignored;
  /// If not provide both [oldMessage] and [oldMessageID] with [oldMessageTimestamp], then will throw an error.
  ///
  /// Returns the updated [Message] which has [Message.patchedTimestamp].
  Future<Message> updateMessage({
    Message? oldMessage,
    String? oldMessageID,
    int? oldMessageTimestamp,
    required Message newMessage,
  }) async {
    if (oldMessage == null) {
      if (oldMessageID == null) {
        throw ArgumentError.notNull(
          'oldMessageID',
        );
      }
      if (oldMessageTimestamp == null) {
        throw ArgumentError.notNull(
          'oldMessageTimestamp',
        );
      }
    }
    return await _patchMessage(
      oldMessage: oldMessage,
      oldMessageID: oldMessageID,
      oldMessageTimestamp: oldMessageTimestamp,
      newMessage: newMessage,
    );
  }

  /// To recall a sent [Message].
  ///
  /// [message] is the sent [Message].
  /// [messageID] is the [Message.id] of the sent [Message].
  /// [messageTimestamp] is the [Message.sentTimestamp] of the sent [Message].
  ///
  /// You can provide either [message] or [messageID] with [messageTimestamp] to represent the sent [Message];
  /// If provide [message], then [messageID] with [messageTimestamp] will be ignored;
  /// If not provide both [message] and [messageID] with [messageTimestamp], then will throw an error.
  ///
  /// Returns the recalled [Message] which has [Message.patchedTimestamp].
  Future<RecalledMessage> recallMessage({
    Message? message,
    String? messageID,
    int? messageTimestamp,
  }) async {
    if (message == null) {
      if (messageID == null) {
        throw ArgumentError.notNull(
          'messageID',
        );
      }
      if (messageTimestamp == null) {
        throw ArgumentError.notNull(
          'messageTimestamp',
        );
      }
    }
    return await _patchMessage(
      oldMessage: message,
      oldMessageID: messageID,
      oldMessageTimestamp: messageTimestamp,
      recall: true,
    ) as RecalledMessage;
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
    int? startTimestamp,
    String? startMessageID,
    bool? startClosed,
    int? endTimestamp,
    String? endMessageID,
    bool? endClosed,
    MessageQueryDirection? direction,
    int? limit = 20,
    int? type,
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
      if (limit < 1 || limit > 100) {
        throw ArgumentError(
          'limit should in [1...100].',
        );
      }
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
    required Set<String> members,
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
    required Set<String> members,
  }) async {
    return await _updateMembers(
      members: members.toList(),
      op: 'remove',
    );
  }

  /// To block [members] from the [Conversation].
  ///
  /// [members] should not be empty.
  ///
  /// Returns a [MemberResult].
  Future<MemberResult> blockMembers({
    required Set<String> members,
  }) async {
    return await _updateBlockMembers(
      members: members.toList(),
      op: 'block',
    );
  }

  /// To unblock [members] from the [Conversation].
  ///
  /// [members] should not be empty.
  ///
  /// Returns a [MemberResult].
  Future<MemberResult> unblockMembers({
    required Set<String> members,
  }) async {
    return await _updateBlockMembers(
      members: members.toList(),
      op: 'unblock',
    );
  }

  /// Get the blocked members in the conversation.
  ///
  /// [limit]'s default is `50`, should not more than `100`.
  /// [next]'s default is `null`.
  ///
  /// Returns a list of members.
  Future<QueryMemberResult> queryBlockedMembers({
    int? limit = 50,
    String? next,
  }) async {
    var args = <dynamic, dynamic>{
      'clientId': client.id,
      'conversationId': id,
    };
    if (next != null) {
      args['next'] = next;
    }
    if (limit != null) {
      if (limit < 1 || limit > 100) {
        throw ArgumentError(
          'limit should in [1...100].',
        );
      }
      args['limit'] = limit;
    }
    final Map result = await call(
      method: 'queryBlockedMembers',
      arguments: args,
    );
    return QueryMemberResult._from(result);
  }

  /// To mute [members] from the [Conversation].
  ///
  /// [members] should not be empty.
  ///
  /// Returns a [MemberResult].
  Future<MemberResult> muteMembers({
    required Set<String> members,
  }) async {
    return await _updateMuteMembers(
      members: members.toList(),
      op: 'mute',
    );
  }

  /// To unmute [members] from the [Conversation].
  ///
  /// [members] should not be empty.
  ///
  /// Returns a [MemberResult].
  Future<MemberResult> unmuteMembers({
    required Set<String> members,
  }) async {
    return await _updateMuteMembers(
      members: members.toList(),
      op: 'unmute',
    );
  }

  /// Get the muted members in the conversation.
  ///
  /// [limit]'s default is `50`, should not more than `100`.
  /// [next]'s default is `null`.
  ///
  /// Returns a list of members.
  Future<QueryMemberResult> queryMutedMembers({
    int? limit = 50,
    String? next,
  }) async {
    var args = <dynamic, dynamic>{
      'clientId': client.id,
      'conversationId': id,
    };
    if (next != null) {
      args['next'] = next;
    }
    if (limit != null) {
      if (limit < 1 || limit > 100) {
        throw ArgumentError(
          'limit should in [1...100].',
        );
      }
      args['limit'] = limit;
    }
    final Map result = await call(
      method: 'queryMutedMembers',
      arguments: args,
    );
    return QueryMemberResult._from(result);
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
    required Map<String, dynamic> attributes,
  }) async {
    if (attributes.isEmpty) {
      throw ArgumentError(
        'attributes should not be empty.',
      );
    }
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
    Message? oldMessage,
    String? oldMessageID,
    int? oldMessageTimestamp,
    Message? newMessage,
    bool recall = false,
  }) async {
    Map args = {
      'clientId': client.id,
      'conversationId': id,
    };
    if (oldMessage != null) {
      args['oldMessage'] = oldMessage._toMap();
    } else {
      args['oldMessage'] = {
        'clientId': client.id,
        'conversationId': id,
        'id': oldMessageID,
        'timestamp': oldMessageTimestamp,
        'from': client.id,
      };
    }
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
    Message patchedMessage = Message();
    if (newMessage != null) {
      patchedMessage = newMessage;
    }
    if (recall) {
      patchedMessage = RecalledMessage();
    }
    patchedMessage._loadMap(rawData);
    _updateLastMessage(
      message: patchedMessage,
    );
    return patchedMessage;
  }

  Future<MemberResult> _updateMembers({
    required List<String> members,
    required String op,
  }) async {
    if (members.isEmpty) {
      throw ArgumentError(
        'members should not be empty.',
      );
    }
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

  Future<MemberResult> _updateBlockMembers({
    required List<String> members,
    required String op,
  }) async {
    if (members.isEmpty) {
      throw ArgumentError(
        'members should not be empty.',
      );
    }
    assert(op == 'block' || op == 'unblock');
    var args = {
      'clientId': client.id,
      'conversationId': id,
      'm': members,
      'op': op,
    };
    final Map result = await call(
      method: 'updateBlockMembers',
      arguments: args,
    );
    _rawData['m'] = result['m'];
    _rawData['updatedAt'] = result['udate'];
    return MemberResult._from(result);
  }

  Future<MemberResult> _updateMuteMembers({
    required List<String> members,
    required String op,
  }) async {
    if (members.isEmpty) {
      throw ArgumentError(
        'members should not be empty.',
      );
    }
    assert(op == 'mute' || op == 'unmute');
    var args = {
      'clientId': client.id,
      'conversationId': id,
      'm': members,
      'op': op,
    };
    final Map result = await call(
      method: 'updateMuteMembers',
      arguments: args,
    );
    _rawData['m'] = result['m'];
    _rawData['updatedAt'] = result['udate'];
    return MemberResult._from(result);
  }

  Future<void> _muteToggle({
    required String op,
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
        op == 'members-left' ||
        op == 'muted' ||
        op == 'unmuted' ||
        op == 'members-muted' ||
        op == 'members-unmuted' ||
        op == 'blocked' ||
        op == 'unblocked' ||
        op == 'members-blocked' ||
        op == 'members-unblocked');
    final List? m = args['m'];
    final String? initBy = args['initBy'];
    final String? udate = args['udate'];
    final List? members = args['members'];
    if (members != null) {
      _rawData['m'] = members;
    }
    if (udate != null) {
      _rawData['updatedAt'] = udate;
    }
    switch (op) {
      case 'joined':
        if (client.onInvited != null) {
          client.onInvited!(
            client: client,
            conversation: this,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'left':
        if (client.onKicked != null) {
          client.onKicked!(
            client: client,
            conversation: this,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'members-joined':
        if (client.onMembersJoined != null) {
          client.onMembersJoined!(
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
          client.onMembersLeft!(
            client: client,
            conversation: this,
            members: m,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'muted':
        if (client.onMuted != null) {
          client.onMuted!(
            client: client,
            conversation: this,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'unmuted':
        if (client.onUnmuted != null) {
          client.onUnmuted!(
            client: client,
            conversation: this,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'members-muted':
        if (client.onMembersMuted != null) {
          client.onMembersMuted!(
            client: client,
            conversation: this,
            members: m,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'members-unmuted':
        if (client.onMembersUnMuted != null) {
          client.onMembersUnMuted!(
            client: client,
            conversation: this,
            members: m,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'blocked':
        if (client.onBlocked != null) {
          client.onBlocked!(
            client: client,
            conversation: this,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'unblocked':
        if (client.onUnblocked != null) {
          client.onUnblocked!(
            client: client,
            conversation: this,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'members-blocked':
        if (client.onMembersBlocked != null) {
          client.onMembersBlocked!(
            client: client,
            conversation: this,
            members: m,
            byClientID: initBy,
            atDate: parseIsoString(udate),
          );
        }
        break;
      case 'members-unblocked':
        if (client.onMembersUnBlocked != null) {
          client.onMembersUnBlocked!(
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
    final Map? rawData = args['rawData'];
    if (rawData != null) {
      _rawData = rawData;
    }
    if (client.onInfoUpdated != null) {
      client.onInfoUpdated!(
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
    final int? count = args['count'];
    if (count != null) {
      _unreadMessageCount = count;
    }
    final bool? mention = args['mention'];
    if (mention != null) {
      _unreadMessageMentioned = mention;
    }
    final Map? messageRawData = args['message'];
    if (messageRawData != null) {
      _updateLastMessage(
        message: Message._instanceFrom(
          messageRawData,
        ),
      );
    }
    if (client.onUnreadMessageCountUpdated != null) {
      client.onUnreadMessageCountUpdated!(
        client: client,
        conversation: this,
      );
    }
  }

  void _lastReceiptTimestampUpdate(
    Map args,
  ) {
    final int? maxReadTimestamp = args['maxReadTimestamp'];
    final int? maxAckTimestamp = args['maxAckTimestamp'];
    if (maxReadTimestamp != null) {
      if (_lastReadTimestamp == null ||
          (maxReadTimestamp > (_lastReadTimestamp ?? -1))) {
        _lastReadTimestamp = maxReadTimestamp;
        if (client.onLastReadAtUpdated != null) {
          client.onLastReadAtUpdated!(
            client: client,
            conversation: this,
          );
        }
      }
    }
    if (maxAckTimestamp != null) {
      if (_lastDeliveredTimestamp == null ||
          (maxAckTimestamp > (_lastDeliveredTimestamp ?? -1))) {
        _lastDeliveredTimestamp = maxAckTimestamp;
        if (client.onLastDeliveredAtUpdated != null) {
          client.onLastDeliveredAtUpdated!(
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
      client.onMessage!(
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
        client.onMessageRecalled!(
          client: client,
          conversation: this,
          recalledMessage: message,
        );
      }
    } else {
      if (client.onMessageUpdated != null) {
        client.onMessageUpdated!(
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
    final String? messageID = args['id'];
    final String? from = args['from'];
    final int? timestamp = args['t'];
    if (isRead) {
      if (client.onMessageRead != null) {
        client.onMessageRead!(
          client: client,
          conversation: this,
          messageID: messageID,
          byClientID: from,
          atDate: parseMilliseconds(timestamp),
        );
      }
    } else {
      if (client.onMessageDelivered != null) {
        client.onMessageDelivered!(
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
    required Message message,
  }) {
    bool notTransient = (message.isTransient == false);
    bool notWill = ((message._will ?? false) == false);
    bool notTransientConversation = (_type != _ConversationType.transient);
    if (notTransient && notWill && notTransientConversation) {
      if (lastMessage == null) {
        _lastMessage = message;
      } else if (lastMessage?.sentTimestamp != null &&
          message.sentTimestamp != null &&
          (message.sentTimestamp ?? -2) >= (lastMessage?.sentTimestamp ?? -1)) {
        _lastMessage = message;
      }
    }
  }
}

/// IM Chat Room of RTM Plugin.
class ChatRoom extends Conversation {
  ChatRoom._from({
    required String id,
    required Client client,
    required _ConversationType type,
    required Map rawData,
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
    required String id,
    required Client client,
    required _ConversationType type,
    required Map rawData,
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
  int? get timeToLive => _rawData['ttl'];

  TemporaryConversation._from({
    required String id,
    required Client client,
    required _ConversationType type,
    required Map rawData,
  }) : super._from(
          id: id,
          client: client,
          type: type,
          rawData: rawData,
        );
}
