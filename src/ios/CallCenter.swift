//
//  CallCenter.swift
//  AgoraRTCWithCallKit
//
//  Created by GongYuhua on 2018/1/23.
//  Copyright © 2018年 Agora. All rights reserved.
//

import UIKit
import CallKit
import AVFoundation

protocol CallCenterDelegate: NSObjectProtocol {
    func callCenter(_ callCenter: CallCenter, startCall session: String)
    func callCenter(_ callCenter: CallCenter, answerCall session: String)
    func callCenter(_ callCenter: CallCenter, muteCall muted: Bool, session: String)
    func callCenter(_ callCenter: CallCenter, declineCall session: String)
    func callCenter(_ callCenter: CallCenter, endCall session: String)
    func callCenterDidActiveAudioSession(_ callCenter: CallCenter)
}

extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }
}

class CallCenter: NSObject {
    
    weak var delegate: CallCenterDelegate?
    
    fileprivate let controller = CXCallController()
    private var provider = CXProvider(configuration: CallCenter.providerConfiguration)
    
    private static var providerConfiguration: CXProviderConfiguration {
        var appName = "Agora";
        if let displayName = Bundle.main.displayName {
            appName = displayName;
        }
        let providerConfiguration = CXProviderConfiguration(localizedName: appName)
        if let iconImage = UIImage(named: "icon_video") {
            providerConfiguration.iconTemplateImageData = UIImagePNGRepresentation(iconImage)
        }
        if #available(iOS 11.0, *) {
            providerConfiguration.includesCallsInRecents = false
        }
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber]
        
        return providerConfiguration
    }
    
    fileprivate var sessionPool = [UUID: String]()
    
    init(delegate: CallCenterDelegate) {
        super.init()
        self.delegate = delegate
        provider.setDelegate(self, queue: nil)
    }
    
//    deinit {
//        provider.invalidate()
//    }
    
    func showIncomingCall(of session: String, callerName: String) {
        print("INCOMING_FOR", session)
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .phoneNumber, value: session)
        callUpdate.localizedCallerName = callerName
        callUpdate.hasVideo = true
        callUpdate.supportsDTMF = false
        
        let uuid = pairedUUID(of: session)
        print("INCOMING_FOR", uuid)
        provider.reportNewIncomingCall(with: uuid, update: callUpdate, completion: { error in
            if let error = error {
                print("reportNewIncomingCall error: \(error.localizedDescription)")
            }
        })
    }
    
    func startOutgoingCall(of session: String) {
        let handle = CXHandle(type: .phoneNumber, value: session)
        let uuid = pairedUUID(of: session)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = true
        
        let transaction = CXTransaction(action: startCallAction)
        controller.request(transaction) { (error) in
            if let error = error {
                print("startOutgoingSession failed: \(error.localizedDescription)")
            }
        }
    }
    
    func setCallConnected(of session: String) {
        let uuid = pairedUUID(of: session)
        if let call = currentCall(of: uuid), call.isOutgoing, !call.hasConnected, !call.hasEnded {
            provider.reportOutgoingCall(with: uuid, connectedAt: nil)
        }
    }
    
    func muteAudio(of session: String, muted: Bool) {
        let muteCallAction = CXSetMutedCallAction(call: pairedUUID(of: session), muted: muted)
        let transaction = CXTransaction(action: muteCallAction)
        controller.request(transaction) { (error) in
            if let error = error {
                print("muteSession \(muted) failed: \(error.localizedDescription)")
            }
        }
    }
    
    func endCall(of session: String) {
        print("ENDING_FOR", session)
        let uuid = pairedUUID(of: session)
        print("ENDING_FOR", uuid)
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        controller.request(transaction) { error in
            if let error = error {
                print("endSession failed: \(error.localizedDescription)")
            }
        }
    }
}

extension CallCenter: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        sessionPool.removeAll()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let session = pairedSession(of:action.callUUID) else {
            action.fail()
            return
        }
        
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = action.handle
        callUpdate.hasVideo = true
        callUpdate.localizedCallerName = session
        callUpdate.supportsDTMF = false
        provider.reportCall(with: action.callUUID, updated: callUpdate)
        
        delegate?.callCenter(self, startCall: session)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        guard let session = pairedSession(of:action.callUUID) else {
            action.fail()
            return
        }
        
        delegate?.callCenter(self, muteCall: action.isMuted, session: session)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let session = pairedSession(of:action.callUUID) else {
            action.fail()
            return
        }
        
        delegate?.callCenter(self, answerCall: session)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("CXEndCallAction_callUUID", action.callUUID)
        guard let session = pairedSession(of:action.callUUID) else {
            print("CXEndCallAction", "failed")
            action.fail()
            return
        }
        
        if let call = currentCall(of: action.callUUID) {
            if call.isOutgoing || call.hasConnected {
                delegate?.callCenter(self, endCall: session)
            } else {
                delegate?.callCenter(self, declineCall: session)
            }
        }
        
        sessionPool.removeAll()
        action.fulfill()
        print("CXEndCallAction", "fulfilled")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        delegate?.callCenterDidActiveAudioSession(self)
    }
}

extension CallCenter {
    func pairedUUID(of session: String) -> UUID {
        for (u, s) in sessionPool {
            if s == session {
                return u
            }
        }
        
        let uuid = UUID()
        sessionPool[uuid] = session
        return uuid
    }
    
    func pairedSession(of uuid: UUID) -> String? {
        return sessionPool[uuid]
    }
    
    func currentCall(of uuid: UUID) -> CXCall? {
        let calls = controller.callObserver.calls
        if let index = calls.firstIndex(where: {$0.uuid == uuid}) {
            return calls[index]
        } else {
            return nil
        }
    }
}
