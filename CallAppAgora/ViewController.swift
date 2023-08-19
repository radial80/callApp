//
//  ViewController.swift
//  CallAppAgora
//
//  Created by Recep Uyduran on 15.08.2023.
//
import UIKit
import AgoraRtcKit
import Koala
import AVFoundation

class ViewController: UIViewController {

    var agoraKit: AgoraRtcEngineKit!
    var koala: Koala?
    var audioInputNode: AVAudioInputNode?

    let agoraAppId = "0584a910925842dab324ce7f6af72346"
    let agoraToken = "007eJxTYAgPU/k9J+aJg5TVqYNtfeGSnqkPb23+pMRx3Ezv9eKpb1oVGAxMLUwSLQ0NLI2ADKOUxCRjI5PkVPM0s8Q0cyNjE7Nt7A9SGgIZGbYK1TAxMkAgiM/DEJJaXKLgnJGYl5eaw8AAAFtPIig="
    let testChannel = "Test Channel"
    let koalaKey = "YNd/NF+5vnxAY93VFyj5VNHCE9P3kuY9TKCU/BU1SjbWvcSEllMBXQ=="

    let audioEngine = AVAudioEngine()

    override func viewDidLoad() {
        super.viewDidLoad()

        audioInputNode = audioEngine.inputNode
    }

    @IBAction func actionButton(_ sender: Any) {
        initializeAgoraEngine()
        initializeKoala()
        setupAudioSession()
    }

    func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: agoraAppId, delegate: self)
        agoraKit.setAudioFrameDelegate(self)
    }

    func initializeKoala() {
        do {
            koala = try Koala(accessKey: koalaKey)
        } catch {
            print("Koala initialization failed: \(error)")
        }
    }

    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat)
            try AVAudioSession.sharedInstance().setActive(true)
            startAudioEngine()
        } catch {
            print("Audio session setup error: \(error)")
        }
    }

    func startAudioEngine() {
        do {
            try audioEngine.start()
            joinChannel()
        } catch {
            print("Audio engine start error: \(error)")
        }
    }

    func joinChannel() {
        let option = AgoraRtcChannelMediaOptions()

        option.clientRoleType = .broadcaster
        //option.clientRoleType = .audience
        option.channelProfile = .communication

        agoraKit.joinChannel(byToken: agoraToken, channelId: testChannel, uid: 0, mediaOptions: option)
    }
}

// MARK: - AGORA DELEGATES
extension ViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("JOINED")
    }

    func getPlaybackAudioParams() -> AgoraAudioParams {
        let param = AgoraAudioParams()
        param.channel = 1
        param.mode = .readOnly
        param.sampleRate = 44100
        param.samplesPerCall = 1024

        return param
    }
}

extension ViewController: AgoraAudioFrameDelegate {

    func getObservedAudioFramePosition() -> AgoraAudioFramePosition {
        return .playback
    }

    func onPlaybackAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        do {
            let count = 256//frame.samplesPerSec
            let audioData = frame.buffer?.bindMemory(to: Int16.self, capacity: count )
            let int16Array = Array(UnsafeBufferPointer(start: audioData, count: count ))

            let enhancedAudio = try koala?.process(int16Array)
            let rawPointer = UnsafeMutableRawPointer(mutating: enhancedAudio)


            self.agoraKit.pushExternalAudioFrameRawData(rawPointer!,
                                                        samples: Int(enhancedAudio?.count ?? 0),
                                                        trackId: 0,
                                                            timestamp: TimeInterval(UInt64(Date().timeIntervalSince1970 * 1000)))
        } catch let error as KoalaError {
            if case is KoalaInvalidArgumentError = error {

                print("Koala invalid argument error: \(error) - \(error.errorDescription) - \(error.failureReason) - \(error.helpAnchor) - \(error.recoverySuggestion)")
            } else {
                print("Koala error: \(error)")
            }
        } catch {
            print("Unexpected error: \(error)")
        }
        return true
    }
}
