import UIKit
import Flutter
import FirebaseCore
import FirebaseAuth
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {

  // audioRecorder를 strong reference로 유지
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
      let options = app.options
      print("📱 Firebase Configuration:")
      print("  - Project ID: \(options.projectID ?? "N/A")")
      print("  - Bundle ID: \(options.bundleID ?? "N/A")")
      print("  - GCM Sender ID: \(options.gcmSenderID ?? "N/A")")
    }
    
    // Auth 설정 (reCAPTCHA 등)
    configureAuthSettings()
  }

  
  private func configureAuthSettings() {
    let authSettings = Auth.auth().settings
    
    #if DEBUG
    authSettings?.isAppVerificationDisabledForTesting = true
    print("DEBUG 모드: 앱 검증 비활성화 (테스트용)")
    #else
    authSettings?.isAppVerificationDisabledForTesting = false
    print("RELEASE 모드: 실제 APNs 토큰 사용")
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
    
    if let registrar = self.registrar(forPlugin: "com.soi.instagram_share") {
      InstagramSharePlugin.register(with: registrar)
    }
    
    // Generated Plugins
    GeneratedPluginRegistrant.register(with: self)
  }
  
  private func configureMethodChannels() {
    guard let messenger = self.registrar(forPlugin: "native_recorder")?.messenger() else { return }

    let audioChannel = FlutterMethodChannel(name: "native_recorder", binaryMessenger: messenger)

    // 프로퍼티에 저장하여 생명주기 동안 유지
    self.audioRecorder = NativeAudioRecorder()

    // weak self 사용 (weak audioRecorder 대신)
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

// MARK: - Instagram Share Plugin
class InstagramSharePlugin: NSObject, FlutterPlugin {
    
    private var viewController: UIViewController?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.soi.instagram_share",
            binaryMessenger: registrar.messenger()
        )
        let instance = InstagramSharePlugin()
        
        // ViewController 참조 획득
        if let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate,
           let window = appDelegate.window {
            instance.viewController = window.rootViewController
        }
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "shareToInstagramDirect":
            if let args = call.arguments as? [String: Any],
               let text = args["text"] as? String {
                shareToInstagramDirect(text: text, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Text is required", details: nil))
            }
            
        case "isInstagramInstalled":
            result(isInstagramInstalled())
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Instagram 설치 여부 확인
    private func isInstagramInstalled() -> Bool {
        guard let url = URL(string: "instagram://app") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// Instagram Direct로 공유 - 이미지와 함께 공유하여 친구 선택 화면 유도
    private func shareToInstagramDirect(text: String, result: @escaping FlutterResult) {
        guard let vc = viewController else {
            result(FlutterError(code: "NO_VC", message: "ViewController not available", details: nil))
            return
        }
        
        // 1. 공유용 이미지 생성 (텍스트가 포함된 간단한 이미지)
        let shareImage = createShareImage(with: text)
        
        // 2. 클립보드에 텍스트도 복사 (사용자가 붙여넣기 가능하도록)
        UIPasteboard.general.string = text
        
        DispatchQueue.main.async {
            // 3. UIActivityViewController로 이미지 공유
            // 이미지를 공유하면 Instagram이 친구 선택 화면을 띄움
            let activityVC = UIActivityViewController(
                activityItems: [shareImage, text],
                applicationActivities: nil
            )
            
            // Instagram만 보이도록 제한하지 않음 (사용자 선택)
            // 하지만 이미지가 포함되어 있으므로 Instagram 선택 시 DM 공유 가능
            
            // iPad 대응
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = vc.view
                popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            activityVC.completionWithItemsHandler = { activityType, completed, items, error in
                if completed {
                    result(true)
                } else if let error = error {
                    result(FlutterError(code: "SHARE_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(false)
                }
            }
            
            vc.present(activityVC, animated: true)
        }
    }
    
    /// 공유용 이미지 생성
    private func createShareImage(with text: String) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 배경색 (SOI 브랜드 컬러)
            UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // SOI 로고 텍스트
            let logoText = "SOI"
            let logoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let logoSize = logoText.size(withAttributes: logoAttributes)
            let logoRect = CGRect(
                x: (size.width - logoSize.width) / 2,
                y: size.height * 0.3,
                width: logoSize.width,
                height: logoSize.height
            )
            logoText.draw(in: logoRect, withAttributes: logoAttributes)
            
            // 초대 메시지
            let messageText = "친구가 되어주세요!"
            let messageAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let messageSize = messageText.size(withAttributes: messageAttributes)
            let messageRect = CGRect(
                x: (size.width - messageSize.width) / 2,
                y: size.height * 0.5,
                width: messageSize.width,
                height: messageSize.height
            )
            messageText.draw(in: messageRect, withAttributes: messageAttributes)
            
            // 링크 텍스트
            let linkText = "soi-sns.web.app"
            let linkAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            let linkSize = linkText.size(withAttributes: linkAttributes)
            let linkRect = CGRect(
                x: (size.width - linkSize.width) / 2,
                y: size.height * 0.65,
                width: linkSize.width,
                height: linkSize.height
            )
            linkText.draw(in: linkRect, withAttributes: linkAttributes)
        }
    }
}
