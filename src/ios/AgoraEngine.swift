import AgoraRtmKit

typealias Completion = (() -> Void)?
typealias ErrorCompletion = ((AGEError) -> Void)?

struct AGEError: Error {
    enum ErrorType {
        case fail(String)
        case invalidParameter(String)
        case valueNil(String)
        case unknown
    }
    
    var localizedDescription: String {
        switch type {
        case .fail(let reason):             return "\(reason)"
        case .invalidParameter(let para):   return "\(para)"
        case .valueNil(let para):           return "\(para) nil"
        case .unknown:                      return "unknown error"
        }
    }
    
    var type: ErrorType
}

protocol AgoraRtmInvitertDelegate: NSObjectProtocol {
    func inviter(_ inviter: AgoraRtmCallKit, didReceivedIncoming invitation: AgoraRtmInvitation)
    func inviter(_ inviter: AgoraRtmCallKit, remoteDidCancelIncoming invitation: AgoraRtmInvitation)
}

struct AgoraRtmInvitation {
    var content: String?
    var caller: String // outgoint call
    var callee: String // incoming call
    
    fileprivate static func agRemoteInvitation(_ ag: AgoraRtmRemoteInvitation) -> AgoraRtmInvitation {
        guard let account = AgoraEngine.instance.account else {
            fatalError("rtm account nil")
        }
        
        let invitation = AgoraRtmInvitation(content: ag.content,
                                            caller: ag.callerId,
                                            callee: account)
        
        return invitation
    }
    
    fileprivate static func agLocalInvitation(_ ag: AgoraRtmLocalInvitation) -> AgoraRtmInvitation {
        guard let account = AgoraEngine.instance.account else {
            fatalError("rtm account nil")
        }
        
        let invitation = AgoraRtmInvitation(content: ag.content,
                                            caller: account,
                                            callee: ag.calleeId)
        
        return invitation
    }
}

enum LoginStatus {
    case online, offline
}

class AgoraEngine: NSObject {
    static let KEY_KILL_ME = "com.agora.openduo.KILL_ME";
    static let instance = AgoraEngine();
    
    var rtmKit: AgoraRtmKit?;
    fileprivate var account: String?
    fileprivate var accountAccessToken: String?
    fileprivate var agoraAppId: String?
    var status: LoginStatus = .offline
    var inviter: AgoraRtmCallKit? {
        return rtmKit?.getRtmCall();
    }
    var inviterDelegate: AgoraRtmInvitertDelegate?
    
    fileprivate var lastOutgoingInvitation: AgoraRtmLocalInvitation?
    fileprivate var lastIncomingInvitation: AgoraRtmRemoteInvitation?
    fileprivate var callKitRefusedBlock: Completion = nil
    fileprivate var callKitAcceptedBlock: Completion = nil
    
    private lazy var appleCallKit = CallCenter(delegate: self)
    
    var viewController: UIViewController?;
    
    override init() {
        super.init()
        inviter?.callDelegate = self
        appleCallKit = CallCenter(delegate: self)
    }
    
    func initAgora(agoraAppId: String) {
        self.agoraAppId = agoraAppId;
        rtmKit = AgoraRtmKit(appId: agoraAppId, delegate: nil);
        inviter?.callDelegate = self;
        inviterDelegate = self;
        appleCallKit = CallCenter(delegate: self)
    }
    
    func getRtmKit() -> AgoraRtmKit {
        return rtmKit!
    }
    
    func getMyId() -> String? {
        return account;
    }
    
    func getAccessToken() -> String? {
        return accountAccessToken;
    }
    
    func getAgoraAppId() -> String? {
        return agoraAppId;
    }
    
    func setViewController(vc: UIViewController) {
        self.viewController = vc;
    }
    
    func getCallKit() -> CallCenter {
        return appleCallKit;
    }
    
}

extension AgoraRtmKit {
    func login(account: String, token: String?, success: Completion, fail: ErrorCompletion) {
        print("rtm login account: \(account)")
        
        AgoraEngine.instance.account = account;
        AgoraEngine.instance.accountAccessToken = token;
        
        login(byToken: token, user: account) { (errorCode) in
            guard errorCode == AgoraRtmLoginErrorCode.ok else {
                if let fail = fail {
                    fail(AGEError(type: .fail("rtm login fail: \(errorCode.rawValue)")))
                }
                return
            }
            
            AgoraEngine.instance.status = .online
            
            if let success = success {
                success()
            }
        }
    }
    
