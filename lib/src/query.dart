part of leancloud_plugin;

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
