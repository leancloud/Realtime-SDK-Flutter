import Flutter
import UIKit
import LeanCloud

var gChannel: FlutterMethodChannel!

public class SwiftLeancloudPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "leancloud_plugin",
            binaryMessenger: registrar.messenger())
        gChannel = channel
        let instance = SwiftLeancloudPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    static var delegatorMap: [String: IMClientDelegator] = [:]
    static let eventQueue = DispatchQueue(
        label: "LC.Flutter.\(SwiftLeancloudPlugin.self).eventQueue")
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        SwiftLeancloudPlugin.eventQueue.async {
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
                        DispatchQueue.main.async {
                            result(self.error(error))
                        }
                    }
                }
            } else {
                guard let delegator = SwiftLeancloudPlugin.delegatorMap[clientId] else {
                    DispatchQueue.main.async {
                        result(LCError.clientNotFound(ID: clientId))
                    }
                    return
                }
                switch call.method {
                case "closeClient":
                    delegator.close(callback: result)
                case "createConversation":
                    delegator.createConversation(parameters: arguments, callback: result)
                case "getConversation":
                    delegator.getConversation(parameters: arguments, callback: result)
                case "sendMessage":
                    delegator.sendMessage(parameters: arguments, callback: result)
                case "readMessage":
                    delegator.readMessage(parameters: arguments, callback: result)
                case "patchMessage":
                    delegator.patchMessage(parameters: arguments, callback: result)
                case "fetchReceiptTimestamp":
                    delegator.fetchReceiptTimestamp(parameters: arguments, callback: result)
                case "queryMessage":
                    delegator.queryMessage(parameters: arguments, callback: result)
                case "updateMembers":
                    delegator.updateMembers(parameters: arguments, callback: result)
                case "updateBlockMembers":
                    delegator.updateBlockMembers(parameters: arguments, callback: result)
                case "updateMuteMembers":
                    delegator.updateMuteMembers(parameters: arguments, callback: result)
                case "queryBlockedMembers":
                    delegator.queryBlockedMembers(parameters: arguments, callback: result)
                case "queryMutedMembers":
                    delegator.queryMutedMembers(parameters: arguments, callback: result)
                case "muteToggle":
                    delegator.muteToggle(parameters: arguments, callback: result)
                case "updateData":
                    delegator.updateData(parameters: arguments, callback: result)
                case "countMembers":
                    delegator.countMembers(parameters: arguments, callback: result)
                case "queryConversation":
                    delegator.queryConversation(parameters: arguments, callback: result)
                default:
                    fatalError("unknown method.")
                }
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
            eventQueue: SwiftLeancloudPlugin.eventQueue)
        self.isSignSessionOpen = (signRegistry?["sessionOpen"] as? Bool) ?? false
        self.isSignConversation = (signRegistry?["conversation"] as? Bool) ?? false
        self.client.delegate = self
        if self.isSignSessionOpen || self.isSignConversation {
            self.client.signatureDelegate = self
        }
        SwiftLeancloudPlugin.delegatorMap[self.client.ID] = self
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
                self.mainAsync([:], callback)
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func close(callback: @escaping FlutterResult) {
        self.client.close { (result) in
            switch result {
            case .success:
                SwiftLeancloudPlugin.delegatorMap.removeValue(forKey: self.client.ID)
                self.mainAsync([:], callback)
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
                    name: name,
                    attributes: attributes,
                    isUnique: convType == 0)
                { (result) in
                    switch result {
                    case .success(value: let conversation):
                        self.mainAsync(["success": conversation.rawData], callback)
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
                        self.mainAsync(["success": chatRoom.rawData], callback)
                    case .failure(error: let error):
                        self.mainAsync(self.error(error), callback)
                    }
                }
            } else if convType == 4 {
                try self.client.createTemporaryConversation(
                    clientIDs: Set(members),
                    timeToLive: Int32(parameters["ttl"] as? Int ?? 0))
                { (result) in
                    switch result {
                    case .success(value: let temporaryConversation):
                        self.mainAsync(["success": temporaryConversation.rawData], callback)
                    case .failure(error: let error):
                        self.mainAsync(self.error(error), callback)
                    }
                }
            } else {
                fatalError("unknown type of conversation.")
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
                self.mainAsync(["success": conversation.rawData], callback)
            case .failure:
                do {
                    let query = self.client.conversationQuery
                    if conversationId.hasPrefix("_tmp:") {
                        try query.getTemporaryConversation(by: conversationId) { (result) in
                            switch result {
                            case .success(value: let conversation):
                                self.mainAsync(["success": conversation.rawData], callback)
                            case .failure(error: let error):
                                self.mainAsync(self.error(error), callback)
                            }
                        }
                    } else {
                        try query.getConversation(by: conversationId) { (result) in
                            switch result {
                            case .success(value: let conversation):
                                self.mainAsync(["success": conversation.rawData], callback)
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
    
    func encodingMessage(
        clientID: String,
        conversationID: String,
        message: IMMessage)
        -> [String: Any]
    {
        var messageData: [String: Any] = [
            "clientId": clientID,
            "conversationId": conversationID]
        if let messageID = message.ID {
            messageData["id"] = messageID
        }
        if let from = message.fromClientID {
            messageData["from"] = from
        }
        if let timestamp = message.sentTimestamp {
            messageData["timestamp"] = Int(timestamp)
        }
        if let patchTimestamp = message.patchedTimestamp {
            messageData["patchTimestamp"] = Int(patchTimestamp)
        }
        if let ackAt = message.deliveredTimestamp {
            messageData["ackAt"] = Int(ackAt)
        }
        if let readAt = message.readTimestamp {
            messageData["readAt"] = Int(readAt)
        }
        if let mentionPids = message.mentionedMembers {
            messageData["mentionPids"] = mentionPids
        }
        if let mentionAll = message.isAllMembersMentioned {
            messageData["mentionAll"] = mentionAll
        }
        if message.isTransient {
            messageData["transient"] = message.isTransient
        }
        if message is IMCategorizedMessage {
            messageData["typeMsgData"] = (message as? IMCategorizedMessage)?.rawData
        } else if let data = message.content?.data {
            messageData["binaryMsg"] = FlutterStandardTypedData(bytes: data)
        } else if let msg = message.content?.string {
            if msg.contains("_lctype"),
                let msgData = msg.data(using: .utf8),
                let typeMsgData = try? JSONSerialization.jsonObject(with: msgData) as? [String: Any],
                let _ = typeMsgData["_lctype"] as? Int {
                messageData["typeMsgData"] = typeMsgData
            } else {
                messageData["msg"] = msg
            }
        }
        return messageData
    }
    
    func decodingMessage(
        parameters: [String: Any],
        messageRawDataKey: String,
        decodingFile: Bool = true)
        throws -> IMMessage
    {
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
                let fileData = decodingFile
                    ? (parameters["file"] as? [String: Any])
                    : nil
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
                    default:
                        fatalError()
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
                    default:
                        fatalError()
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
                    default:
                        fatalError()
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
                    default:
                        fatalError()
                    }
                }
                if let name = fileData?["name"] as? String {
                    typeableMessage.file?.name = LCString(name)
                }
            case -5:
                typeableMessage = IMLocationMessage()
            case -127:
                typeableMessage = IMRecalledMessage()
            default:
                typeableMessage = IMCategorizedMessage()
            }
            typeMsgData.forEach { (key, value) in
                switch key {
                case "_lctext":
                    typeableMessage.text = value as? String
                case "_lcattrs":
                    typeableMessage.attributes = value as? [String: Any]
                case "_lcloc":
                    if let location = value as? [String: Any],
                        let latitude = location["latitude"] as? Double,
                        let longitude = location["longitude"] as? Double {
                        typeableMessage.location = LCGeoPoint(latitude: latitude, longitude: longitude)
                    }
                default:
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
                    let message = try self.decodingMessage(
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
                    if let priorityNumber = options?["priority"] as? Int,
                        let priorityValue = IMChatRoom.MessagePriority(rawValue: priorityNumber) {
                        priority = priorityValue
                    }
                    if let file = (message as? IMCategorizedMessage)?.file,
                        let _ = file.name {
                        file.keepFileName = true
                    }
                    try conversation.send(
                        message: message,
                        options: sendOptions,
                        priority: priority,
                        pushData: options?["pushData"] as? [String: Any])
                    { (result) in
                        switch result {
                        case .success:
                            let messageData = self.encodingMessage(
                                clientID: self.client.ID,
                                conversationID: conversation.ID,
                                message: message)
                            self.mainAsync(["success": messageData], callback)
                        case .failure(error: let error):
                            self.mainAsync(self.error(error), callback)
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
    
    func patchMessage(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                do {
                    let oldMessage = try self.decodingMessage(
                        parameters: parameters,
                        messageRawDataKey: "oldMessage",
                        decodingFile: false)
                    if let data = parameters["oldMessage"] {
                        oldMessage.padding(unsafeFlutterObject: data)
                    }
                    if let recall = parameters["recall"] as? Bool,
                        recall {
                        try conversation.recall(message: oldMessage) { (result) in
                            switch result {
                            case .success(value: let recalledMessage):
                                let messageRawData = self.encodingMessage(
                                    clientID: self.client.ID,
                                    conversationID: conversation.ID,
                                    message: recalledMessage)
                                self.mainAsync(["success": messageRawData], callback)
                            case .failure(error: let error):
                                self.mainAsync(self.error(error), callback)
                            }
                        }
                    } else {
                        let newMessage = try self.decodingMessage(
                            parameters: parameters,
                            messageRawDataKey: "newMessage")
                        if let file = (newMessage as? IMCategorizedMessage)?.file,
                            let _ = file.name {
                            file.keepFileName = true
                        }
                        try conversation.update(oldMessage: oldMessage, to: newMessage) { (result) in
                            switch result {
                            case .success:
                                let messageRawData = self.encodingMessage(
                                    clientID: self.client.ID,
                                    conversationID: conversation.ID,
                                    message: newMessage)
                                self.mainAsync(["success": messageRawData], callback)
                            case .failure(error: let error):
                                self.mainAsync(self.error(error), callback)
                            }
                        }
                    }
                } catch {
                    self.mainAsync(self.error(error), callback)
                }
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func fetchReceiptTimestamp(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                do {
                    try conversation.getMessageReceiptFlag { (result) in
                        switch result {
                        case .success(value: let rcp):
                            var success: [String: Any] = [
                                "clientId": self.client.ID,
                                "conversationId": conversation.ID]
                            if let maxAckTimestamp = rcp.deliveredFlagTimestamp {
                                success["maxAckTimestamp"] = Int(maxAckTimestamp)
                            }
                            if let maxReadTimestamp = rcp.readFlagTimestamp {
                                success["maxReadTimestamp"] = Int(maxReadTimestamp)
                            }
                            self.mainAsync([:], callback)
                            self.invoke("onLastReceiptTimestampUpdate", success)
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
    }
    
    func queryMessage(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                do {
                    var startEndpoint: IMConversation.MessageQueryEndpoint?
                    if let start = parameters["start"] as? [String: Any] {
                        let timestamp = start["timestamp"] as? Int
                        startEndpoint = IMConversation.MessageQueryEndpoint(
                            messageID: start["id"] as? String,
                            sentTimestamp: (timestamp != nil) ? Int64(timestamp!) : nil,
                            isClosed: start["close"] as? Bool)
                    }
                    var endEndpoint: IMConversation.MessageQueryEndpoint?
                    if let end = parameters["end"] as? [String: Any] {
                        let timestamp = end["timestamp"] as? Int
                        endEndpoint = IMConversation.MessageQueryEndpoint(
                            messageID: end["id"] as? String,
                            sentTimestamp: (timestamp != nil) ? Int64(timestamp!) : nil,
                            isClosed: end["close"] as? Bool)
                    }
                    try conversation.queryMessage(
                        start: startEndpoint,
                        end: endEndpoint,
                        direction: IMConversation.MessageQueryDirection(
                            rawValue: (parameters["direction"] as? Int) ?? 1),
                        limit: parameters["limit"] as? Int ?? 20,
                        type: parameters["type"] as? Int,
                        policy: .onlyNetwork)
                    { (result) in
                        switch result {
                        case .success(value: let messages):
                            var messageRawDatas: [[String: Any]] = []
                            messages.forEach { (item) in
                                messageRawDatas.append(self.encodingMessage(
                                    clientID: self.client.ID,
                                    conversationID: conversation.ID,
                                    message: item))
                            }
                            self.mainAsync(["success": messageRawDatas], callback)
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
    }
    
    func updateMembers(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                let op = parameters["op"] as! String
                let m = parameters["m"] as! [String]
                do {
                    let handleResult: (IMConversation.MemberResult) -> Void = { result in
                        switch result {
                        case .allSucceeded:
                            var successData: [String: Any] = ["allowedPids": m]
                            if let members = conversation.members {
                                successData["m"] = members
                            }
                            if let udate = conversation.updatedAt {
                                successData["udate"] = udate.lcDate.isoString
                            }
                            self.mainAsync(["success": successData], callback)
                        case let .slicing(success: success, failure: failure):
                            var successData: [String: Any] = [:]
                            if let sucess = success {
                                successData["allowedPids"] = sucess
                            }
                            var failedPids: [[String: Any]] = []
                            for item in failure {
                                failedPids.append([
                                    "pids": item.IDs,
                                    "error": self.error(item.error),
                                ])
                            }
                            successData["failedPids"] = failedPids
                            if let members = conversation.members {
                                successData["m"] = members
                            }
                            if let udate = conversation.updatedAt {
                                successData["udate"] = udate.lcDate.isoString
                            }
                            self.mainAsync(["success": successData], callback)
                        case let .failure(error: error):
                            self.mainAsync(self.error(error), callback)
                        }
                    }
                    switch op {
                    case "add":
                        try conversation.add(members: Set(m)) { (result) in
                            handleResult(result)
                        }
                    case "remove":
                        try conversation.remove(members: Set(m)) { (result) in
                            handleResult(result)
                        }
                    default:
                        fatalError()
                    }
                } catch {
                    self.mainAsync(self.error(error), callback)
                }
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func updateBlockMembers(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                let op = parameters["op"] as! String
                let m = parameters["m"] as! [String]
                do {
                    let handleResult: (IMConversation.MemberResult) -> Void = { result in
                        switch result {
                        case .allSucceeded:
                            var successData: [String: Any] = ["allowedPids": m]
                            if let members = conversation.members {
                                successData["m"] = members
                            }
                            if let udate = conversation.updatedAt {
                                successData["udate"] = udate.lcDate.isoString
                            }
                            self.mainAsync(["success": successData], callback)
                        case let .slicing(success: success, failure: failure):
                            var successData: [String: Any] = [:]
                            if let sucess = success {
                                successData["allowedPids"] = sucess
                            }
                            var failedPids: [[String: Any]] = []
                            for item in failure {
                                failedPids.append([
                                    "pids": item.IDs,
                                    "error": self.error(item.error),
                                ])
                            }
                            successData["failedPids"] = failedPids
                            if let members = conversation.members {
                                successData["m"] = members
                            }
                            if let udate = conversation.updatedAt {
                                successData["udate"] = udate.lcDate.isoString
                            }
                            self.mainAsync(["success": successData], callback)
                        case let .failure(error: error):
                            self.mainAsync(self.error(error), callback)
                        }
                    }
                    switch op {
                    case "block":
                        try conversation.block(members: Set(m)) { (result) in
                            handleResult(result)
                        }
                    case "unblock":
                        try conversation.unblock(members: Set(m)) { (result) in
                            handleResult(result)
                        }
                    default:
                        fatalError()
                    }
                } catch {
                    self.mainAsync(self.error(error), callback)
                }
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func queryBlockedMembers(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                do {
                    try conversation.getBlockedMembers(
                        limit: parameters["limit"] as? Int ?? 50,
                        next: parameters["next"] as? String)
                    {(result) in
                        switch result {
                        case .success(value: let membersResult):
                            var successData: [String: Any] = [:];
                            successData["client_ids"] = membersResult.members;
                            successData["next"] = membersResult.next;
                            self.mainAsync(["success": successData], callback)
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
    }
    
    func updateMuteMembers(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                let op = parameters["op"] as! String
                let m = parameters["m"] as! [String]
                do {
                    let handleResult: (IMConversation.MemberResult) -> Void = { result in
                        switch result {
                        case .allSucceeded:
                            var successData: [String: Any] = ["allowedPids": m]
                            if let members = conversation.members {
                                successData["m"] = members
                            }
                            if let udate = conversation.updatedAt {
                                successData["udate"] = udate.lcDate.isoString
                            }
                            self.mainAsync(["success": successData], callback)
                        case let .slicing(success: success, failure: failure):
                            var successData: [String: Any] = [:]
                            if let sucess = success {
                                successData["allowedPids"] = sucess
                            }
                            var failedPids: [[String: Any]] = []
                            for item in failure {
                                failedPids.append([
                                    "pids": item.IDs,
                                    "error": self.error(item.error),
                                ])
                            }
                            successData["failedPids"] = failedPids
                            if let members = conversation.members {
                                successData["m"] = members
                            }
                            if let udate = conversation.updatedAt {
                                successData["udate"] = udate.lcDate.isoString
                            }
                            self.mainAsync(["success": successData], callback)
                        case let .failure(error: error):
                            self.mainAsync(self.error(error), callback)
                        }
                    }
                    switch op {
                    case "mute":
                        try conversation.mute(members: Set(m)) { (result) in
                            handleResult(result)
                        }
                    case "unmute":
                        try conversation.unmute(members: Set(m)) { (result) in
                            handleResult(result)
                        }
                    default:
                        fatalError()
                    }
                } catch {
                    self.mainAsync(self.error(error), callback)
                }
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func queryMutedMembers(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                do {
                    try conversation.getMutedMembers(
                        limit: parameters["limit"] as? Int ?? 50,
                        next: parameters["next"] as? String)
                    {(result) in
                        switch result {
                        case .success(value: let membersResult):
                            var successData: [String: Any] = [:];
                            successData["client_ids"] = membersResult.members;
                            successData["next"] = membersResult.next;
                            self.mainAsync(["success": successData], callback)
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
    }
    
    func muteToggle(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                let op = parameters["op"] as! String
                let handleResult: (LCBooleanResult) -> Void = { result in
                    switch result {
                    case .success:
                        var successData: [String: Any] = [:]
                        if let mu = conversation["mu"] as? [String] {
                            successData["mu"] = mu
                        }
                        if let udate = conversation.updatedAt {
                            successData["udate"] = udate.lcDate.isoString
                        }
                        self.mainAsync(["success": successData], callback)
                    case .failure(error: let error):
                        self.mainAsync(self.error(error), callback)
                    }
                }
                switch op {
                case "mute":
                    conversation.mute { (result) in
                        handleResult(result)
                    }
                case "unmute":
                    conversation.unmute { (result) in
                        handleResult(result)
                    }
                default:
                    fatalError()
                }
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func updateData(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                let data = parameters["data"] as! [String: Any]
                do {
                    try conversation.update(attribution: data) { (result) in
                        switch result {
                        case .success:
                            self.mainAsync(["success": conversation.rawData], callback)
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
    }
    
    func countMembers(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            switch result {
            case .success(value: let conversation):
                conversation.countMembers { (result) in
                    switch result {
                    case .success(count: let count):
                        self.mainAsync(["success": count], callback)
                    case .failure(error: let error):
                        self.mainAsync(self.error(error), callback)
                    }
                }
            case .failure(error: let error):
                self.mainAsync(self.error(error), callback)
            }
        }
    }
    
    func queryConversation(parameters: [String: Any], callback: @escaping FlutterResult) {
        do {
            let query = self.client.conversationQuery
            if let limit = parameters["limit"] as? Int {
                query.limit = limit
            }
            if let flag = parameters["flag"] as? Int {
                query.options = IMConversationQuery.Options(rawValue: flag)
            }
            if let tempConvIds = parameters["tempConvIds"] as? [String] {
                try query.getTemporaryConversations(by: Set(tempConvIds)) { (result) in
                    switch result {
                    case .success(value: let conversations):
                        var rawDatas: [[String: Any]] = []
                        for item in conversations {
                            rawDatas.append(item.rawData)
                        }
                        self.mainAsync(["success": rawDatas], callback)
                    case .failure(error: let error):
                        self.mainAsync(self.error(error), callback)
                    }
                }
            } else {
                if let whereString = parameters["where"] as? String {
                    query.whereString = whereString
                }
                if let sort = parameters["sort"] as? String {
                    try query.where(sort, .ascending)
                }
                if let skip = parameters["skip"] as? Int {
                    query.skip = skip
                }
                try query.findConversations { (result) in
                    switch result {
                    case .success(value: let conversations):
                        var rawDatas: [[String: Any]] = []
                        for conversation in conversations {
                            var rawData = conversation.rawData
                            if let options = query.options,
                                options.contains(.containLastMessage),
                                let lastMessage = conversation.lastMessage {
                                rawData["msg"] = self.encodingMessage(
                                    clientID: self.client.ID,
                                    conversationID: conversation.ID,
                                    message: lastMessage)
                            }
                            rawDatas.append(rawData)
                        }
                        self.mainAsync(["success": rawDatas], callback)
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

extension IMClientDelegator: IMClientDelegate {
    
    func client(_ client: IMClient, event: IMClientEvent) {
        var args: [String: Any] = ["clientId": client.ID]
        switch event {
        case .sessionDidOpen:
            self.invoke("onSessionOpen", args)
        case .sessionDidResume:
            self.invoke("onSessionResume", args)
        case .sessionDidPause(error: let error):
            args.merge(self.error(error)) { (current, _) in current }
            self.invoke("onSessionDisconnect", args)
        case .sessionDidClose(error: let error):
            args.merge(self.error(error)) { (current, _) in current }
            self.invoke("onSessionClose", args)
        }
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
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .left(byClientID: byClientID, at: at):
            args["op"] = "left"
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .membersJoined(members: members, byClientID: byClientID, at: at):
            args["op"] = "members-joined"
            args["m"] = members
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .membersLeft(members: members, byClientID: byClientID, at: at):
            args["op"] = "members-left"
            args["m"] = members
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .blocked(byClientID: byClientID, at: at):
            args["op"] = "blocked"
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .unblocked(byClientID: byClientID, at: at):
            args["op"] = "unblocked"
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .muted(byClientID: byClientID, at: at):
            args["op"] = "muted"
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .unmuted(byClientID: byClientID, at: at):
            args["op"] = "unmuted"
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .membersBlocked(members: members, byClientID: byClientID, at: at):
            args["op"] = "members-blocked"
            args["m"] = members
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .membersUnblocked(members: members, byClientID: byClientID, at: at):
            args["op"] = "members-unblocked"
            args["m"] = members
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .membersMuted(members: members, byClientID: byClientID, at: at):
            args["op"] = "members-muted"
            args["m"] = members
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case let .membersUnmuted(members: members, byClientID: byClientID, at: at):
            args["op"] = "members-unmuted"
            args["m"] = members
            args["members"] = conversation.members
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationMembersUpdate", args)
        case .unreadMessageCountUpdated:
            let count = conversation.unreadMessageCount
            args["count"] = count
            args["mention"] = conversation.isUnreadMessageContainMention
            if count > 0,
                let message = conversation.lastMessage {
                args["message"] = self.encodingMessage(
                    clientID: client.ID,
                    conversationID: conversation.ID,
                    message: message)
            }
            self.invoke("onUnreadMessageCountUpdate", args)
        case let .dataUpdated(updatingData: updatingData, updatedData: updatedData, byClientID: byClientID, at: at):
            args["attr"] = updatingData
            args["attrModified"] = updatedData
            args["rawData"] = conversation.rawData
            args["initBy"] = byClientID
            if let at = at {
                args["udate"] = at.lcDate.isoString
            }
            self.invoke("onConversationDataUpdate", args)
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
                let messageRawData = self.encodingMessage(
                    clientID: client.ID,
                    conversationID: conversation.ID,
                    message: message)
                if let recalledMessage = message as? IMRecalledMessage,
                    recalledMessage.isRecall {
                    args["recall"] = true
                }
                args["message"] = messageRawData
                args["patchCode"] = reason?.code
                args["patchReason"] = reason?.reason
                self.invoke("onMessagePatch", args)
            case let .delivered(toClientID: toClientID, messageID: messageID, deliveredTimestamp: deliveredTimestamp):
                args["id"] = messageID
                args["t"] = Int(deliveredTimestamp)
                if let from = toClientID {
                    args["from"] = from
                }
                args["read"] = false
                self.invoke("onMessageReceipt", args)
            case let .read(byClientID: byClientID, messageID: messageID, readTimestamp: readTimestamp):
                args["id"] = messageID
                args["t"] = Int(readTimestamp)
                if let from = byClientID {
                    args["from"] = from
                }
                args["read"] = true
                self.invoke("onMessageReceipt", args)
            }
        default:
            break
        }
    }
}

extension IMClientDelegator: IMSignatureDelegate {
    
    func client(_ client: IMClient, action: IMSignature.Action, signatureHandler: @escaping (IMClient, IMSignature?) -> Void) {
        let handleSignResult: (Any?) -> Void = { result in
            if let result = result as? [String: Any],
                let sign = result["sign"] as? [String: Any],
                let s = sign["s"] as? String,
                let n = sign["n"] as? String,
                let t = sign["t"] as? Int {
                signatureHandler(client, IMSignature(
                    signature: s,
                    timestamp: Int64(t),
                    nonce: n))
            }
        }
        switch action {
        case .open:
            if self.isSignSessionOpen {
                self.invoke("onSignSessionOpen", ["clientId": client.ID]) { (result) in
                    handleSignResult(result)
                }
            } else {
                signatureHandler(client, nil)
            }
        case let .createConversation(memberIDs: memberIDs):
            if self.isSignConversation {
                self.invoke("onSignConversation", [
                    "clientId": client.ID,
                    "targetIds": Array(memberIDs),
                    "action": "create"])
                { (result) in
                    handleSignResult(result)
                }
            } else {
                signatureHandler(client, nil)
            }
        case let .add(memberIDs: memberIDs, toConversation: conversation):
            if self.isSignConversation {
                self.invoke("onSignConversation", [
                    "clientId": client.ID,
                    "conversationId": conversation.ID,
                    "targetIds": Array(memberIDs),
                    "action": "invite"])
                { (result) in
                    handleSignResult(result)
                }
            } else {
                signatureHandler(client, nil)
            }
        case let .remove(memberIDs: memberIDs, fromConversation: conversation):
            if self.isSignConversation {
                self.invoke("onSignConversation", [
                    "clientId": client.ID,
                    "conversationId": conversation.ID,
                    "targetIds": Array(memberIDs),
                    "action": "kick"])
                { (result) in
                    handleSignResult(result)
                }
            } else {
                signatureHandler(client, nil)
            }
        default:
            signatureHandler(client, nil)
        }
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
