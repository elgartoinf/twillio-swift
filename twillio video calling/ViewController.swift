//
//  ViewController.swift
//  twillio video calling
//
//  Created by Gabriel on 2/8/19.
//  Copyright © 2019 elgartoinf. All rights reserved.
//

import UIKit
import TwilioVideo
import CallKit
import AVFoundation

class ViewController: UIViewController {
    var accessToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImN0eSI6InR3aWxpby1mcGE7dj0xIn0.eyJqdGkiOiJTSzJjYTMyNTUzOGRhMGQ3ZjdlZjUzNTMxNDFlMWRkNzQzLTE1NDk5ODU5NTkiLCJpc3MiOiJTSzJjYTMyNTUzOGRhMGQ3ZjdlZjUzNTMxNDFlMWRkNzQzIiwic3ViIjoiQUMwOTIzMGQ1MWM4NjBjZjdlOTYyYzFjM2M0MTFhZjIwNyIsImV4cCI6MTU0OTk4OTU1OSwiZ3JhbnRzIjp7ImlkZW50aXR5IjoiMjMxMjMxMjMiLCJ2aWRlbyI6e319fQ.MscDCLo_87xYyb5h6GN8XPdE0RT5WE4NO_VLjED-sNc"
    
    // CallKit components
    let callKitProvider: CXProvider
    let callKitCallController: CXCallController
    var callKitCompletionHandler: ((Bool)->Swift.Void?)? = nil
    var userInitiatedDisconnect: Bool = false
    
    //camera components
    var camera: TVICameraSource?
    var localVideoTrack: TVILocalVideoTrack?
    var remoteParticipant: TVIRemoteParticipant?
    
    //audio components
    var audioDevice: TVIDefaultAudioDevice = TVIDefaultAudioDevice()
    //local audio
    var localAudioTrack: TVILocalAudioTrack?
    
    // Video SDK components
    var room: TVIRoom?
    
    //MARK: IBOutlet
    @IBOutlet weak var preview: TVIVideoView!
    @IBOutlet weak var remoteView: TVIVideoView!
    
    //MARK: functions
    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
        callKitProvider.invalidate()
    }
    
    required init?(coder aDecoder: NSCoder) {
        let configuration = CXProviderConfiguration(localizedName: "CallKit Quickstart")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportsVideo = true
        if let callKitIcon = UIImage(named: "iconMask80") {
            configuration.iconTemplateImageData = callKitIcon.pngData()
        }
        
        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()
        
        super.init(coder: aDecoder)
        
        callKitProvider.setDelegate(self, queue: nil)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
         * The important thing to remember when providing a TVIAudioDevice is that the device must be set
         * before performing any other actions with the SDK (such as creating Tracks, or connecting to a Room).
         * In this case we've already initialized our own `TVIDefaultAudioDevice` instance which we will now set.
         */
        TwilioVideo.audioDevice = self.audioDevice;
        
        if PlatformUtils.isSimulator {
            self.preview.removeFromSuperview()
        } else {
            // Preview our local camera track in the local video preview view.
            self.startPreview()
        }
        
        //MARK: setup conection and channel
        performStartCallAction(uuid: UUID.init(), roomName: "channel")
    }
    
    // MARK: Private camera
    func startPreview() {
        if PlatformUtils.isSimulator {
            return
        }
        
        let frontCamera = TVICameraSource.captureDevice(for: .front)
        let backCamera = TVICameraSource.captureDevice(for: .back)
        
        if (frontCamera != nil || backCamera != nil) {
            // Preview our local camera track in the local video preview view.
            camera = TVICameraSource(delegate: self)
            localVideoTrack = TVILocalVideoTrack.init(source: camera!, enabled: true, name: "Camera")
            
            // Add renderer to video track for local preview
            localVideoTrack!.addRenderer(self.preview)
            
            if (frontCamera != nil && backCamera != nil) {
                // We will flip camera on tap.
                let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.flipCamera))
                self.preview.addGestureRecognizer(tap)
            }
            
            camera!.startCapture(with: frontCamera != nil ? frontCamera! : backCamera!) { (captureDevice, videoFormat, error) in
                if let error = error {
                    print("Capture failed with error.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                } else {
                    self.preview.shouldMirror = (captureDevice.position == .front)
                }
            }
        }
        else {
            print("No front or back capture device found!")
        }
    }
    
    @objc func flipCamera() {
        var newDevice: AVCaptureDevice?
        
        if let camera = self.camera, let captureDevice = camera.device {
            if captureDevice.position == .front {
                newDevice = TVICameraSource.captureDevice(for: .back)
            } else {
                newDevice = TVICameraSource.captureDevice(for: .front)
            }
            
            if let newDevice = newDevice {
                camera.select(newDevice) { (captureDevice, videoFormat, error) in
                    if let error = error {
                        print("Error selecting capture device.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                    } else {
                        self.preview.shouldMirror = (captureDevice.position == .front)
                    }
                }
            }
        }
    }
    
    func muteAudio(isMuted: Bool) {
        if let localAudioTrack = self.localAudioTrack {
            localAudioTrack.isEnabled = !isMuted
            
            // Update the button title
            if (!isMuted) {
                print("mute")
            } else {
                print("unmute")
            }
        }
    }
    
    func holdCall(onHold: Bool) {
        localAudioTrack?.isEnabled = !onHold
        localVideoTrack?.isEnabled = !onHold
    }


}


