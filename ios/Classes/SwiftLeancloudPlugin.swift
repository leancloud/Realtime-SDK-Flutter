import Flutter
import UIKit
import LeanCloud

var gChannel: FlutterMethodChannel!

public class SwiftLeancloudPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "leancloud_plugin", binaryMessenger: registrar.messenger())
        gChannel = channel
        let instance = SwiftLeancloudPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    static var delegatorMap: [String: IMClientDelegator] = [:]
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        let clientId = arguments["clientId"] as! String
        if call.method == "openClient" {
            let isReconnect = arguments["r"] as? Bool ?? false
            if let delegator = SwiftLeancloudPlugin.delegatorMap[clientId] {
                delegator.open(
                    isReconnect: isReconnect,
                    callback: result)
            } else {
                do {
                    let delegator = try IMClientDelegator(
                        ID: clientId,
                        tag: arguments["tag"] as? String,
                        signRegistry: arguments["signRegistry"] as? [String: Any])
                    delegator.open(
                        isReconnect: isReconnect,
                        callback: result)
                } catch {
                    result(self.error(error))
                }
            }
        } else {
            guard let delegator = SwiftLeancloudPlugin.delegatorMap[clientId] else {
                result(LCError.clientNotFound(ID: clientId))
                return
            }
            switch call.method {
            case "closeClient":
                delegator.close(callback: result)
            case "createConversation":
                delegator.createConversation(parameters: arguments, callback: result)
            case "getConversation":
                delegator.getConversation(parameters: arguments, callback: result)
            case "updateStatus":
                delegator.updateStatus(parameters: arguments, callback: result)
            case "sendMessage":
                delegator.sendMessage(parameters: arguments, callback: result)
            case "readMessage":
                delegator.readMessage(parameters: arguments, callback: result)
            case "updateMessage":
                delegator.updateMessage( parameters: arguments, callback: result)
            default:
                fatalError("unknown method.")
            }
        }
    }
}

extension SwiftLeancloudPlugin: ErrorEncoding {}

class IMClientDelegator: ErrorEncoding, EventNotifying {
    
    let client: IMClient
    let isSignSessionOpen: Bool
    let isSignConversation: Bool
    
    init(ID: String, tag: String?, signRegistry: [String: Any]?) throws {
        self.client = try IMClient(
            ID: ID,
            tag: tag,
            eventQueue: DispatchQueue(
                label: "\(IMClientDelegator.self).eventQueue"))
        self.isSignSessionOpen = (signRegistry?["sessionOpen"] as? Bool) ?? false
        self.isSignConversation = (signRegistry?["conversation"] as? Bool) ?? false
        self.client.delegate = self
        if self.isSignSessionOpen || self.isSignConversation {
            self.client.signatureDelegate = self
        }
    }
    
    func mainAsync(_ value: [String: Any], _ callback: @escaping FlutterResult) {
        DispatchQueue.main.async {
            callback(value)
        }
    }
    
