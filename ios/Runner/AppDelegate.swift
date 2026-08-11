import Flutter
import UIKit
import PushKit
import CallKit
import AVFoundation
import flutter_callkit_incoming
import WebRTC

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]
    // WebRTC + CallKit ses icin manuel audio session
    RTCAudioSession.sharedInstance().useManualAudio = true
    RTCAudioSession.sharedInstance().isAudioEnabled = false
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
      let fileURL = dir.appendingPathComponent("voip_token.txt")
      try? deviceToken.write(to: fileURL, atomically: true, encoding: .utf8)
    }
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    let dict = payload.dictionaryPayload
    if (dict["type"] as? String) == "call_cancelled" {
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
      completion()
      return
    }
    let serverCallId = (dict["callId"] as? String) ?? ""
    let callerName = (dict["callerName"] as? String) ?? "Ziyaretci"
    let callKitId = UUID().uuidString
    let data = flutter_callkit_incoming.Data(id: callKitId, nameCaller: callerName, handle: "MobilDiafon", type: 1)
    data.extra = [
      "callId": serverCallId,
      "callKitId": callKitId,
      "callerName": callerName,
      "callerUserId": (dict["callerUserId"] as? String) ?? "",
      "buildingId": (dict["buildingId"] as? String) ?? ""
    ] as NSDictionary
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
    completion()
  }

  // MARK: - CallkitIncomingAppDelegate
  func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
    action.fulfill()
  }

  func onDecline(_ call: Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onEnd(_ call: Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onTimeOut(_ call: Call) {
  }

  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    // WebRTC audio session devralsin - SES BURADAN GELIYOR
    RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = true
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = false
  }

  func providerDidReset() {
  }
}