// MARK: TVIRemoteParticipantDelegate
extension ViewController : TVIRemoteParticipantDelegate {
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           publishedVideoTrack publication: TVIRemoteVideoTrackPublication) {
        
        // Remote Participant has offered to share the video Track.
        
        print("Participant \(participant.identity) published video track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           unpublishedVideoTrack publication: TVIRemoteVideoTrackPublication) {
        
        // Remote Participant has stopped sharing the video Track.
        
        print("Participant \(participant.identity) unpublished video track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           publishedAudioTrack publication: TVIRemoteAudioTrackPublication) {
        
        // Remote Participant has offered to share the audio Track.
        
        print("Participant \(participant.identity) published audio track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           unpublishedAudioTrack publication: TVIRemoteAudioTrackPublication) {
        
        // Remote Participant has stopped sharing the audio Track.
        
        print("Participant \(participant.identity) unpublished audio track")
    }
    
    func subscribed(to videoTrack: TVIRemoteVideoTrack,
                    publication: TVIRemoteVideoTrackPublication,
                    for participant: TVIRemoteParticipant) {
        
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's video frames now.
        
        print("Subscribed to video track for Participant \(participant.identity)")
        
        if (self.remoteParticipant == participant) {
            //MARK:  remover
            //setupRemoteVideoView()
            videoTrack.addRenderer(self.remoteView!)
        }
    }
    
    func unsubscribed(from videoTrack: TVIRemoteVideoTrack,
                      publication: TVIRemoteVideoTrackPublication,
                      for participant: TVIRemoteParticipant) {
        
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.
        
        print("Unsubscribed from video track for Participant \(participant.identity)")
        
        if (self.remoteParticipant == participant) {
            videoTrack.removeRenderer(self.remoteView!)
            self.remoteView?.removeFromSuperview()
            self.remoteView = nil
        }
    }
    
    func subscribed(to audioTrack: TVIRemoteAudioTrack,
                    publication: TVIRemoteAudioTrackPublication,
                    for participant: TVIRemoteParticipant) {
        
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
        
        print("Subscribed to audio track for Participant \(participant.identity)")
    }
    
    func unsubscribed(from audioTrack: TVIRemoteAudioTrack,
                      publication: TVIRemoteAudioTrackPublication,
                      for participant: TVIRemoteParticipant) {
        
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        
        print("Unsubscribed from audio track for Participant \(participant.identity)")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           enabledVideoTrack publication: TVIRemoteVideoTrackPublication) {
        print("Participant \(participant.identity) enabled video track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           disabledVideoTrack publication: TVIRemoteVideoTrackPublication) {
        print("Participant \(participant.identity) disabled video track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           enabledAudioTrack publication: TVIRemoteAudioTrackPublication) {
        print("Participant \(participant.identity) enabled audio track")
    }
    
    func remoteParticipant(_ participant: TVIRemoteParticipant,
                           disabledAudioTrack publication: TVIRemoteAudioTrackPublication) {
        print("Participant \(participant.identity) disabled audio track")
    }
    
    func failedToSubscribe(toAudioTrack publication: TVIRemoteAudioTrackPublication,
                           error: Error,
                           for participant: TVIRemoteParticipant) {
        print("FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }
    
    func failedToSubscribe(toVideoTrack publication: TVIRemoteVideoTrackPublication,
                           error: Error,
                           for participant: TVIRemoteParticipant) {
        print("FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

// MARK: TVIVideoViewDelegate
extension ViewController : TVIVideoViewDelegate {
    func videoView(_ view: TVIVideoView, videoDimensionsDidChange dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}

// MARK: TVICameraSourceDelegate
extension ViewController : TVICameraSourceDelegate {
    func cameraSource(_ source: TVICameraSource, didFailWithError error: Error) {
        print("Camera source failed with error: \(error.localizedDescription)")
    }
}



//MARK: extension for twillio
extension ViewController : CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        print( "providerDidReset:")
        
        // AudioDevice is enabled by default
        self.audioDevice.isEnabled = true
        
        room?.disconnect()
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        print( "providerDidBegin")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print( "provider:didActivateAudioSession:")
        
        self.audioDevice.isEnabled = true
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print( "provider:didDeactivateAudioSession:")
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        print( "provider:timedOutPerformingAction:")
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print( "provider:performStartCallAction:")
        
        /*
         * Configure the audio session, but do not start call audio here, since it must be done once
         * the audio session has been activated by the system after having its priority elevated.
         */
        
        // Stop the audio unit by setting isEnabled to `false`.
        self.audioDevice.isEnabled = false;
        
        // Configure the AVAudioSession by executign the audio device's `block`.
        self.audioDevice.block()
        
        callKitProvider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: nil)
        
        performRoomConnect(uuid: action.callUUID, roomName: action.handle.value) { (success) in
            if (success) {
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print( "provider:performAnswerCallAction:")
        
        /*
         * Configure the audio session, but do not start call audio here, since it must be done once
         * the audio session has been activated by the system after having its priority elevated.
         */
        
        // Stop the audio unit by setting isEnabled to `false`.
        self.audioDevice.isEnabled = false;
        
        // Configure the AVAudioSession by executign the audio device's `block`.
        self.audioDevice.block()
        
        //MARK: room's id
        performRoomConnect(uuid: action.callUUID, roomName: "sd") { (success) in
            if (success) {
                action.fulfill(withDateConnected: Date())
            } else {
                action.fail()
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("provider:performEndCallAction:")
        
        // AudioDevice is enabled by default
        self.audioDevice.isEnabled = true
        room?.disconnect()
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        NSLog("provier:performSetMutedCallAction:")
        
        muteAudio(isMuted: action.isMuted)
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("provier:performSetHeldCallAction:")
        
        let cxObserver = callKitCallController.callObserver
        let calls = cxObserver.calls
        
        guard let call = calls.first(where:{$0.uuid == action.callUUID}) else {
            action.fail()
            return
        }
        
        if call.isOnHold {
            holdCall(onHold: false)
        } else {
            holdCall(onHold: true)
        }
        action.fulfill()
    }
    
    func prepareLocalMedia() {
        // We will share local audio and video when we connect to the Room.
        
        // Create an audio track.
        if (localAudioTrack == nil) {
            localAudioTrack = TVILocalAudioTrack.init()
            
            if (localAudioTrack == nil) {
                print("Failed to create audio track")
            }
        }
        
        // Create a video track which captures from the camera.
        if (localVideoTrack == nil) {
            self.startPreview()
        }
    }
    
}

// MARK: Call Kit Actions
extension ViewController {
    
    func performStartCallAction(uuid: UUID, roomName: String?) {
        let callHandle = CXHandle(type: .generic, value: roomName ?? "")
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        
        startCallAction.isVideo = true
        
        let transaction = CXTransaction(action: startCallAction)
        
        callKitCallController.request(transaction)  { error in
            if let error = error {
                NSLog("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }
            NSLog("StartCallAction transaction request successful")
        }
    }
    
    func reportIncomingCall(uuid: UUID, roomName: String?, completion: ((NSError?) -> Void)? = nil) {
        let callHandle = CXHandle(type: .generic, value: roomName ?? "")
        
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.supportsDTMF = false
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = true
        
        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if error == nil {
                NSLog("Incoming call successfully reported.")
            } else {
                NSLog("Failed to report incoming call successfully: \(String(describing: error?.localizedDescription)).")
            }
            completion?(error as NSError?)
        }
    }
    
    func performEndCallAction(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("EndCallAction transaction request failed: \(error.localizedDescription).")
                return
            }
            
            NSLog("EndCallAction transaction request successful")
        }
    }
    
    func performRoomConnect(uuid: UUID, roomName: String? , completionHandler: @escaping (Bool) -> Swift.Void) {
        // Configure access token either from server or manually.
        // If the default wasn't changed, try fetching from server.
        if (accessToken == "TWILIO_ACCESS_TOKEN") {
            do {
                //MARK: get token dynamic
                //accessToken = try TokenUtils.fetchToken(url: tokenUrl)
            } catch {
                let message = "Failed to fetch access token"
                print( message)
                return
            }
        }
        
        // Prepare local media which we will share with Room Participants.
        self.prepareLocalMedia()
        
        // Preparing the connect options with the access token that we fetched (or hardcoded).
        let connectOptions = TVIConnectOptions.init(token: accessToken) { (builder) in
            
            // Use the local media that we prepared earlier.
            builder.audioTracks = self.localAudioTrack != nil ? [self.localAudioTrack!] : [TVILocalAudioTrack]()
            builder.videoTracks = self.localVideoTrack != nil ? [self.localVideoTrack!] : [TVILocalVideoTrack]()
            
            // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
            // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
            builder.roomName = roomName
            
            // The CallKit UUID to assoicate with this Room.
            builder.uuid = uuid
        }
        
        // Connect to the Room using the options we provided.
        room = TwilioVideo.connect(with: connectOptions, delegate: self)
        
        print( "Attempting to connect to room \(String(describing: roomName))")
        
        self.callKitCompletionHandler = completionHandler
    }
}



// MARK: TVIRoomDelegate
extension ViewController : TVIRoomDelegate {
    func didConnect(to room: TVIRoom) {
        
        // At the moment, this example only supports rendering one Participant at a time.
        
        print("Connected to room \(room.name) as \(String(describing: room.localParticipant?.identity))")
        
        if (room.remoteParticipants.count > 0) {
            self.remoteParticipant = room.remoteParticipants[0]
            self.remoteParticipant?.delegate = self
        }
        
        let cxObserver = callKitCallController.callObserver
        let calls = cxObserver.calls
        
        // Let the call provider know that the outgoing call has connected
        if let uuid = room.uuid, let call = calls.first(where:{$0.uuid == uuid}) {
            if call.isOutgoing {
                callKitProvider.reportOutgoingCall(with: uuid, connectedAt: nil)
            }
        }
        
        self.callKitCompletionHandler!(true)
    }
    
    func room(_ room: TVIRoom, didDisconnectWithError error: Error?) {
        print("Disconncted from room \(room.name), error = \(String(describing: error))")
        
        if !self.userInitiatedDisconnect, let uuid = room.uuid, let error = error {
            var reason = CXCallEndedReason.remoteEnded
            
            if (error as NSError).code != TVIError.roomRoomCompletedError.rawValue {
                reason = .failed
            }
            
            self.callKitProvider.reportCall(with: uuid, endedAt: nil, reason: reason)
        }
        
        //self.cleanupRemoteParticipant()
        self.room = nil
        //self.showRoomUI(inRoom: false)
        self.callKitCompletionHandler = nil
        self.userInitiatedDisconnect = false
    }
    
    func room(_ room: TVIRoom, didFailToConnectWithError error: Error) {
        print("Failed to connect to room with error: \(error.localizedDescription)")
        
        self.callKitCompletionHandler!(false)
        self.room = nil
        //self.showRoomUI(inRoom: false)
    }
    
    func room(_ room: TVIRoom, participantDidConnect participant: TVIRemoteParticipant) {
        if (self.remoteParticipant == nil) {
            self.remoteParticipant = participant
            self.remoteParticipant?.delegate = self
        }
        print("Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
    }
    
    func room(_ room: TVIRoom, participantDidDisconnect participant: TVIRemoteParticipant) {
        if (self.remoteParticipant == participant) {
            //cleanupRemoteParticipant()
            print("se deslogeo el participante")
        }
        print("Room \(room.name), Participant \(participant.identity) disconnected")
    }
}
