import Flutter
import UIKit
import LeanCloud

public class SwiftLeancloudPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "leancloud_plugin", binaryMessenger: registrar.messenger())
        let instance = SwiftLeancloudPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as! [String: Any]
        switch call.method {
        case "openClient":
            self.openClient(arguments: arguments, completion: result)
        case "closeClient":
            self.closeClient(arguments: arguments, completion: result)
        default:
            fatalError("unknown method.");
        }
    }
    
    static var delegatorMap: [String: IMClientDelegator] = [:]
    
    func openClient(arguments: [String: Any], completion: @escaping FlutterResult) {
        let clientId = arguments["clientId"] as! String
        let delegator: IMClientDelegator
        if let _delegator = SwiftLeancloudPlugin.delegatorMap[clientId] {
            delegator = _delegator
        } else {
            do {
                let tag = arguments["tag"] as? String
                delegator = try IMClientDelegator(ID: clientId, tag: tag)
                SwiftLeancloudPlugin.delegatorMap[clientId] = delegator
            } catch {
                completion(self.error(error))
                return
            }
        }
        let force = (arguments["force"] as? Bool) ?? true
        delegator.client.open(options: force ? .forced : []) { (result) in
            switch result {
            case .success:
                completion([:])
            case .failure(error: let error):
                completion(self.error(error))
            }
        }
    }
    
    func closeClient(arguments: [String: Any], completion: @escaping FlutterResult) {
        let clientId = arguments["clientId"] as! String
        if let delegator = SwiftLeancloudPlugin.delegatorMap[clientId] {
            delegator.client.close { (result) in
                switch result {
                case .success:
                    SwiftLeancloudPlugin.delegatorMap.removeValue(forKey: clientId)
                    completion([:])
                case .failure(error: let error):
                    completion(self.error(error))
                }
            }
        } else {
            completion(self.clientNotFound)
        }
    }
}

class IMClientDelegator: IMClientDelegate {
    
    let client: IMClient
    
    init(ID: String, tag: String?) throws {
        self.client = try IMClient(ID: ID, tag: tag)
        self.client.delegate = self
    }
    
    func client(_ client: IMClient, event: IMClientEvent) {
        
    }
    
    func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent) {
        
    }
}

extension SwiftLeancloudPlugin {
    
    // MARK: Error
    
    var clientNotFound: [String: Any] {
        return self.error(
            code: 9973,
            message: "client not found.")
    }
    
    func error(code: Int, message: String?, details: [String: Any]? = nil) -> [String: Any] {
        var error: [String: Any] = ["code": code]
        if let message = message {
            error["message"] = message
        }
        if let details = details {
            error["details"] = details
        }
        return ["error": error]
    }
    
    func error(_ err: Error) -> [String: Any] {
        if let error = err as? LCError {
            if error.code == 9977 {
                return self.error(
                    code: error.code,
                    message: String(describing: error.underlyingError),
                    details: error.userInfo)
            } else {
                return self.error(
                    code: error.code,
                    message: error.reason,
                    details: error.userInfo)
            }
        } else {
            return self.error(
                code: 9977,
                message: String(describing: err))
        }
    }
}