    func queryPeerOnline(_ peer: String, success: ((_ status: AgoraRtmPeerOnlineState) -> Void)? = nil, fail: ErrorCompletion = nil) {
        print("rtm query peer: \(peer)")
        
        queryPeersOnlineStatus([peer]) { (onlineStatusArray, errorCode) in
            guard errorCode == AgoraRtmQueryPeersOnlineErrorCode.ok else {
                if let fail = fail {
                    fail(AGEError(type: .fail("rtm queryPeerOnline fail: \(errorCode.rawValue)")))
                }
                return
            }
            
            guard let onlineStatus = onlineStatusArray?.first else {
                if let fail = fail {
                    fail(AGEError(type: .fail("rtm queryPeerOnline array nil")))
                }
                return
            }
            
            if let success = success {
                success(onlineStatus.state)
            }
        }
    }
}

extension AgoraRtmCallKit {
    enum Status {
        case outgoing, incoming, none
    }
    
    var lastIncomingInvitation: AgoraRtmInvitation? {
        let rtm = AgoraEngine.instance
        
        if let agInvitation = rtm.lastIncomingInvitation {
            let invitation = AgoraRtmInvitation.agRemoteInvitation(agInvitation)
            return invitation
        } else {
            return nil
        }
    }
    
    var status: Status {
        if let _ = AgoraEngine.instance.lastOutgoingInvitation {
            return .outgoing
        } else if let _ = AgoraEngine.instance.lastIncomingInvitation {
            return .incoming
        } else {
            return .none
        }
    }
    
    func sendInvitation(peer: String, channel: String, extraContent: String? = nil, accepted: Completion = nil, refused: Completion = nil, fail: ErrorCompletion = nil) {
        print("rtm sendInvitation peer: \(peer)")
        print("rtm sendInvitation channel: \(channel)")
        print("rtm sendInvitation extraContent: \(extraContent)")
        
        let rtm = AgoraEngine.instance;
        let invitation = AgoraRtmLocalInvitation(calleeId: peer);
        invitation.channelId = channel;
        invitation.content = extraContent;
        
        rtm.lastOutgoingInvitation = invitation
        
        send(invitation) { [unowned rtm] (errorCode) in
            guard errorCode == AgoraRtmInvitationApiCallErrorCode.ok else {
                if let fail = fail {
                    fail(AGEError(type: .fail("rtm send invitation fail: \(errorCode.rawValue)")))
                }
                return
            }
            
            rtm.callKitAcceptedBlock = accepted
            rtm.callKitRefusedBlock = refused
        }
        rtm.getCallKit().startOutgoingCall(of: peer);
        
        if(rtm.viewController != nil) {
            let vc: CallingViewController = CallingViewController();
            vc.modalPresentationStyle = .fullScreen
            vc.channel = channel;
            vc.additionalData = AgoraEngine.instance.lastOutgoingInvitation?.content;
            vc.remoteUid = UInt(AgoraEngine.instance.lastOutgoingInvitation!.calleeId);
            vc.localUid = UInt(AgoraEngine.instance.getMyId()!);
            rtm.viewController?.present(vc, animated: true, completion: nil)
        }
    }
    
    func cancelLastOutgoingInvitation(fail: ErrorCompletion = nil) {
        let rtm = AgoraEngine.instance
        
        guard let last = rtm.lastOutgoingInvitation else {
            return
        }
        
        cancel(last) { (errorCode) in
            guard errorCode == AgoraRtmInvitationApiCallErrorCode.ok else {
                if let fail = fail {
                    fail(AGEError(type: .fail("rtm cancel invitation fail: \(errorCode.rawValue)")))
                }
                return
            }
        }
        
        rtm.lastOutgoingInvitation = nil
    }
    
    func refuseLastIncomingInvitation(fail: ErrorCompletion = nil) {
        let rtm = AgoraEngine.instance
        
        guard let last = rtm.lastIncomingInvitation else {
            return
        }
        
        refuse(last) { (errorCode) in
            guard errorCode == AgoraRtmInvitationApiCallErrorCode.ok else {
                if let fail = fail {
                    fail(AGEError(type: .fail("rtm refuse invitation fail: \(errorCode.rawValue)")))
                }
                return
            }
        }
    }
    
    func accpetLastIncomingInvitation(fail: ErrorCompletion = nil) {
        let rtm = AgoraEngine.instance
        
        guard let last = rtm.lastIncomingInvitation else {
            fatalError("rtm lastIncomingInvitation")
        }
        
        accept(last) {(errorCode) in
            guard errorCode == AgoraRtmInvitationApiCallErrorCode.ok else {
                if let fail = fail {
                    fail(AGEError(type: .fail("rtm refuse invitation fail: \(errorCode.rawValue)")))
                }
                return
            }
        }
    }
}

extension AgoraEngine: AgoraRtmInvitertDelegate {
    func inviter(_ inviter: AgoraRtmCallKit, didReceivedIncoming invitation: AgoraRtmInvitation) {
        getCallKit().showIncomingCall(of: invitation.caller, callerName: Helper.parseValueJsonObject(jsonData: invitation.content!, fieldName: "name_caller", defaultValue: invitation.caller))
    }
    
