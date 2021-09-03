//
//  VideoChatViewController.swift
//  Agora iOS Tutorial
//
//  Created by James Fang on 7/14/16.
//  Copyright © 2016 Agora.io. All rights reserved.
//

import Foundation
import UIKit
import AgoraRtcKit

protocol VideoChatVCDelegate: NSObjectProtocol {
    func videoChat(_ vc: VideoChatViewController, didEndChatWith uid: UInt)
}

class VideoChatViewController: UIViewController {
    let remoteVideo: UIView = {
        let view = UIView()
        view.backgroundColor = .white;
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let localVideo: UIView = {
        let view = UIView()
        view.backgroundColor = .gray;
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let micButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "mic"), for: .normal);
        return button
    }()
    
    let endButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "end"), for: .normal);
        return button
    }()
    
    let cameraButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "switch"), for: .normal);
        return button
    }()
    
    private func setupUi() {
        view.addSubview(remoteVideo);
        view.addSubview(localVideo);
        view.addSubview(micButton);
        view.addSubview(endButton);
        view.addSubview(cameraButton);
        
        remoteVideo.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        remoteVideo.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        remoteVideo.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        remoteVideo.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        
        localVideo.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: CGFloat(16)).isActive = true
        localVideo.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: CGFloat(-10)).isActive = true
        localVideo.heightAnchor.constraint(equalToConstant: CGFloat(140)).isActive = true
        localVideo.widthAnchor.constraint(equalToConstant: CGFloat(85)).isActive = true
        
        
        micButton.widthAnchor.constraint(equalToConstant: CGFloat(56)).isActive = true
        micButton.heightAnchor.constraint(equalToConstant: CGFloat(56)).isActive = true
        //        endButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        //        endButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        cameraButton.widthAnchor.constraint(equalToConstant: CGFloat(56)).isActive = true
        cameraButton.heightAnchor.constraint(equalToConstant: CGFloat(56)).isActive = true
        
        micButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: CGFloat(-36)).isActive = true
        endButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: CGFloat(-44)).isActive = true
        endButton.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor).isActive = true
        cameraButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: CGFloat(-36)).isActive = true
        
        micButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: CGFloat(22)).isActive = true
        cameraButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: CGFloat(-22)).isActive = true
        
        endButton.addTarget(self, action: #selector(didClickHangUpButton), for: .touchUpInside)
        micButton.addTarget(self, action: #selector(didClickMuteButton), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(didClickSwitchCameraButton), for: .touchUpInside)
    }
    
    private var isRemoteVideoRender: Bool = true {
        didSet {
            //remoteVideoMutedIndicator.isHidden = isRemoteVideoRender
            remoteVideo.isHidden = !isRemoteVideoRender
        }
    }
    
    private var isLocalVideoRender: Bool = false {
        didSet {
            //localVideoMutedIndicator.isHidden = isLocalVideoRender
        }
    }
    
    private var isStartCalling: Bool = true;
    
    private var agoraKit: AgoraRtcEngineKit!
    
    weak var delegate: VideoChatVCDelegate?
    
    var localUid: UInt?
    var remoteUid: UInt?
    var channel: String?
    var additionalData: String?
    
    //    override var preferredStatusBarStyle: UIStatusBarStyle {
    //        return .lightContent
    //    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUi()
        
        NotificationCenter.default.addObserver(self, selector: #selector(actOnKillCommand), name: NSNotification.Name(rawValue: AgoraEngine.KEY_KILL_ME), object: nil)
        
        // This is our usual steps for joining
        // a channel and starting a call.
        initializeAgoraEngine()
        setupVideo()
        setupLocalVideo()
        joinChannel()
    }
    
    func connectCall(channel: String, remoteId: UInt, localId: UInt) {
        self.channel = channel;
        self.remoteUid = remoteId;
        self.localUid = localId;
        
        joinChannel()
    }
    
    @objc func actOnKillCommand() {
        AgoraEngine.instance.getCallKit().endCall(of: String(remoteUid!))
        leaveChannel()
        dismiss(animated: true, completion: nil)
    }
    
    @objc func didClickHangUpButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        actOnKillCommand()
        //        if sender.isSelected {
        //            actOnKillCommand()
        //        } else {
        //            joinChannel()
        //        }
    }
    
    @objc func didClickMuteButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        // mute local audio
        agoraKit.muteLocalAudioStream(sender.isSelected)
        sender.setImage(UIImage(named: (sender.isSelected ? "mic_pressed" : "mic")), for: .normal);
    }
    
    @objc func didClickSwitchCameraButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        agoraKit.switchCamera()
        sender.setImage(UIImage(named: (sender.isSelected ? "switch_pressed" : "switch")), for: .normal);
    }
    
    func initializeAgoraEngine() {
        // init AgoraRtcEngineKit
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: AgoraEngine.instance.getAgoraAppId()!, delegate: self)
    }
    
    func setupVideo() {
        // In simple use cases, we only need to enable video capturing
        // and rendering once at the initialization step.
        // Note: audio recording and playing is enabled by default.
        agoraKit.enableAudio()
        agoraKit.enableVideo()
        
        // Set video configuration
        // Please go to this page for detailed explanation
        // https://docs.agora.io/cn/Voice/API%20Reference/java/classio_1_1agora_1_1rtc_1_1_rtc_engine.html#af5f4de754e2c1f493096641c5c5c1d8f
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: AgoraVideoDimension640x360,
                                                                             frameRate: .fps15,
                                                                             bitrate: AgoraVideoBitrateStandard,
                                                                             orientationMode: .adaptative))
    }
    
    func setupLocalVideo() {
        // This is used to set a local preview.
        // The steps setting local and remote view are very similar.
        // But note that if the local user do not have a uid or do
        // not care what the uid is, he can set his uid as ZERO.
        // Our server will assign one and return the uid via the block
        // callback (joinSuccessBlock) after
        // joining the channel successfully.
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = localUid ?? 0
        videoCanvas.view = localVideo
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
    }
    
    func joinChannel() {
        // Set audio route to speaker
        // For videocalling, we don't suggest letting sdk handel audio routing
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        
        guard let channel = channel else {
            fatalError("rtc channel id nil")
        }
        
        guard let uid = localUid else {
            fatalError("rtc uid nil")
        }
        
        // Sets the audio session's operational restriction.
        //agoraKit.setAudioSessionOperationRestriction(.all)
        
        // 1. Users can only see each other after they join the
        // same channel successfully using the same app id.
        // 2. One token is only valid for the channel name that
        // you use to generate this token.
        agoraKit.joinChannel(byToken: AgoraEngine.instance.getAccessToken(),
                             channelId: channel,
                             info: nil,
                             uid: uid) { [unowned self] (channel, uid, elapsed) -> Void in
            // Did join channel
            self.isLocalVideoRender = true
            agoraKit.setEnableSpeakerphone(true)
            print("did join channel")
        }
        
        isStartCalling = true
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func leaveChannel() {
        // leave channel and end chat
        agoraKit.leaveChannel(nil)
        
        guard let remoteUid = remoteUid else {
            fatalError("remoteUid nil")
        }
        
        delegate?.videoChat(self, didEndChatWith: remoteUid)
        
        isRemoteVideoRender = false
        isLocalVideoRender = false
        isStartCalling = false
        UIApplication.shared.isIdleTimerDisabled = false
        print("did leave channel")
    }
}

extension VideoChatViewController: AgoraRtcEngineDelegate {
    // first remote video frame
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        isRemoteVideoRender = true
        
        // Only one remote video view is available for this
        // tutorial. Here we check if there exists a surface
        // view tagged as this uid.
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = remoteVideo
        videoCanvas.renderMode = .hidden
        agoraKit.setupRemoteVideo(videoCanvas)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        isRemoteVideoRender = false
        
        guard let remoteUid = remoteUid else {
            fatalError("remoteUid nil")
        }
        print("didOfflineOfUid: \(uid)")
        if uid == remoteUid {
            leaveChannel()
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith channelStats: AgoraChannelStats) {
        actOnKillCommand()
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted: Bool, byUid: UInt) {
        isRemoteVideoRender = !muted
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        print("did occur warning, code: \(warningCode.rawValue)");
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("did occur error, code: \(errorCode.rawValue)");
    }
    
}
