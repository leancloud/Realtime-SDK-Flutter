import Flutter
import UIKit
import LeanCloud

public class SwiftLeancloudPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "leancloud_plugin", binaryMessenger: registrar.messenger())
        let instance = SwiftLeancloudPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    var delegatorMap: [String: IMClientDelegator] = [:]
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        switch call.method {
        case "initClient":
            let clientId = args["clientId"] as! String
            let tag = args["tag"] as? String
            do {
                let delegator = try IMClientDelegator(ID: clientId, tag: tag)
                self.delegatorMap[clientId] = delegator
                result([:])
            } catch {
                result(["error": ["code": (error as! LCError).code]])
            }
        case "deinitClient":
            let clientId = args["clientId"] as! String
            self.delegatorMap.removeValue(forKey: clientId)
            result([:])
        case "openClient":
            let clientId = args["clientId"] as! String
            let force = args["force"] as! Bool
            if let delegator = self.delegatorMap[clientId] {
                delegator.client.open(options: force ? .forced : []) { (res) in
                    switch res {
                    case .success:
                        result([:])
                    case .failure(error: let error):
                        result(["error": ["code": error.code]])
                    }
                }
            } else {
                result(["error": ["code": 9973]])
            }
        case "closeClient":
            let clientId = args["clientId"] as! String
            if let delegator = self.delegatorMap[clientId] {
                delegator.client.close { (res) in
                    switch res {
                    case .success:
                        result([:])
                    case .failure(error: let error):
                        result(["error": ["code": error.code]])
                    }
                }
            } else {
                result(["error": ["code": 9973]])
            }
        default:
            fatalError("unknown method.");
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
