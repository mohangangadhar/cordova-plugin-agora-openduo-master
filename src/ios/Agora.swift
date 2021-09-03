/*
 * Notes: The @objc shows that this class & function should be exposed to Cordova.
 */
@objc(Agora) class Agora : CDVPlugin {
    @objc(initAgora:) // Declare your function name.
    func initAgora(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "The Plugin Failed");
        if((command.argument(at: 0)) != nil) {
            AgoraEngine.instance.initAgora(agoraAppId: command.argument(at: 0) as! String);
            AgoraEngine.instance.setViewController(vc: self.viewController);
            pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "The plugin succeeded");
        }
        // Send the function result back to Cordova.
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
    }
    
    @objc(loginUser:) // Declare your function name.
    func loginUser(command: CDVInvokedUrlCommand) {
        if((command.argument(at: 1)) != nil) {
            let tokenIn: String? = command.arguments[0] as? String ?? nil;
            let accIn: String = command.arguments[1] as? String ?? String.init(describing: command.arguments[1]);
            AgoraEngine.instance.getRtmKit().login(account: accIn, token: tokenIn, success: { () in
                AgoraEngine.instance.setViewController(vc: self.viewController);
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Logged in");
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            },fail: { (error) in
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: String(error.localizedDescription).hasSuffix("8") ? "LOGIN_ERR_ALREADY_LOGGED_IN" : error.localizedDescription);
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            })
        } else {
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "LOGIN_ERR_INVALID_PEER_ID");
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
        }
    }
    
    @objc(callUser:) // Declare your function name.
    func callUser(command: CDVInvokedUrlCommand) {
        let peerId: String = command.arguments[0] as? String ?? String.init(describing: command.arguments[0]);
        let channelName: String = command.arguments[1] as? String ?? String.init(describing: command.arguments[1]);
        let additionalData: [String: String]? = command.arguments[2] as? [String: String];
        
        var additionalDataString = ""
        if (additionalData != nil) {
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(additionalData) {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    additionalDataString = jsonString
                    print("additionalDataString", additionalDataString)
                }
            }
        }
        
        AgoraEngine.instance.setViewController(vc: self.viewController);
        
        AgoraEngine.instance.getRtmKit().queryPeerOnline(peerId) { (status) in
            if(status == .online) {
                AgoraEngine.instance.inviter?.sendInvitation(peer: peerId, channel: channelName, extraContent: additionalDataString, accepted: {
                    print("AGORA, invitation accepted");
                    
                    if let vc = self.viewController.presentedViewController as? CallingViewController {
                        vc.close()
                    }
                    AgoraEngine.instance.getCallKit().setCallConnected(of: peerId);
                    let vc: VideoChatViewController = VideoChatViewController();
                    vc.modalPresentationStyle = .fullScreen
                    vc.channel = channelName;
                    vc.additionalData = additionalDataString;
                    vc.remoteUid = UInt(peerId);
                    vc.localUid = UInt(AgoraEngine.instance.getMyId()!);
                    self.viewController.present(vc, animated: true,completion: nil)
                    
                }, refused: {
                    if let vc = self.viewController.presentedViewController as? CallingViewController {
                        vc.close()
                    }
                    AgoraEngine.instance.getCallKit().endCall(of: peerId);
                    print("AGORA, invitation refused");
                }, fail: { (error) in
                    if let vc = self.viewController.presentedViewController as? CallingViewController {
                        vc.close()
                    }
                    print("AGORA, invitation error " + error.localizedDescription);
                })
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "peer_online");
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            } else {
                let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "peer_offline");
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        } fail: { (error) in
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: error.localizedDescription);
            self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
        }
    }
    
    @objc(logout:)
    func logout(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "peer_online");
        AgoraEngine.instance.getRtmKit().logout { (error) in
            pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: error.rawValue);
        }
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
    }
    
}
