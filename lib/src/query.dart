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

  _LCCompositionalCondition condition = _LCCompositionalCondition();

  ConversationQuery whereEqualTo(
    String key,
    dynamic value,
  ) {
    condition.whereEqualTo(key, value);
    return this;
  }

  ConversationQuery whereNotEqualTo(
    String key,
    dynamic value,
  ) {
    condition.whereNotEqualTo(key, value);
    return this;
  }

  ConversationQuery whereContainedIn(
    String key,
    List values,
  ) {
    condition.whereContainedIn(key, values);
    return this;
  }

  ConversationQuery whereNotContainedIn(
    String key,
    List values,
  ) {
    condition.whereNotContainedIn(key, values);
    return this;
  }

  ConversationQuery whereContainsAll(
    String key,
    List values,
  ) {
    condition.whereContainsAll(key, values);
    return this;
  }

  ConversationQuery whereExists(
    String key,
  ) {
    condition.whereExists(key);
    return this;
  }

  ConversationQuery whereDoesNotExist(
    String key,
  ) {
    condition.whereDoesNotExist(key);
    return this;
  }

  ConversationQuery whereSizeEqualTo(
    String key,
    int size,
  ) {
    condition.whereSizeEqualTo(key, size);
    return this;
  }

  ConversationQuery whereGreaterThan(
    String key,
    dynamic value,
  ) {
    condition.whereGreaterThan(key, value);
    return this;
  }

  ConversationQuery whereGreaterThanOrEqualTo(
    String key,
    dynamic value,
  ) {
    condition.whereGreaterThanOrEqualTo(key, value);
    return this;
  }

  ConversationQuery whereLessThan(
    String key,
    dynamic value,
  ) {
    condition.whereLessThan(key, value);
    return this;
  }

  ConversationQuery whereLessThanOrEqualTo(
    String key,
    dynamic value,
  ) {
    condition.whereLessThanOrEqualTo(key, value);
    return this;
  }

  ConversationQuery whereStartsWith(
    String key,
    String prefix,
  ) {
    condition.whereStartsWith(key, prefix);
    return this;
  }

  ConversationQuery whereEndsWith(
    String key,
    String suffix,
  ) {
    condition.whereEndsWith(key, suffix);
    return this;
  }

  ConversationQuery whereContains(
    String key,
    String subString,
  ) {
    condition.whereContains(key, subString);
    return this;
  }

  ConversationQuery whereMatches(
    String key,
    String regex, {
    String modifiers,
  }) {
    condition.whereMatches(key, regex, modifiers);
    return this;
  }

  ConversationQuery whereMatchesQuery(
    String key,
    ConversationQuery query,
  ) {
    condition.whereMatchesQuery(key, query);
    return this;
  }

  ConversationQuery whereDoesNotMatchQuery(
    String key,
    ConversationQuery query,
  ) {
    condition.whereDoesNotMatchQuery(key, query);
    return this;
  }

  ConversationQuery orderByAscending(
    String key,
  ) {
    condition.orderByAscending(key);
    return this;
  }

  ConversationQuery orderByDescending(
    String key,
  ) {
    condition.orderByDecending(key);
    return this;
  }

  ConversationQuery addAscendingOrder(
    String key,
  ) {
    condition.addAscendingOrder(key);
    return this;
  }

  ConversationQuery addDescendingOrder(
    String key,
  ) {
    condition.addDescendingOrder(key);
    return this;
  }

  static ConversationQuery and(
    List<ConversationQuery> queries,
  ) {
    if (queries == null || queries.length < 1) {
      throw ArgumentError.notNull(
        'queries',
      );
    }
    ConversationQuery compositionQuery = ConversationQuery._from(
      client: queries.first.client,
    );
    for (var query in queries) {
      if (query.client != compositionQuery.client) {
        throw ArgumentError(
          'ConversationQuery.client inconsistency',
        );
      }
      compositionQuery.condition.add(query.condition);
    }
    return compositionQuery;
  }

  static ConversationQuery or(
    List<ConversationQuery> queries,
  ) {
    if (queries == null || queries.length < 1) {
      throw ArgumentError.notNull(
        'queries',
      );
    }
    ConversationQuery compositionQuery = ConversationQuery._from(
      client: queries.first.client,
    );
    compositionQuery.condition = _LCCompositionalCondition(
      composition: _LCCompositionalCondition.Or,
    );
    for (var query in queries) {
      if (query.client != compositionQuery.client) {
        throw ArgumentError(
          'ConversationQuery.client inconsistency',
        );
      }
      compositionQuery.condition.add(query.condition);
    }
    return compositionQuery;
  }

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
      Map params = condition._buildParams();
      if (whereString != null) {
        args['where'] = whereString;
      } else if (params['where'] != null) {
        args['where'] = params['where'];
      }
      if (sort != null) {
        args['sort'] = sort;
      } else if (params['order'] != null) {
        args['sort'] = params['order'];
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

abstract class _LCQueryCondition {
  bool equals(_LCQueryCondition other);

  Map<String, dynamic> encode();
}

class _LCCompositionalCondition extends _LCQueryCondition {
  static const String And = '\$and';
  static const String Or = '\$or';

  String composition;

  List<_LCQueryCondition> conditionList;

  List<String> orderByList;

  _LCCompositionalCondition({
    this.composition = And,
  }) {
    conditionList = [];
  }

  void whereEqualTo(String key, dynamic value) {
    add(_LCEqualCondition(key, value));
  }

  void whereNotEqualTo(String key, dynamic value) {
    addOperation(key, '\$ne', value);
  }

  void whereContainedIn(String key, Iterable values) {
    addOperation(key, '\$in', values);
  }

  void whereNotContainedIn(String key, Iterable values) {
    addOperation(key, '\$nin', values);
  }

  void whereContainsAll(String key, Iterable values) {
    addOperation(key, '\$all', values);
  }

  void whereExists(String key) {
    addOperation(key, '\$exists', true);
  }

  void whereDoesNotExist(String key) {
    addOperation(key, '\$exists', false);
  }

  void whereSizeEqualTo(String key, int size) {
    addOperation(key, '\$size', size);
  }

  void whereGreaterThan(String key, dynamic value) {
    addOperation(key, '\$gt', value);
  }

  void whereGreaterThanOrEqualTo(String key, dynamic value) {
    addOperation(key, '\$gte', value);
  }

  void whereLessThan(String key, dynamic value) {
    addOperation(key, '\$lt', value);
  }

  void whereLessThanOrEqualTo(String key, dynamic value) {
    addOperation(key, '\$lte', value);
  }

  void whereStartsWith(String key, String prefix) {
    addOperation(key, '\$regex', '^$prefix.*');
  }

  void whereEndsWith(String key, String suffix) {
    addOperation(key, '\$regex', '.*$suffix\$');
  }

  void whereContains(String key, String subString) {
    addOperation(key, '\$regex', '.*$subString.*');
  }

  void whereMatches(String key, String regex, String modifiers) {
    Map<String, dynamic> value = {
      '\$regex': regex,
    };
    if (modifiers != null) {
      value['\$options'] = modifiers;
    }
    add(_LCEqualCondition(key, value));
  }

  void whereMatchesQuery(String key, ConversationQuery query) {
    Map<String, dynamic> inQuery = {
      'where': query.condition,
    };
    addOperation(key, '\$inQuery', inQuery);
  }

  void whereDoesNotMatchQuery(String key, ConversationQuery query) {
    Map<String, dynamic> inQuery = {
      'where': query.condition,
    };
    addOperation(key, '\$notInQuery', inQuery);
  }

  void orderByAscending(String key) {
    orderByList = [];
    orderByList.add(key);
  }

  void orderByDecending(String key) {
    orderByAscending('-$key');
  }

  void addAscendingOrder(String key) {
    if (orderByList == null) {
      orderByList = [];
    }
    orderByList.add(key);
  }

  void addDescendingOrder(String key) {
    addAscendingOrder('-$key');
  }

  void addOperation(String key, String op, dynamic value) {
    _LCOperationCondition cond = _LCOperationCondition(key, op, value);
    add(cond);
  }

  void add(_LCQueryCondition cond) {
    if (cond == null) {
      return;
    }
    conditionList.removeWhere((item) => item.equals(cond));
    conditionList.add(cond);
  }

  @override
  bool equals(_LCQueryCondition other) {
    return false;
  }

  @override
  Map<String, dynamic> encode() {
    if (conditionList == null || conditionList.length == 0) {
      return null;
    }
    if (conditionList.length == 1) {
      return conditionList[0].encode();
    }
    return {
      composition: _LCEncoder.encodeList(conditionList),
    };
  }

  Map<String, dynamic> _buildParams() {
    Map<String, dynamic> result = {};
    if (conditionList != null && conditionList.length > 0) {
      result['where'] = jsonEncode(encode());
    }
    if (orderByList != null && orderByList.length > 0) {
      result['order'] = orderByList.join(',');
    }
    return result;
  }
}

class _LCEqualCondition extends _LCQueryCondition {
  String key;
  dynamic value;

  _LCEqualCondition(this.key, this.value);

  @override
  bool equals(_LCQueryCondition other) {
    if (other is _LCEqualCondition) {
      return key == other.key;
    }
    return false;
  }

  @override
  Map<String, dynamic> encode() {
    return {
      key: _LCEncoder.encode(value),
    };
  }
}

class _LCOperationCondition extends _LCQueryCondition {
  String key;
  String op;
  dynamic value;

  _LCOperationCondition(this.key, this.op, this.value);

  @override
  bool equals(_LCQueryCondition other) {
    if (other is _LCOperationCondition) {
      return key == other.key && op == other.op;
    }
    return false;
  }

  @override
  Map<String, dynamic> encode() {
    return {
      key: {
        op: _LCEncoder.encode(value),
      }
    };
  }
}

class _LCEncoder with _Utilities {
  static dynamic encode(dynamic object) {
    if (object is DateTime) {
      return encodeDateTime(object);
    }
    if (object is Uint8List) {
      return encodeBytes(object);
    }
    if (object is List) {
      return encodeList(object);
    }
    if (object is Map) {
      return encodeMap(object);
    }
    if (object is _LCQueryCondition) {
      return object.encode();
    }
    return object;
  }

  static dynamic encodeDateTime(
    DateTime dateTime,
  ) {
    return {
      '__type': 'Date',
      'iso': _Utilities.isoDateFormat.format(dateTime),
    };
  }

  static dynamic encodeBytes(
    Uint8List bytes,
  ) {
    return {
      '__type': 'Bytes',
      'base64': base64Encode(bytes),
    };
  }

  static dynamic encodeList(List list) {
    List l = [];
    for (var item in list) {
      l.add(encode(item));
    }
    return l;
  }

  static dynamic encodeMap(Map map) {
    Map m = {};
    map.forEach((key, value) {
      m[key] = encode(value);
    });
    return m;
  }
}
