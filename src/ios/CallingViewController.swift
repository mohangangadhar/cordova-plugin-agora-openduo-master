//
//  CallingViewController.swift
//  Vertulio
//
//  Created by Aman Sharma on 26/01/21.
//

import UIKit
import AgoraRtmKit
import AudioToolbox
import Kingfisher

class CallingViewController: UIViewController {
    enum Operation {
        case on, off
    }
    
    let headImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    let numberTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.boldSystemFont(ofSize: 20)
        textView.textColor = .black
        textView.backgroundColor = .white
        textView.textAlignment = .center
        textView.isEditable = false;
        textView.isScrollEnabled = false;
        return textView
    }()
    let callingTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = "Calling.."
        textView.textAlignment = .center
        textView.textColor = .black
        textView.backgroundColor = .white
        textView.isEditable = false;
        textView.isScrollEnabled = false;
        return textView
    }()
    let endButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "end"), for: .normal);
        return button
    }()
    
    private func setupUi() {
        view.backgroundColor = .white
        view.addSubview(headImageView)
        view.addSubview(numberTextView)
        view.addSubview(callingTextView)
        view.addSubview(endButton)
        
        headImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        headImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100).isActive = true
        headImageView.widthAnchor.constraint(equalToConstant: 150).isActive = true
        headImageView.heightAnchor.constraint(equalToConstant: 150).isActive = true
        
        numberTextView.topAnchor.constraint(equalTo: headImageView.bottomAnchor, constant: 60).isActive = true
        numberTextView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        numberTextView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        callingTextView.topAnchor.constraint(equalTo: numberTextView.bottomAnchor, constant: 20).isActive = true
        callingTextView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        callingTextView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        endButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: CGFloat(-44)).isActive = true
        endButton.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor).isActive = true
    }
    
    private var ringStatus: Operation = .off {
        didSet {
            guard oldValue != ringStatus else {
                return
            }
            
            switch ringStatus {
            case .on:  startPlayRing()
            case .off: stopPlayRing()
            }
        }
    }
    
    private var animationStatus: Operation = .off {
        didSet {
            guard oldValue != animationStatus else {
                return
            }
            
            switch animationStatus {
            case .on:  startAnimating()
            case .off: stopAnimationg()
            }
        }
    }
    
    private let aureolaView = AureolaView(color: UIColor(red: 173.0 / 255.0,
                                                         green: 211.0 / 255.0,
                                                         blue: 252.0 / 255.0, alpha: 1))
    private var timer: Timer?
    private var soundId = SystemSoundID()
    
    var localUid: UInt?
    var remoteUid: UInt?
    var channel: String?
    var additionalData: String?
    
    //    override var preferredStatusBarStyle: UIStatusBarStyle {
    //        return .lightContent
    //    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUi()
        
        var url: URL?
        if additionalData != nil {
            let image_callee = Helper.parseValueJsonObject(jsonData: additionalData!, fieldName: "image_callee", defaultValue: "")
            if (image_callee.count > 0) {
                url = URL(string: image_callee)
            }
        }
        
        if url == nil {
            url = URL(string: "https://dummy.com")
        }
        
        KF.url(url!)
            .placeholder(UIImage(named: "empty_dp.png"))
            .setProcessor(RoundCornerImageProcessor(cornerRadius: 75))
            .set(to: headImageView)
        
        numberTextView.text = Helper.parseValueJsonObject(jsonData: additionalData!, fieldName: "name_callee", defaultValue: "")
        
        endButton.addTarget(self, action: #selector(didClickEndButton), for: .touchUpInside)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animationStatus = .on
        ringStatus = .on
    }
    
    @objc func didClickEndButton(_ sender: UIButton) {
        let errorHandle: ErrorCompletion = { (error: AGEError) in
            //self?.showAlert(error.localizedDescription)
        }
        AgoraEngine.instance.getCallKit().endCall(of: String(remoteUid!))
        AgoraEngine.instance.inviter!.cancelLastOutgoingInvitation(fail: errorHandle)
        
        close()
    }
    
    func close() {
        animationStatus = .off
        ringStatus = .off
        dismiss(animated: true, completion: nil)
    }
}

private extension CallingViewController {
    @objc func animation() {
        aureolaView.startLayerAnimation(aboveView: headImageView,
                                        layerWidth: 2)
    }
    
    func startAnimating() {
//        let timer = Timer(timeInterval: 0.3,
//                          target: self,
//                          selector: #selector(animation),
//                          userInfo: nil,
//                          repeats: true)
//        timer.fire()
//        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
//        self.timer = timer
    }
    
    func stopAnimationg() {
//        timer?.invalidate()
//        timer = nil
//        aureolaView.removeAnimation()
    }
    
    func startPlayRing() {
        let path = Bundle.main.path(forResource: "ring", ofType: "mp3")
        let url = URL.init(fileURLWithPath: path!)
        AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
        
        AudioServicesAddSystemSoundCompletion(soundId,
                                              CFRunLoopGetMain(),
                                              nil, { (soundId, context) in
                                                AudioServicesPlaySystemSound(soundId)
                                              }, nil)
        
        AudioServicesPlaySystemSound(soundId)
    }
    
    func stopPlayRing() {
        AudioServicesDisposeSystemSoundID(soundId)
        AudioServicesRemoveSystemSoundCompletion(soundId)
    }
}
