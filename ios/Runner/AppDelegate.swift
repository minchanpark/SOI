import UIKit
import Flutter
import FirebaseCore
import FirebaseAuth
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {

  // ✅ audioRecorder를 strong reference로 유지
  private var audioRecorder: NativeAudioRecorder?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 1. Firebase 초기화 및 설정
    configureFirebase()
    
    // 2. APNs 및 알림 설정
    configureNotifications(for: application)
    
    // 3. 플러그인 및 채널 등록
    registerPlugins()
    configureMethodChannels()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - APNs Token Registration
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    handleAPNsTokenRegistration(deviceToken)
  }
  
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    handleAPNsRegistrationFailure(error)
  }
  
  // MARK: - Notification Handling
  override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    handleRemoteNotification(userInfo, completionHandler: completionHandler)
  }
  
  // MARK: - URL Handling
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}

// MARK: - Firebase Configuration
extension AppDelegate {
  private func configureFirebase() {
    FirebaseApp.configure()
    
    // Firebase 설정 정보 로깅
    if let app = FirebaseApp.app() {
      logFirebaseOptions(app.options)
    }
    
    // Auth 설정 (reCAPTCHA 등)
    configureAuthSettings()
  }
  
  private func logFirebaseOptions(_ options: FirebaseOptions) {
    print("🔥 Firebase 초기화 완료")
    print("🔥 프로젝트 ID: \(options.projectID ?? "Unknown")")
    print("🔥 Bundle ID: \(options.bundleID ?? "Unknown")")
    print("🔥 API Key: \(String(options.apiKey?.prefix(10) ?? "Unknown"))...")
  }
  
  private func configureAuthSettings() {
    let authSettings = Auth.auth().settings
    
    #if DEBUG
    authSettings?.isAppVerificationDisabledForTesting = true
    print("🔧 DEBUG 모드: 앱 검증 비활성화 (테스트용)")
    #else
    authSettings?.isAppVerificationDisabledForTesting = false
    print("🚀 RELEASE 모드: 실제 APNs 토큰 사용")
    #endif
  }
}

// MARK: - Notification Setup
extension AppDelegate {
  private func configureNotifications(for application: UIApplication) {
    // 백그라운드 fetch 설정
    if #available(iOS 13.0, *) {
      application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    // 권한 요청 및 델리게이트 설정
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      requestNotificationAuthorization(application)
    } else {
      application.registerForRemoteNotifications()
    }
  }
  
  private func requestNotificationAuthorization(_ application: UIApplication) {
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
      if granted {
        print("Notification permission granted")
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      } else {
        print("Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
      }
    }
  }
  
  private func handleAPNsTokenRegistration(_ deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("APNs Token received: \(tokenString)")
    
    // Firebase Auth에 APNs 토큰 설정
    let firebaseAuth = Auth.auth()
    
    #if DEBUG
    firebaseAuth.setAPNSToken(deviceToken, type: .sandbox)
    print("APNs Token set for SANDBOX environment")
    #else
    firebaseAuth.setAPNSToken(deviceToken, type: .prod)
    print("APNs Token set for PRODUCTION environment")
    #endif
    
    print("APNs Token이 Firebase Auth에 등록되었습니다.")
  }
  
  private func handleAPNsRegistrationFailure(_ error: Error) {
    print("APNs Token 등록 실패: \(error.localizedDescription)")
    print("해결 방법: Apple Developer Program, Provisioning Profile, Firebase 콘솔 설정을 확인하세요.")
  }
  
  private func handleRemoteNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.newData)
      return
    }
    completionHandler(.noData)
  }
}

// MARK: - Plugin & Channel Setup
extension AppDelegate {
  private func registerPlugins() {
    // Custom Plugins
    if let registrar = self.registrar(forPlugin: "com.soi.camera") {
      SwiftCameraPlugin.register(with: registrar)
    }
    
    if let registrar = self.registrar(forPlugin: "SwiftAudioConverter") {
      SwiftAudioConverter.register(with: registrar)
    }
    
    // Generated Plugins
    GeneratedPluginRegistrant.register(with: self)
  }
  
  private func configureMethodChannels() {
    guard let messenger = self.registrar(forPlugin: "native_recorder")?.messenger() else { return }

    let audioChannel = FlutterMethodChannel(name: "native_recorder", binaryMessenger: messenger)

    // ✅ 프로퍼티에 저장하여 생명주기 동안 유지
    self.audioRecorder = NativeAudioRecorder()

    // ✅ weak self 사용 (weak audioRecorder 대신)
    audioChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      guard let audioRecorder = self.audioRecorder else {
        result(FlutterError(code: "NO_RECORDER", message: "Audio recorder not initialized", details: nil))
        return
      }
      self.handleAudioRecorderMethodCall(call, result: result, recorder: audioRecorder)
    }
  }
  
  private func handleAudioRecorderMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult, recorder: NativeAudioRecorder) {
    switch call.method {
    case "checkMicrophonePermission":
      recorder.checkMicrophonePermission(result: result)
    case "requestMicrophonePermission":
      recorder.requestMicrophonePermission(result: result)
    case "startRecording":
      if let args = call.arguments as? [String: Any],
         let filePath = args["filePath"] as? String {
        recorder.startRecording(filePath: filePath, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      }
    case "stopRecording":
      recorder.stopRecording(result: result)
    case "isRecording":
      recorder.isRecording(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
