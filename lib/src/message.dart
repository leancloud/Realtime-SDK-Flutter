part of leancloud_plugin;

/// The status for [Message].
enum MessageStatus {
  /// means fail to send.
  failed,

  /// initial state.
  none,

  /// means in sending.
  sending,

  /// means have been sent successfully, [Message.sentTimestamp] will not be `null`.
  sent,

  /// means have been delivered to other successfully, [Message.deliveredTimestamp] will not be `null`.
  delivered,

  /// means have been read by other successfully, [Message.readTimestamp] will not be `null`.
  read,
}

/// IM Message of RTM Plugin.
class Message with _Utilities {
  /// The [Conversation.id] of the [Conversation] which the [Message] belong to.
  String? get conversationID => _conversationID;

  /// The ID of the [Message].
  String? get id => _id;

  /// The status of the [Message].
  MessageStatus get status {
    var value = _status;
    if (value == MessageStatus.sent) {
      if (readTimestamp != null) {
        value = MessageStatus.read;
      } else if (deliveredTimestamp != null) {
        value = MessageStatus.delivered;
      }
    }
    return value;
  }

  /// The timestamp when send the [Message], unit is millisecond.
  int? get sentTimestamp => _timestamp;

  /// The date representation of the [Message.sentTimestamp].
  DateTime? get sentDate => parseMilliseconds(_timestamp);

  /// The [Client.id] of the [Client] who send the [Message].
  String? get fromClientID => _fromClientID;

  /// The timestamp when update the [Message], unit is millisecond.
  int? get patchedTimestamp => _patchedTimestamp;

  /// The date representation of the [Message.patchedTimestamp].
  DateTime? get patchedDate => parseMilliseconds(_patchedTimestamp);

  /// The timestamp when the [Message] has been delivered to other.
  int? deliveredTimestamp;

  /// The date representation of the [Message.deliveredTimestamp].
  DateTime? get deliveredDate => parseMilliseconds(deliveredTimestamp);

  /// The timestamp when the [Message] has been read by other.
  int? readTimestamp;

  /// The date representation of the [Message.readTimestamp].
  DateTime? get readDate => parseMilliseconds(readTimestamp);

  /// Whether all members in the [Conversation] are mentioned by the [Message].
  bool? mentionAll;

  /// The members in the [Conversation] mentioned by the [Message].
  List? mentionMembers;

  /// The string content of the [Message].
  ///
  /// If [Message.binaryContent] exists, [Message.stringContent] will be covered by it.
  String? stringContent;

  /// The binary content of the [Message].
  Uint8List? binaryContent;

  /// Indicates whether this [Message] is transient.
  bool get isTransient => _transient ?? false;

  String? _conversationID;
  String? _id;
  String? _fromClientID;
  String? _currentClientID;
  int? _timestamp;
  int? _patchedTimestamp;
  bool? _transient;
  bool? _will;
  MessageStatus _status = MessageStatus.none;

  /// To create a new [Message].
  Message();

  static Message _instanceFrom(
    Map rawData,
  ) {
    Message message = Message();
    final Map? typeMsgData = rawData['typeMsgData'];
    String? jsonString;
    if (typeMsgData != null) {
      final int? typeIndex = typeMsgData['_lctype'];
      if (typeIndex != null) {
        final TypedMessage Function()? constructor =
            TypedMessage._classMap[typeIndex];
        if (constructor != null) {
          message = constructor();
        } else {
          jsonString = jsonEncode(typeMsgData);
        }
      }
    }
    message._loadMap(rawData);
    if (jsonString != null) {
      message.stringContent = jsonString;
    }
    message._status = MessageStatus.sent;
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
    final int? ackAt = data['ackAt'];
    if (ackAt != null) {
      deliveredTimestamp = ackAt;
    }
    final int? readAt = data['readAt'];
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
    if (instance.type < 1) {
      throw ArgumentError(
        'type should be a positive number',
      );
    }
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
  String? get text => rawData['_lctext'];

  /// The default setter for text of the [TypedMessage].
  set text(String? value) => rawData['_lctext'] = value;

  /// The default getter for attributes of the [TypedMessage].
  Map? get attributes => rawData['_lcattrs'];

  /// The default setter for attributes of the [TypedMessage].
  set attributes(Map? value) => rawData['_lcattrs'] = value;

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
    required String text,
  }) {
    this.text = text;
  }
}

/// IM Image Message of RTM Plugin.
class ImageMessage extends FileMessage {
  @override
  int get type => -2;

  /// The width of the image file, unit is pixel.
  double? get width {
    double? width;
    final Map? metaDataMap = _metaDataMap;
    if (metaDataMap != null) {
      width = metaDataMap['width']?.toDouble();
    }
    return width;
  }

  /// The height of the image file, unit is pixel.
  double? get height {
    double? height;
    final Map? metaDataMap = _metaDataMap;
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
    String? path,
    Uint8List? binaryData,
    String? url,
    String? format,
    String? name,
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
  double? get duration {
    double? duration;
    final Map? metaDataMap = _metaDataMap;
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
    String? path,
    Uint8List? binaryData,
    String? url,
    String? format,
    String? name,
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
  double? get duration {
    double? duration;
    final Map? metaDataMap = _metaDataMap;
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
    String? path,
    Uint8List? binaryData,
    String? url,
    String? format,
    String? name,
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
  double? get latitude {
    double? latitude;
    final Map? locationMap = _locationMap;
    if (locationMap != null) {
      latitude = locationMap['latitude']?.toDouble();
    }
    return latitude;
  }

  /// The longitude of the geolocation.
  double? get longitude {
    double? longitude;
    final Map? locationMap = _locationMap;
    if (locationMap != null) {
      longitude = locationMap['longitude']?.toDouble();
    }
    return longitude;
  }

  /// To create a new [LocationMessage].
  LocationMessage() : super();

  /// To create a new [LocationMessage] with [latitude] and [longitude].
  LocationMessage.from({
    required double latitude,
    required double longitude,
  }) {
    _locationMap = {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Map? get _locationMap => rawData['_lcloc'];
  set _locationMap(Map? value) => rawData['_lcloc'] = value;
}

/// IM File Message of RTM Plugin.
class FileMessage extends TypedMessage {
  @override
  int get type => -6;

  /// The URL of the file.
  String? get url {
    String? url;
    final Map? fileMap = _fileMap;
    if (fileMap != null) {
      url = fileMap['url'];
    }
    return url;
  }

  /// The format extension of the file.
  String? get format {
    String? format;
    final Map? metaDataMap = _metaDataMap;
    if (metaDataMap != null) {
      format = metaDataMap['format'];
    }
    return format;
  }

  /// The size of the file, unit is byte.
  double? get size {
    double? size;
    final Map? metaDataMap = _metaDataMap;
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
    String? path,
    Uint8List? binaryData,
    String? url,
    String? format,
    String? name,
  }) {
    int count = 0;
    if (path != null) {
      count += 1;
    }
    if (binaryData != null) {
      count += 1;
    }
    if (url != null) {
      count += 1;
    }
    if (count != 1) {
      throw ArgumentError(
        'must provide only one of parameters in [path], [binaryData] and [url].',
      );
    }
    _filePath = path;
    _fileData = binaryData;
    _fileUrl = url;
    _fileFormat = format;
    _fileName = name;
  }

  String? _filePath;
  Uint8List? _fileData;
  String? _fileUrl;
  String? _fileFormat;
  String? _fileName;

  Map? get _fileMap => rawData['_lcfile'];

  Map? get _metaDataMap {
    Map? metaData;
    final Map? fileMap = _fileMap;
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