    func open(isReconnect: Bool = false, callback: @escaping FlutterResult) {
        self.client.open(options: isReconnect ? [] : .default) { (result) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    SwiftLeancloudPlugin.delegatorMap[self.client.ID] = self
                }
                self.mainAsync([:], callback);
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func close(callback: @escaping FlutterResult) {
        self.client.close { (result) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    SwiftLeancloudPlugin.delegatorMap.removeValue(forKey: self.client.ID)
                }
                self.mainAsync([:], callback);
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func createConversation(parameters: [String: Any], callback: @escaping FlutterResult) {
        do {
            let convType = parameters["conv_type"] as! Int
            let members = parameters["m"] as? [String] ?? []
            let name = parameters["name"] as? String
            let attributes = parameters["attr"] as? [String: Any]
            if convType == 0 || convType == 1 {
                try self.client.createConversation(
                    clientIDs: Set(members),
                    name: name, attributes: attributes, isUnique: convType == 0)
                { (result) in
                    switch result {
                    case .success(value: let conversation):
                        var rawData = conversation.rawData
                        rawData["objectId"] = conversation.ID
                        rawData["conv_type"] = 1
                        self.mainAsync(["success": rawData], callback)
                    case .failure(error: let error):
                        self.mainAsync(self.error(error), callback)
                    }
                }
            } else if convType == 2 {
                try self.client.createChatRoom(
                    name: name,
                    attributes: attributes)
                { (result) in
                    switch result {
                    case .success(value: let chatRoom):
                        var rawData = chatRoom.rawData
                        rawData["objectId"] = chatRoom.ID
                        rawData["conv_type"] = 2
                        rawData["tr"] = true
                        self.mainAsync(["success": rawData], callback)
                    case .failure(error: let error):
                        self.mainAsync(self.error(error), callback)
                    }
                }
            } else if convType == 4 {
                let ttl = Int32(parameters["ttl"] as? Int ?? 0)
                try self.client.createTemporaryConversation(
                    clientIDs: Set(members),
                    timeToLive: ttl)
                { (result) in
                    switch result {
                    case .success(value: let temporaryConversation):
                        var rawData = temporaryConversation.rawData
                        rawData["objectId"] = temporaryConversation.ID
                        rawData["conv_type"] = 4
                        rawData["temp"] = true
                        rawData["ttl"] = temporaryConversation.timeToLive
                        self.mainAsync(["success": rawData], callback)
                    case .failure(error: let error):
                        self.mainAsync(self.error(error), callback)
                    }
                }
            } else {
                fatalError()
            }
        } catch {
            self.mainAsync(self.error(error), callback)
        }
    }
    
    func getConversation(parameters: [String: Any], callback: @escaping FlutterResult) {
        let conversationId = parameters["conversationId"] as! String
        self.client.getCachedConversation(ID: conversationId) { (result) in
            switch result {
            case .success(value: let conversation):
                var rawData = conversation.rawData
                rawData["objectId"] = conversation.ID
                switch conversation {
                case is IMTemporaryConversation:
                    rawData["conv_type"] = 4
                case is IMServiceConversation:
                    rawData["conv_type"] = 3
                case is IMChatRoom:
                    rawData["conv_type"] = 2
                default:
                    rawData["conv_type"] = 1
                }
                self.mainAsync(["success": rawData], callback)
            case .failure:
                do {
                    if conversationId.hasPrefix("_tmp:") {
                        try self.client.conversationQuery.getTemporaryConversations(by: [conversationId]) { (result) in
                            switch result {
                            case .success(value: let conversations):
                                guard let conversation = conversations.first else {
                                    self.mainAsync(
                                        self.error(
                                            LCError.InternalErrorCode.conversationNotFound.rawValue,
                                            "Conversation not found,",
                                            ["conversationId": conversationId]),
                                        callback)
                                    return
                                }
                                var rawData = conversation.rawData
                                rawData["objectId"] = conversation.ID
                                rawData["conv_type"] = 4
                                self.mainAsync(["success": rawData], callback)
                            case .failure(error: let error):
                                self.mainAsync(self.error(error), callback)
                            }
                        }
                    } else {
                        try self.client.conversationQuery.getConversation(by: conversationId) { (result) in
                            switch result {
                            case .success(value: let conversation):
                                var rawData = conversation.rawData
                                rawData["objectId"] = conversation.ID
                                switch conversation {
                                case is IMTemporaryConversation:
                                    rawData["conv_type"] = 4
                                case is IMServiceConversation:
                                    rawData["conv_type"] = 3
                                case is IMChatRoom:
                                    rawData["conv_type"] = 2
                                default:
                                    rawData["conv_type"] = 1
                                }
                                self.mainAsync(["success": rawData], callback)
                            case .failure(error: let error):
                                self.mainAsync(self.error(error), callback)
                            }
                        }
                    }
                } catch {
                    self.mainAsync(self.error(error), callback)
                }
            }
        }
    }
    
    func updateStatus(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                if let unreadMessageMention = parameters["unreadMessageMention"] as? Bool {
                    conversation.isUnreadMessageContainMention = unreadMessageMention
                }
                self.mainAsync([:], callback)
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func encodingMessage(
        clientID: String,
        conversationID: String,
        message: IMMessage)
        -> [String: Any]
    {
        var messageData: [String: Any] = [
            "clientId": clientID,
            "conversationId": conversationID]
        if let messageID: String = message.ID {
            messageData["id"] = messageID
        }
        if let from: String = message.fromClientID {
            messageData["from"] = from
        }
        if let timestamp: Int64 = message.sentTimestamp {
            messageData["timestamp"] = Int(timestamp)
        }
        if let patchTimestamp: Int64 = message.patchedTimestamp {
            messageData["patchTimestamp"] = Int(patchTimestamp)
        }
        if let ackAt: Int64 = message.deliveredTimestamp {
            messageData["ackAt"] = Int(ackAt)
        }
        if let readAt: Int64 = message.readTimestamp {
            messageData["readAt"] = Int(readAt)
        }
        if let mentionPids: [String] = message.mentionedMembers {
            messageData["mentionPids"] = mentionPids
        }
        if let mentionAll: Bool = message.isAllMembersMentioned {
            messageData["mentionAll"] = mentionAll
        }
        if message.isTransient {
            messageData["transient"] = message.isTransient
        }
        if message is IMCategorizedMessage {
            messageData["typeMsgData"] = (message as? IMCategorizedMessage)?.rawData
        } else if let data: Data = message.content?.data {
            messageData["binaryMsg"] = FlutterStandardTypedData(bytes: data)
        } else if let msg: String = message.content?.string {
            messageData["msg"] = msg
        }
        return messageData
    }
    
    func decodingMessage(parameters: [String: Any], messageRawDataKey: String) throws -> IMMessage {
        let message: IMMessage
        let messageRawData = parameters[messageRawDataKey] as? [String: Any]
        if let msg = messageRawData?["msg"] as? String {
            message = IMMessage()
            try message.set(content: .string(msg))
        } else if let binaryMsg = messageRawData?["binaryMsg"] as? FlutterStandardTypedData {
            message = IMMessage()
            try message.set(content: .data(binaryMsg.data))
        } else if let typeMsgData = messageRawData?["typeMsgData"] as? [String: Any] {
            let typeableMessage: IMCategorizedMessage
            let msgType = typeMsgData["_lctype"] as! Int
            switch msgType {
            case -1:
                typeableMessage = IMTextMessage()
            case -2, -3, -4, -6:
                let fileData = parameters["file"] as? [String: Any]
                let fileFormat = fileData?["format"] as? String
                if let data = fileData?["data"] as? FlutterStandardTypedData {
                    switch msgType {
                    case -2:
                        typeableMessage = IMImageMessage(data: data.data, format: fileFormat)
                    case -3:
                        typeableMessage = IMAudioMessage(data: data.data, format: fileFormat)
                    case -4:
                        typeableMessage = IMVideoMessage(data: data.data, format: fileFormat)
                    case -6:
                        typeableMessage = IMFileMessage(data: data.data, format: fileFormat)
                    default: fatalError()
                    }
                } else if let path = fileData?["path"] as? String {
                    switch msgType {
                    case -2:
                        typeableMessage = IMImageMessage(filePath: path, format: fileFormat)
                    case -3:
                        typeableMessage = IMAudioMessage(filePath: path, format: fileFormat)
                    case -4:
                        typeableMessage = IMVideoMessage(filePath: path, format: fileFormat)
                    case -6:
                        typeableMessage = IMFileMessage(filePath: path, format: fileFormat)
                    default: fatalError()
                    }
                } else if let urlString = fileData?["url"] as? String,
                    let url = URL(string: urlString) {
                    switch msgType {
                    case -2:
                        typeableMessage = IMImageMessage(url: url, format: fileFormat)
                    case -3:
                        typeableMessage = IMAudioMessage(url: url, format: fileFormat)
                    case -4:
                        typeableMessage = IMVideoMessage(url: url, format: fileFormat)
                    case -6:
                        typeableMessage = IMFileMessage(url: url, format: fileFormat)
                    default: fatalError()
                    }
                } else {
                    switch msgType {
                    case -2:
                        typeableMessage = IMImageMessage()
                    case -3:
                        typeableMessage = IMAudioMessage()
                    case -4:
                        typeableMessage = IMVideoMessage()
                    case -6:
                        typeableMessage = IMFileMessage()
                    default: fatalError()
                    }
                }
                if let name = fileData?["name"] as? String {
                    typeableMessage.file?.name = LCString(name)
                }
            case -5:
                typeableMessage = IMLocationMessage()
            case -127:
                typeableMessage = IMRecalledMessage()
            default: fatalError()
            }
            typeMsgData.forEach { (key, value) in
                if key == "_lctext" {
                    typeableMessage.text = value as? String
                } else if key == "_lcattrs"  {
                    typeableMessage.attributes = value as? [String: Any]
                } else if key == "_lcloc" {
                    if let location = value as? [String: Any],
                        let latitude = location["latitude"] as? Double,
                        let longitude = location["longitude"] as? Double {
                        typeableMessage.location = LCGeoPoint(latitude: latitude, longitude: longitude)
                    }
                } else {
                    typeableMessage[key] = value
                }
            }
            message = typeableMessage
        } else {
            message = IMMessage()
        }
        if let mentionAll = messageRawData?["mentionAll"] as? Bool {
            message.isAllMembersMentioned = mentionAll
        }
        if let mentionPids = messageRawData?["mentionPids"] as? [String] {
            message.mentionedMembers = mentionPids
        }
        return message
    }
    
    func sendMessage(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            do {
                switch result {
                case .success(value: let conversation):
                    let message: IMMessage = try self.decodingMessage(
                        parameters: parameters,
                        messageRawDataKey: "message")
                    let options = parameters["options"] as? [String: Any]
                    var sendOptions: IMConversation.MessageSendOptions = []
                    if let receipt = options?["receipt"] as? Bool,
                        receipt {
                        sendOptions.insert(.needReceipt)
                    }
                    if let will = options?["will"] as? Bool,
                        will {
                        sendOptions.insert(.isAutoDeliveringWhenOffline)
                    }
                    if let transient = (parameters["message"] as? [String: Any])?["transient"] as? Bool,
                        transient {
                        sendOptions.insert(.isTransient)
                    }
                    var priority: IMChatRoom.MessagePriority?
                    if let priorityValue = options?["priority"] as? Int {
                        if priorityValue == 1 {
                            priority = .high
                        } else if priorityValue == 2 {
                            priority = .normal
                        } else if priorityValue == 3 {
                            priority = .low
                        }
                    }
                    if let file = (message as? IMCategorizedMessage)?.file,
                        let _ = file.name {
                        file.save(options: .keepFileName) { result in
                            switch result {
                            case .success:
                                do {
                                    try conversation.send(
                                        message: message,
                                        options: sendOptions,
                                        priority: priority,
                                        pushData: options?["pushData"] as? [String: Any])
                                    { (result) in
                                        switch result {
                                        case .success:
                                            let messageData: [String: Any] = self.encodingMessage(
                                                clientID: self.client.ID,
                                                conversationID: conversation.ID,
                                                message: message)
                                            self.mainAsync(["success": messageData], callback)
                                        case .failure(error: let error):
                                            self.mainAsync(self.error(error), callback)
                                        }
                                    }
                                } catch {
                                    self.mainAsync(self.error(error), callback)
                                }
                            case .failure(error: let error):
                                self.mainAsync(self.error(error), callback)
                            }
                        }
                    } else {
                        try conversation.send(
                            message: message,
                            options: sendOptions,
                            priority: priority,
                            pushData: options?["pushData"] as? [String: Any])
                        { (result) in
                            switch result {
                            case .success:
                                let messageData: [String: Any] = self.encodingMessage(
                                    clientID: self.client.ID,
                                    conversationID: conversation.ID,
                                    message: message)
                                self.mainAsync(["success": messageData], callback)
                            case .failure(error: let error):
                                self.mainAsync(self.error(error), callback)
                            }
                        }
                    }
                case .failure(error: let error):
                    self.mainAsync(self.error(error), callback)
                }
            } catch {
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func readMessage(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                conversation.read()
                self.mainAsync([:], callback)
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func updateMessage(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: _):
                fatalError()
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
}

extension IMClientDelegator: IMClientDelegate {
    
    func client(_ client: IMClient, event: IMClientEvent) {
        
    }
    
    func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent) {
        var args: [String: Any] = [
            "clientId": client.ID,
            "conversationId": conversation.ID]
        switch event {
        case let .joined(byClientID: byClientID, at: at):
            args["op"] = "joined"
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = (LCDate(at).jsonValue as? [String: String])?["iso"]
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .left(byClientID: byClientID, at: at):
            args["op"] = "left"
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = (LCDate(at).jsonValue as? [String: String])?["iso"]
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .membersJoined(members: members, byClientID: byClientID, at: at):
            args["op"] = "members-joined"
            args["m"] = members
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = (LCDate(at).jsonValue as? [String: String])?["iso"]
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .membersLeft(members: members, byClientID: byClientID, at: at):
            args["op"] = "members-left"
            args["m"] = members
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = (LCDate(at).jsonValue as? [String: String])?["iso"]
            }
            self.invoke("onConversationMembersUpdate", args)
        case .lastMessageUpdated:
            if let message = conversation.lastMessage {
                args["message"] = self.encodingMessage(
                    clientID: client.ID,
                    conversationID: conversation.ID,
                    message: message)
                self.invoke("onLastMessageUpdate", args)
            }
        case .unreadMessageCountUpdated:
            args["count"] = conversation.unreadMessageCount
            if conversation.isUnreadMessageContainMention {
                args["mention"] = true
            }
            self.invoke("onUnreadMessageCountUpdate", args)
        case let .message(event: messageEvent):
            switch messageEvent {
            case let .received(message: message):
                let messageRawData: [String: Any] = self.encodingMessage(
                    clientID: client.ID,
                    conversationID: conversation.ID,
                    message: message)
                args["message"] = messageRawData
                self.invoke("onMessageReceive", args)
            case let .updated(updatedMessage: message, reason: reason):
                let messageRawData: [String: Any] = self.encodingMessage(
                    clientID: client.ID,
                    conversationID: conversation.ID,
                    message: message)
                args["message"] = messageRawData
                args["patchCode"] = reason?.code
                args["patchReason"] = reason?.reason
                self.invoke("onMessageUpdate", args)
            default:
                break
            }
        default:
            break
        }
    }
}

extension IMClientDelegator: IMSignatureDelegate {
    
    func client(_ client: IMClient, action: IMSignature.Action, signatureHandler: @escaping (IMClient, IMSignature?) -> Void) {
        
    }
}

protocol EventNotifying {
    
    func invoke(_ method: String, _ arguments: [String: Any], _ callback: FlutterResult?)
}

extension EventNotifying {
    
    func invoke(_ method: String, _ arguments: [String: Any], _ callback: FlutterResult? = nil) {
        DispatchQueue.main.async {
            gChannel.invokeMethod(
                method,
                arguments: arguments,
                result: callback)
        }
    }
}

protocol ErrorEncoding {
    
    func error(_ err: Error) -> [String: Any]
    
    func error(_ code: Int, _ message: String?, _ details: [String: Any]?) -> [String: Any]
}

extension ErrorEncoding {
    
    func error(_ err: Error) -> [String: Any] {
        if let error = err as? LCError {
            if error.code == 9977 {
                return self.error(error.code, String(describing: error.underlyingError), error.userInfo)
            } else {
                return self.error(error.code, error.reason, error.userInfo)
            }
        } else {
            return self.error(9977, String(describing: err))
        }
    }
    
    func error(_ code: Int, _ message: String?, _ details: [String: Any]? = nil) -> [String: Any] {
        var error: [String: Any] = ["code": code]
        if let message = message {
            error["message"] = message
        }
        if let details = details {
            error["details"] = details
        }
        return ["error": error]
    }
}

extension LCError {
    
    static func clientNotFound(ID: String) -> [String: Any] {
        return [
            "error": [
                "code": LCError.InternalErrorCode.notFound.rawValue,
                "message": "Client not found.",
                "details": [
                    "clientId": ID]]]
    }
}
