import Flutter
import UIKit
import LeanCloud

public class SwiftLeancloudPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "leancloud_plugin", binaryMessenger: registrar.messenger())
        let instance = SwiftLeancloudPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    var clientMap: [String: IMClientDelegator] = [:]
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Any]
        switch call.method {
        case "initClient":
            let clientId = args["clientId"] as! String
            let tag = args["tag"] as? String
            do {
                let delegator = try IMClientDelegator(ID: clientId, tag: tag)
                self.clientMap[clientId] = delegator
                result([:])
            } catch {
                let err = error as! LCError
                result(["error": ["code": err.code]])
            }
        case "deinitClient":
            let clientId = args["clientId"] as! String
            self.clientMap.removeValue(forKey: clientId)
            result([:])
        case "openClient":
            break
        case "closeClient":
            break
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
