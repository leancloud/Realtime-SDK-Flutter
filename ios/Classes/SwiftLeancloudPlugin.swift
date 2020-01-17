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
            guard let delegator  = SwiftLeancloudPlugin.delegatorMap[clientId] else {
                result(LCError.clientNotFound(
                    ID: clientId))
                return
            }
            switch call.method {
            case "closeClient":
                delegator.close(callback: result)
            case "createConversation":
                delegator.createConversation(
                    parameters: arguments,
                    callback: result)
            case "getConversation":
                delegator.getConversation(
                    parameters: arguments,
                    callback: result)
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
    
    func sendMessage(parameters: [String: Any], callback: @escaping FlutterResult) {
        self.client.getCachedConversation(
            ID: parameters["conversationId"] as! String)
        { (result) in
            do {
                switch result {
                case .success(value: let conversation):
                    let message: IMMessage
                    let rawData = parameters["message"] as? [String: Any]
                    if let msg = rawData?["msg"] as? String {
                        message = IMMessage()
                        try message.set(content: .string(msg))
                    } else if let binaryMsg = rawData?["msg"] as? FlutterStandardTypedData {
                        message = IMMessage()
                        try message.set(content: .data(binaryMsg.data))
                    } else if let typeMsgData = rawData?["typeMsgData"] as? [String: Any] {
                        fatalError()
                    } else {
                        message = IMMessage()
                    }
                    try conversation.send(message: message) { (result) in
                        switch result {
                        case .success:
                            break
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
}

extension IMClientDelegator: IMClientDelegate {
    
    func client(_ client: IMClient, event: IMClientEvent) {
        
    }
    
    func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent) {
        var args: [String: Any] = [
            "clientId": client.ID,
            "conversationId": conversation.ID,
        ]
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