    func inviter(_ inviter: AgoraRtmCallKit, remoteDidCancelIncoming invitation: AgoraRtmInvitation) {
        getCallKit().endCall(of: invitation.caller)
        NotificationCenter.default.post(name: Notification.Name(rawValue: AgoraEngine.KEY_KILL_ME), object: nil);
    }
}

extension AgoraEngine: AgoraRtmCallDelegate {
    func rtmCallKit(_ callKit: AgoraRtmCallKit, localInvitationAccepted localInvitation: AgoraRtmLocalInvitation, withResponse response: String?) {
        print("rtmCallKit localInvitationAccepted")
        
        let rtm = AgoraEngine.instance
        if let accepted = rtm.callKitAcceptedBlock {
            DispatchQueue.main.async {
                accepted()
            }
            rtm.callKitAcceptedBlock = nil
        }
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, localInvitationRefused localInvitation: AgoraRtmLocalInvitation, withResponse response: String?) {
        print("rtmCallKit localInvitationRefused")
        
        let rtm = AgoraEngine.instance
        if let refused = rtm.callKitRefusedBlock {
            DispatchQueue.main.async {
                refused()
            }
            rtm.callKitRefusedBlock = nil
        }
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, remoteInvitationReceived remoteInvitation: AgoraRtmRemoteInvitation) {
        print("rtmCallKit remoteInvitationReceived")
        
        let rtm = AgoraEngine.instance
        
        guard rtm.lastIncomingInvitation == nil else {
            return
        }
        
        guard let inviter = rtm.inviter else {
            fatalError("rtm inviter nil")
        }
        
        DispatchQueue.main.async { [unowned inviter, weak self] in
            self?.lastIncomingInvitation = remoteInvitation
            let invitation = AgoraRtmInvitation.agRemoteInvitation(remoteInvitation)
            self?.inviterDelegate?.inviter(inviter, didReceivedIncoming: invitation)
            
            print("remoteInvitationReceived", self?.lastIncomingInvitation)
        }
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, remoteInvitationCanceled remoteInvitation: AgoraRtmRemoteInvitation) {
        print("rtmCallKit remoteInvitationCanceled")
        let rtm = AgoraEngine.instance
        
        guard let inviter = rtm.inviter else {
            fatalError("rtm inviter nil")
        }
        
        DispatchQueue.main.async { [weak self] in
            let invitation = AgoraRtmInvitation.agRemoteInvitation(remoteInvitation)
            self?.inviterDelegate?.inviter(inviter, remoteDidCancelIncoming: invitation)
            self?.lastIncomingInvitation = nil
            
            print("lastIncomingInvitation", "made nil")
        }
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, localInvitationReceivedByPeer localInvitation: AgoraRtmLocalInvitation) {
        print("rtmCallKit localInvitationReceivedByPeer")
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, localInvitationCanceled localInvitation: AgoraRtmLocalInvitation) {
        print("rtmCallKit localInvitationCanceled")
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, localInvitationFailure localInvitation: AgoraRtmLocalInvitation, errorCode: AgoraRtmLocalInvitationErrorCode) {
        print("rtmCallKit localInvitationFailure: \(errorCode.rawValue)")
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, remoteInvitationFailure remoteInvitation: AgoraRtmRemoteInvitation, errorCode: AgoraRtmRemoteInvitationErrorCode) {
        print("rtmCallKit remoteInvitationFailure: \(errorCode.rawValue)")
        self.lastIncomingInvitation = nil
        print("lastIncomingInvitation", "made nil")
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, remoteInvitationRefused remoteInvitation: AgoraRtmRemoteInvitation) {
        print("rtmCallKit remoteInvitationRefused")
        self.lastIncomingInvitation = nil
        print("lastIncomingInvitation", "made nil")
    }
    
    func rtmCallKit(_ callKit: AgoraRtmCallKit, remoteInvitationAccepted remoteInvitation: AgoraRtmRemoteInvitation) {
        print("rtmCallKit remoteInvitationAccepted")
        self.lastIncomingInvitation = nil
        print("lastIncomingInvitation", "made nil")
    }
}

extension AgoraEngine: CallCenterDelegate {
    func callCenter(_ callCenter: CallCenter, answerCall session: String) {
        print("callCenter answerCall")
        
        guard let inviter = AgoraEngine.instance.inviter else {
            fatalError("rtm inviter nil")
        }
        
        if let incomingInvitation = AgoraEngine.instance.lastIncomingInvitation {
            guard let channel = incomingInvitation.channelId else {
                fatalError("lastIncomingInvitation content nil")
            }
            
    //        guard let remote = UInt(session) else {
    //            fatalError("string to int fail")
    //        }
            
            inviter.accpetLastIncomingInvitation()
            
            if(viewController != nil) {
                let vc: VideoChatViewController = VideoChatViewController();
                vc.modalPresentationStyle = .fullScreen
                vc.channel = channel;
                vc.additionalData = incomingInvitation.content;
                vc.remoteUid = UInt(incomingInvitation.callerId);
                vc.localUid = UInt(AgoraEngine.instance.getMyId()!);
                viewController?.present(vc, animated: true, completion: nil)
            }
        } else {
            print("incomingInvitation content nil")
        }
        
        // present VideoChat VC after 'callCenterDidActiveAudioSession'
        //        self.prepareToVideoChat = { [weak self] in
        //            var data: (channel: String, remote: UInt)
        //            data.channel = channel
        //            data.remote = remote
        //            self?.performSegue(withIdentifier: "DialToVideoChat", sender: data)
        //        }
    }
    
    func callCenter(_ callCenter: CallCenter, declineCall session: String) {
        print("callCenter declineCall")
        
        guard let inviter = AgoraEngine.instance.inviter else {
            fatalError("rtm inviter nil")
        }
        
        inviter.refuseLastIncomingInvitation {  [weak self] (error) in
            //self?.showAlert(error.localizedDescription)
            print(error.localizedDescription)
        }
    }
    
    func callCenter(_ callCenter: CallCenter, startCall session: String) {
        print("callCenter startCall")
        
        //        guard let kit = AgoraEngine.instance.kit else {
        //            fatalError("rtm kit nil")
        //        }
        //
        //        guard let localNumber = localNumber else {
        //            fatalError("localNumber nil")
        //        }
        //
        //        guard let inviter = AgoraEngine.instance.inviter else {
        //            fatalError("rtm inviter nil")
        //        }
        //
        //        guard let vc = self.presentedViewController as? CallingViewController else {
        //            fatalError("CallingViewController nil")
        //        }
        //
        //        let remoteNumber = session
        //
        //        // rtm query online status
        //        kit.queryPeerOnline(remoteNumber, success: { [weak vc] (onlineStatus) in
        //            switch onlineStatus {
        //            case .online:      sendInvitation(remote: remoteNumber, callingVC: vc!)
        //            case .offline:     vc?.close(.remoteReject(remoteNumber))
        //            case .unreachable: vc?.close(.remoteReject(remoteNumber))
        //            @unknown default:  fatalError("queryPeerOnline")
        //            }
        //        }) { [weak vc] (error) in
        //            vc?.close(.error(error))
        //        }
        //
        //        // rtm send invitation
        //        func sendInvitation(remote: String, callingVC: CallingViewController) {
        //            let channel = "\(localNumber)-\(remoteNumber)-\(Date().timeIntervalSinceReferenceDate)"
        //
        //            inviter.sendInvitation(peer: remoteNumber, extraContent: channel, accepted: { [weak self, weak vc] in
        //                vc?.close(.toVideoChat)
        //
        //                self?.appleCallKit.setCallConnected(of: remote)
        //
        //                guard let remote = UInt(remoteNumber) else {
        //                    fatalError("string to int fail")
        //                }
        //
        //                var data: (channel: String, remote: UInt)
        //                data.channel = channel
        //                data.remote = remote
        //                self?.performSegue(withIdentifier: "DialToVideoChat", sender: data)
        //
        //            }, refused: { [weak vc] in
        //                vc?.close(.remoteReject(remoteNumber))
        //            }) { [weak vc] (error) in
        //                vc?.close(.error(error))
        //            }
        //        }
    }
    
    func callCenter(_ callCenter: CallCenter, muteCall muted: Bool, session: String) {
        print("callCenter muteCall")
    }
    
    func callCenter(_ callCenter: CallCenter, endCall session: String) {
        print("callCenter endCall")
        //self.prepareToVideoChat = nil
    }
    
    func callCenterDidActiveAudioSession(_ callCenter: CallCenter) {
        print("callCenter didActiveAudioSession")
//        if let channel = AgoraEngine.instance.lastIncomingInvitation?.channelId {
//            if(viewController != nil) {
//                let vc: VideoChatViewController = VideoChatViewController();
//                vc.modalPresentationStyle = .fullScreen
//                vc.channel = channel;
//                vc.additionalData = AgoraEngine.instance.lastIncomingInvitation?.content;
//                vc.remoteUid = UInt(AgoraEngine.instance.lastIncomingInvitation!.callerId);
//                vc.localUid = UInt(AgoraEngine.instance.getMyId()!);
//                viewController?.present(vc, animated: true, completion: nil)
//            }
//        } else {
//            print("lastIncomingInvitation content nil")
//        }
    }
}
