import Flutter
import UIKit
import AVFoundation
import CoreImage

// MARK: - Flutter Plugin Entry Point
public final class SwiftCameraPlugin: NSObject, FlutterPlugin {
    private static let channelName = "com.soi.camera"

    private let sessionManager = CameraSessionManager()
    private var channel: FlutterMethodChannel?

    // 추가: 비디오 녹화 시작 햅틱(진동) - 소리와 달리 마이크에 섞여 녹음되지 않습니다.
    private static func playVideoRecordStartHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftCameraPlugin()
        let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        instance.channel = methodChannel
        instance.sessionManager.delegate = instance
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        registrar.register(
            CameraPreviewFactory(sessionManager: instance.sessionManager),
            withId: "com.soi.camera/preview"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initCamera":
            sessionManager.ensureConfigured { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result(true)
                    case .failure(let error):
                        result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "prepareCamera":
            sessionManager.prepareSession { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result(true)
                    case .failure(let error):
                        result(FlutterError(code: "PREPARE_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "isSessionActive":
            result(sessionManager.isSessionRunning)

        case "takePicture":
            sessionManager.capturePhoto { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success(let path):
                        result(path)
                    case .failure(let error):
                        result(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "switchCamera":
            sessionManager.switchCamera { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Camera switched")
                    case .failure(let error):
                        result(FlutterError(code: "SWITCH_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "setFlash":
            guard let args = call.arguments as? [String: Any],
                  let isOn = args["isOn"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing isOn", details: nil))
                return
            }
            sessionManager.setFlash(isOn: isOn) { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Flash updated")
                    case .failure(let error):
                        result(FlutterError(code: "FLASH_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "setZoom":
            guard let args = call.arguments as? [String: Any],
                  let zoomValue = args["zoomValue"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing zoomValue", details: nil))
                return
            }
            sessionManager.setZoom(to: zoomValue) { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Zoom updated")
                    case .failure(let error):
                        result(FlutterError(code: "ZOOM_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "setBrightness":
            guard let args = call.arguments as? [String: Any],
                  let value = args["value"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing value", details: nil))
                return
            }
            sessionManager.setBrightness(value) { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Brightness updated")
                    case .failure(let error):
                        result(FlutterError(code: "BRIGHTNESS_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "getAvailableZoomLevels":
            sessionManager.availableZoomLevels { levels in
                DispatchQueue.main.async {
                    result(levels)
                }
            }

        case "getZoomRange":
            // 추가: Flutter(UI)에서 드래그 줌을 할 때 "최대 줌"까지 자연스럽게 가려면
            // 디바이스가 지원하는 min/max 줌 범위를 알아야 합니다.
            sessionManager.zoomRange { minZoom, maxZoom in
                DispatchQueue.main.async {
                    result(["minZoom": minZoom, "maxZoom": maxZoom])
                }
            }

        case "optimizeCamera":
            sessionManager.optimizeForCapture { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Camera optimized")
                    case .failure(let error):
                        result(FlutterError(code: "OPTIMIZE_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "pauseCamera":
            sessionManager.pauseSession()
            result("Camera paused")

        case "resumeCamera":
            sessionManager.resumeSession { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("Camera resumed")
                    case .failure(let error):
                        result(FlutterError(code: "RESUME_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "disposeCamera":
            sessionManager.dispose()
            result("Camera disposed")

        case "startVideoRecording":
            let durationMs = (call.arguments as? [String: Any])?["maxDurationMs"] as? Int
            sessionManager.startRecording(maxDurationMs: durationMs) { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        // 수정: 효과음 대신 햅틱(진동)으로 변경 (효과음이 영상에 같이 녹음되는 문제 방지)
                        Self.playVideoRecordStartHaptic()
                        result(true)
                    case .failure(let error):
                        result(FlutterError(code: "RECORDING_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "stopVideoRecording":
            sessionManager.stopRecording { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success(let path):
                        result(path)
                    case .failure(let error):
                        result(FlutterError(code: "STOP_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "cancelVideoRecording":
            sessionManager.cancelRecording { outcome in
                DispatchQueue.main.async {
                    switch outcome {
                    case .success:
                        result("")
                    case .failure(let error):
                        result(FlutterError(code: "CANCEL_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "supportsLiveSwitch":
            result(sessionManager.supportsLiveSwitch)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Delegate Bridge
extension SwiftCameraPlugin: CameraSessionManagerDelegate {
    fileprivate func cameraSessionManager(_ manager: CameraSessionManager, didFinishRecording path: String) {
        channel?.invokeMethod("onVideoRecorded", arguments: ["path": path])
    }

    fileprivate func cameraSessionManager(_ manager: CameraSessionManager, didFailRecording error: Error) {
        channel?.invokeMethod("onVideoError", arguments: ["message": error.localizedDescription])
    }
}

// MARK: - Camera Session Manager
fileprivate protocol CameraSessionManagerDelegate: AnyObject {
    func cameraSessionManager(_ manager: CameraSessionManager, didFinishRecording path: String)
    func cameraSessionManager(_ manager: CameraSessionManager, didFailRecording error: Error)
}

fileprivate enum CameraSessionError: LocalizedError {
    case deviceUnavailable
    case configurationFailed
    case alreadyRecording
    case notRecording
    case cannotSwitchWhileRecording

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "Camera device is unavailable"
        case .configurationFailed:
            return "Failed to configure camera session"
        case .alreadyRecording:
            return "Video recording already in progress"
        case .notRecording:
            return "No active recording"
        case .cannotSwitchWhileRecording:
            return "Cannot switch camera while recording"
        }
    }
}

fileprivate final class CameraSessionManager: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    weak var delegate: CameraSessionManagerDelegate?

    private let sessionQueue = DispatchQueue(label: "com.soi.camera.session")
    private let captureSession = AVCaptureSession()

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private var deviceCache: [AVCaptureDevice.Position: AVCaptureDevice] = [:]

    private var isConfigured = false
    private var isRecordingPipelineConfigured = false
    private var isAudioSessionConfigured = false
    private var currentPosition: AVCaptureDevice.Position = .back
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private var photoCompletion: ((Result<String, Error>) -> Void)?
    private var recordingCompletion: ((Result<String, Error>) -> Void)?
    private var recordingTimer: DispatchSourceTimer?
    private var currentMovieURL: URL?
    private var isCancellingRecording = false

    // AVAssetWriter properties
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var recordingStartTime: CMTime?
    private var lastVideoTimestamp: CMTime?
    private var lastAudioTimestamp: CMTime?
    // 추가: 카메라 전환 시 sampleBuffer timestamp가 점프하면(영상 공백) 오디오가 먼저 재생될 수 있습니다.
    // 그 공백을 timeOffset으로 빼서 A/V 타임라인을 연속으로 만듭니다.
    private var timeOffset: CMTime = .zero
    private var lastWrittenVideoTimestamp: CMTime?
    private var isSwitchingCamera = false
    private var isAudioPausedForSwitch = false
    private var audioResumeWorkItem: DispatchWorkItem?
    private var isAudioResumeScheduled = false

    // 수정: 카메라 전환 중 오디오를 너무 오래 끄면(예: 3초) 사용자가 "마이크가 안 들어온다"로 느낄 수 있습니다.
    // 전환 직후 첫 정상 비디오 프레임이 들어오면 즉시 오디오를 재개하고,
    // 혹시 프레임이 늦게 들어오는 상황을 대비해 짧은 타이머로만 fail-safe를 둡니다.
    private let cameraSwitchTimeFrameMs: Int = 400
    private var previewAspectRatio: CGFloat?
    private var recordingAspectRatio: CGFloat?
    private let cropContext = CIContext(options: nil)
    private let cropColorSpace = CGColorSpaceCreateDeviceRGB()

    // 추가: 핀치 줌 상태(연속 줌 지원). 플랫폼뷰(PreviewView)에서 들어온 핀치 제스처를 기준으로
    // baseZoom * scale → clamp(min~max) 하여 자연스럽게 확대/축소합니다.
    private var pinchBaseZoomFactor: Double?
    private var lastPinchAppliedZoomFactor: Double = 1.0
    private var lastPinchUpdateTime: CFTimeInterval = 0

    // 추가: 세로 드래그(1손가락) 줌 상태(연속 줌 지원)
    // baseZoom * exp(-translationY / k) 형태로 '핀치처럼 곱셈 기반'으로 자연스럽게 줌이 변하게 합니다.
    private var dragBaseZoomFactor: Double?
    private var lastDragAppliedZoomFactor: Double = 1.0
    private var lastDragUpdateTime: CFTimeInterval = 0

    var supportsLiveSwitch: Bool {
        availablePositions.count > 1
    }

    var isSessionRunning: Bool {
        captureSession.isRunning
    }

    func prepareSession(completion: @escaping (Result<Void, Error>) -> Void) {
        ensureConfigured(startRunning: false, completion: completion)
    }

    func ensureConfigured(startRunning: Bool = true, settleDelayMs: Int = 100, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            if self.isConfigured {
                if startRunning {
                    self.startSessionIfNeeded()
                    self.waitForSessionToStart(settleDelayMs: settleDelayMs, completion: completion)
                } else {
                    completion(.success(()))
                }
                return
            }

            do {
                try self.configureSession()
                self.isConfigured = true
                if startRunning {
                    self.startSessionIfNeeded()
                    self.waitForSessionToStart(settleDelayMs: settleDelayMs, completion: completion)
                } else {
                    completion(.success(()))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func waitForSessionToStart(settleDelayMs: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        if captureSession.isRunning {
            if settleDelayMs <= 0 {
                completion(.success(()))
                return
            }
            sessionQueue.asyncAfter(deadline: .now() + .milliseconds(settleDelayMs)) {
                completion(.success(()))
            }
        } else {
            // 최대 3초까지 대기
            var attempts = 0
            let maxAttempts = 30
            let checkInterval: DispatchTimeInterval = .milliseconds(100)
            
            func checkSession() {
                attempts += 1
                if self.captureSession.isRunning {
                    if settleDelayMs <= 0 {
                        completion(.success(()))
                        return
                    }
                    self.sessionQueue.asyncAfter(deadline: .now() + .milliseconds(settleDelayMs)) {
                        completion(.success(()))
                    }
                } else if attempts < maxAttempts {
                    self.sessionQueue.asyncAfter(deadline: .now() + checkInterval) {
                        checkSession()
                    }
                } else {
                    completion(.failure(CameraSessionError.configurationFailed))
                }
            }
            
            sessionQueue.asyncAfter(deadline: .now() + checkInterval) {
                checkSession()
            }
        }
    }

    // MARK: - Public Camera Controls
    // 사진 캡처하는 기능
    func capturePhoto(completion: @escaping (Result<String, Error>) -> Void) {
        ensureConfigured(settleDelayMs: 0) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.sessionQueue.async {
                    guard self.photoOutput.connection(with: .video) != nil else {
                        completion(.failure(CameraSessionError.configurationFailed))
                        return
                    }

                    let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                    if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
                        settings.flashMode = self.flashMode
                    }

                    self.photoCompletion = completion
                    self.photoOutput.capturePhoto(with: settings, delegate: self)
                }
            }
        }
    }

    // 수정된 카메라 전환 로직 - 고정 시간 프레임 내에서 카메라 전환 + 오디오 일시정지 후 동시 재개
    func switchCamera(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard self.captureSession.isRunning else {
                completion(.failure(CameraSessionError.configurationFailed))
                return
            }

            let target: AVCaptureDevice.Position = (self.currentPosition == .back) ? .front : .back
            let previousZoom = self.videoInput?.device.videoZoomFactor ?? 1.0
            let previousLastVideoTimestamp = self.lastVideoTimestamp
            let previousLastAudioTimestamp = self.lastAudioTimestamp

            do {
                self.isSwitchingCamera = true

                // 녹화 중이면 오디오 일시정지 및 타이머 시작
                if self.isRecording {
                    self.pauseAudioDuringCameraSwitch()
                    self.scheduleSynchronizedSwitchCompletion()
                }

                self.lastVideoTimestamp = nil
                self.lastAudioTimestamp = nil

                // AVAssetWriter 사용 시 녹화 중에도 일반 교체 가능
                try self.replaceVideoInput(position: target, desiredZoomFactor: previousZoom)

                // 연결 설정 업데이트 (미러링만 변경, transform은 녹화 시작 시 고정)
                self.updateConnectionMirroring()

                // 녹화 중이 아니면 즉시 완료
                if !self.isRecording {
                    self.isSwitchingCamera = false
                    self.resumeAudioAfterCameraSwitchIfNeeded()
                }
                // 녹화 중이면 타이머 종료 시 두 기능 동시 완료 (scheduleSynchronizedSwitchCompletion에서 처리)                
                completion(.success(()))
            } catch {
                self.isSwitchingCamera = false
                self.cancelPendingAudioResume()
                self.resumeAudioAfterCameraSwitchIfNeeded()
                self.lastVideoTimestamp = previousLastVideoTimestamp
                self.lastAudioTimestamp = previousLastAudioTimestamp
                completion(.failure(error))
            }
        }
    }

    func setFlash(isOn: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            self.flashMode = isOn ? .on : .off
            completion(.success(()))
        }
    }

    func setZoom(to value: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion(.failure(CameraSessionError.deviceUnavailable))
                return
            }
            do {
                try device.lockForConfiguration()
                // 수정: 0.5x(초광각)처럼 1.0 미만 줌도 디바이스가 지원하면 허용합니다.
                let minValue = max(Double(device.minAvailableVideoZoomFactor), value)
                let clamped = min(Double(device.activeFormat.videoMaxZoomFactor), minValue)
                device.videoZoomFactor = CGFloat(clamped)
                device.unlockForConfiguration()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // 추가: 프리뷰 핀치 제스처로 연속 줌 처리
    func handlePinchZoom(scale: Double, state: UIGestureRecognizer.State) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                return
            }

            switch state {
            case .began:
                // 제스처 시작 시점의 줌을 기준(base)으로 잡습니다.
                self.pinchBaseZoomFactor = Double(device.videoZoomFactor)
                self.lastPinchAppliedZoomFactor = self.pinchBaseZoomFactor ?? 1.0
                self.lastPinchUpdateTime = 0

            case .changed:
                let baseZoom = self.pinchBaseZoomFactor ?? Double(device.videoZoomFactor)
                self.pinchBaseZoomFactor = baseZoom

                let desiredZoom = baseZoom * scale
                let minZoom = Double(device.minAvailableVideoZoomFactor)
                let maxZoom = Double(device.activeFormat.videoMaxZoomFactor)
                let clamped = min(max(desiredZoom, minZoom), maxZoom)

                // 수정: 업데이트 빈도를 줄여 lockForConfiguration 호출 폭주를 방지합니다.
                let now = CACurrentMediaTime()
                if abs(clamped - self.lastPinchAppliedZoomFactor) < 0.01 {
                    return
                }
                if now - self.lastPinchUpdateTime < 0.02 {
                    return
                }

                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = CGFloat(clamped)
                    device.unlockForConfiguration()
                    self.lastPinchAppliedZoomFactor = clamped
                    self.lastPinchUpdateTime = now
                } catch {
                    // 핀치 중 오류는 UI를 깨지 않도록 무시 (다음 업데이트에서 재시도)
                }

            case .ended, .cancelled, .failed:
                // 제스처가 끝나면 마지막으로 적용된 줌에서 그대로 멈춥니다.
                self.pinchBaseZoomFactor = nil

            default:
                break
            }
        }
    }

    // 추가: 프리뷰 세로 드래그(위/아래)로 연속 줌 처리
    func handleVerticalDragZoom(translationY: Double, state: UIGestureRecognizer.State) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                return
            }

            switch state {
            case .began:
                // 드래그 시작 시점의 줌을 기준(base)으로 잡습니다.
                self.dragBaseZoomFactor = Double(device.videoZoomFactor)
                self.lastDragAppliedZoomFactor = self.dragBaseZoomFactor ?? 1.0
                self.lastDragUpdateTime = 0

            case .changed:
                let baseZoom = self.dragBaseZoomFactor ?? Double(device.videoZoomFactor)
                self.dragBaseZoomFactor = baseZoom

                // 수정: 픽셀 이동을 곱셈 기반 줌으로 변환해(지수 함수) 핀치처럼 자연스럽게 줌이 변하도록 합니다.
                // translationY가 음수(위로 드래그)면 exp(-(-)/k) => exp(+) => 줌 인
                let pixelsPerNaturalZoomStep = 300.0
                let zoomMultiplier = exp(-translationY / pixelsPerNaturalZoomStep)
                let desiredZoom = baseZoom * zoomMultiplier

                let minZoom = Double(device.minAvailableVideoZoomFactor)
                let maxZoom = Double(device.activeFormat.videoMaxZoomFactor)
                let clamped = min(max(desiredZoom, minZoom), maxZoom)

                // 수정: 업데이트 빈도를 줄여 lockForConfiguration 호출 폭주를 방지합니다.
                let now = CACurrentMediaTime()
                if abs(clamped - self.lastDragAppliedZoomFactor) < 0.01 {
                    return
                }
                if now - self.lastDragUpdateTime < 0.02 {
                    return
                }

                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = CGFloat(clamped)
                    device.unlockForConfiguration()
                    self.lastDragAppliedZoomFactor = clamped
                    self.lastDragUpdateTime = now
                } catch {
                    // 드래그 중 오류는 UI를 깨지 않도록 무시 (다음 업데이트에서 재시도)
                }

            case .ended, .cancelled, .failed:
                // 드래그가 끝나면 마지막으로 적용된 줌에서 그대로 멈춥니다.
                self.dragBaseZoomFactor = nil

            default:
                break
            }
        }
    }

    func setBrightness(_ value: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion(.failure(CameraSessionError.deviceUnavailable))
                return
            }
            do {
                try device.lockForConfiguration()
                let bias = max(min(Float(value), device.maxExposureTargetBias), device.minExposureTargetBias)
                device.setExposureTargetBias(bias) { _ in }
                device.unlockForConfiguration()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func availableZoomLevels(completion: @escaping ([Double]) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion([1.0])
                return
            }

            let minZoom = Double(device.minAvailableVideoZoomFactor)
            let maxZoom = Double(device.activeFormat.videoMaxZoomFactor)

            // Define preferred zoom levels in priority order
            let preferredLevels: [Double] = [0.5, 1.0, 2.0, 3.0, 5.0]

            // Filter to only include levels within the device's supported range
            let supportedLevels = preferredLevels.filter { level in
                level >= minZoom && level <= maxZoom
            }

            // Ensure we have at least the min zoom level
            var finalLevels = Set(supportedLevels)
            finalLevels.insert(minZoom)

            // Return up to 3 levels, sorted
            completion(Array(finalLevels.sorted().prefix(3)))
        }
    }

    // 추가: 디바이스가 지원하는 줌 최소/최대 범위 제공 (연속 줌 UI용)
    func zoomRange(completion: @escaping (Double, Double) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion(1.0, 1.0)
                return
            }
            completion(
                Double(device.minAvailableVideoZoomFactor),
                Double(device.activeFormat.videoMaxZoomFactor)
            )
        }
    }

    func optimizeForCapture(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else {
                completion(.failure(CameraSessionError.deviceUnavailable))
                return
            }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                device.unlockForConfiguration()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func pauseSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    func resumeSession(completion: @escaping (Result<Void, Error>) -> Void) {
        ensureConfigured { outcome in
            completion(outcome)
        }
    }

    func dispose() {
        sessionQueue.sync {
            recordingTimer?.cancel()
            recordingTimer = nil
            if captureSession.isRunning { captureSession.stopRunning() }
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            captureSession.outputs.forEach { captureSession.removeOutput($0) }
            videoInput = nil
            audioInput = nil
            isConfigured = false
            isRecordingPipelineConfigured = false
            isAudioSessionConfigured = false
            currentMovieURL = nil
            cancelPendingAudioResume()
            resumeAudioAfterCameraSwitchIfNeeded()
        }
    }

    // AVAssetWriter 기반 녹화 시작 - 카메라 전환 지원
    func startRecording(maxDurationMs: Int?, completion: @escaping (Result<Void, Error>) -> Void) {
        ensureConfigured { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.sessionQueue.async {
                    guard !self.isRecording else {
                        completion(.failure(CameraSessionError.alreadyRecording))
                        return
                    }

                    do {
                        try self.configureRecordingPipelineIfNeeded()
                        let url = self.temporaryURL(extension: "mov")
                        self.currentMovieURL = url
                        self.isCancellingRecording = false

                        // Setup AVAssetWriter
                        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

                        // Audio settings
                        let audioSettings: [String: Any] = [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVNumberOfChannelsKey: 1,
                            AVSampleRateKey: 44100,
                            AVEncoderBitRateKey: 64000
                        ]

                        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                        audioInput.expectsMediaDataInRealTime = true

                        if writer.canAdd(audioInput) {
                            writer.add(audioInput)
                        }

                        self.assetWriter = writer
                        self.audioWriterInput = audioInput
                        self.videoWriterInput = nil
                        self.pixelBufferAdaptor = nil
                        self.recordingAspectRatio = nil
                        self.recordingStartTime = nil
                        self.lastVideoTimestamp = nil
                        self.lastAudioTimestamp = nil
                        self.timeOffset = .zero // 추가: 새 녹화 시작 시 오프셋 초기화
                        self.lastWrittenVideoTimestamp = nil // 추가
                        self.isSwitchingCamera = false
                        self.isRecording = true

                        self.startRecordingTimerIfNeeded(maxDurationMs: maxDurationMs)
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    func stopRecording(completion: @escaping (Result<String, Error>) -> Void) {
        sessionQueue.async {
            guard self.isRecording else {
                completion(.failure(CameraSessionError.notRecording))
                return
            }

            self.recordingTimer?.cancel()
            self.recordingTimer = nil
            self.isRecording = false
            self.isCancellingRecording = false
            self.cancelPendingAudioResume()
            self.resumeAudioAfterCameraSwitchIfNeeded()

            guard let writer = self.assetWriter,
                  let videoInput = self.videoWriterInput,
                  let audioInput = self.audioWriterInput else {
                completion(.failure(CameraSessionError.configurationFailed))
                return
            }

            videoInput.markAsFinished()
            audioInput.markAsFinished()

            writer.finishWriting { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    if writer.status == .completed, let url = self.currentMovieURL {
                        completion(.success(url.path))
                        self.delegate?.cameraSessionManager(self, didFinishRecording: url.path)
                    } else {
                        let error = writer.error ?? CameraSessionError.configurationFailed
                        completion(.failure(error))
                        self.delegate?.cameraSessionManager(self, didFailRecording: error)
                    }

                    self.assetWriter = nil
                    self.videoWriterInput = nil
                    self.audioWriterInput = nil
                    self.pixelBufferAdaptor = nil
                }
            }
        }
    }

    func cancelRecording(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard self.isRecording else {
                completion(.success(()))
                return
            }

            self.recordingTimer?.cancel()
            self.recordingTimer = nil
            self.isRecording = false
            self.isCancellingRecording = true
            self.cancelPendingAudioResume()
            self.resumeAudioAfterCameraSwitchIfNeeded()

            guard let writer = self.assetWriter,
                  let videoInput = self.videoWriterInput,
                  let audioInput = self.audioWriterInput else {
                completion(.success(()))
                return
            }

            videoInput.markAsFinished()
            audioInput.markAsFinished()

            writer.finishWriting { [weak self] in
                guard let self else { return }
                if let url = self.currentMovieURL {
                    self.cleanupRecordingFile(url)
                }
                DispatchQueue.main.async {
                    completion(.success(()))

                    self.assetWriter = nil
                    self.videoWriterInput = nil
                    self.audioWriterInput = nil
                    self.pixelBufferAdaptor = nil
                }
            }
        }
    }

    func registerPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        layer.videoGravity = .resizeAspectFill
        layer.session = captureSession
        ensureConfigured(startRunning: false) { _ in }
    }

    func updatePreviewBounds(_ bounds: CGRect) {
        sessionQueue.async {
            guard bounds.width > 0, bounds.height > 0 else { return }
            self.previewAspectRatio = bounds.width / bounds.height
        }
    }

    // MARK: - Private Helpers
    private func configureSession() throws {
        captureSession.sessionPreset = .high

        try replaceVideoInput(position: currentPosition, desiredZoomFactor: 1.0)

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        updateConnectionMirroring()
    }

    private func configureAudioSessionIfNeeded() throws {
        guard !isAudioSessionConfigured else { return }
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .videoRecording,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try audioSession.setActive(true)
        isAudioSessionConfigured = true
    }

    private func configureRecordingPipelineIfNeeded() throws {
        guard !isRecordingPipelineConfigured else { return }

        try configureAudioSessionIfNeeded()

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        if audioInput == nil, let audioDevice = AVCaptureDevice.default(for: .audio) {
            let input = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                audioInput = input
            }
        }

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        }

        updateConnectionMirroring()
        isRecordingPipelineConfigured = true
    }

    // 일반 비디오 입력 교체 (녹화 중이 아닐 때)
    private func replaceVideoInput(position: AVCaptureDevice.Position, desiredZoomFactor: CGFloat) throws {
        guard let device = cameraDevice(position: position) else {
            throw CameraSessionError.deviceUnavailable
        }

        let newInput = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()
        if let existing = videoInput {
            captureSession.removeInput(existing)
        }

        guard captureSession.canAddInput(newInput) else {
            captureSession.commitConfiguration()
            throw CameraSessionError.configurationFailed
        }

        captureSession.addInput(newInput)
        captureSession.commitConfiguration()

        // 비디오 출력 연결의 orientation 및 미러링 업데이트
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (position == .front)
            }
        }

        applyPreferredConfiguration(to: device, matching: desiredZoomFactor)

        videoInput = newInput
        currentPosition = position
    }

    private func startSessionIfNeeded() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // 캐시 확인
        if let cached = deviceCache[position], cached.isConnected {
            return cached
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera],
            mediaType: .video,
            position: position
        )
        if let device = discovery.devices.first {
            deviceCache[position] = device
            return device
        }

        if let fallback = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            deviceCache[position] = fallback
            return fallback
        }
        return nil
    }

    private var availablePositions: [AVCaptureDevice.Position] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.map { $0.position }.filter { $0 == .front || $0 == .back }.uniqued()
    }

    // 수정된 연결 미러링 업데이트
    private func updateConnectionMirroring() {
        // Photo output 연결 설정
        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (currentPosition == .front)
            }
        }

        // Video output 연결 설정
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (currentPosition == .front)
            }
        }
    }


    private func applyPreferredConfiguration(to device: AVCaptureDevice, matching previousZoom: CGFloat) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            let minZoom = max(previousZoom, 1.0)
            let clamped = min(device.activeFormat.videoMaxZoomFactor, minZoom)
            device.videoZoomFactor = clamped
        } catch {
            // Ignore configuration errors; device will keep defaults
        }
    }

    private func startRecordingTimerIfNeeded(maxDurationMs: Int?) {
        recordingTimer?.cancel()
        recordingTimer = nil

        guard let maxDurationMs, maxDurationMs > 0 else { return }

        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + .milliseconds(maxDurationMs))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            if self.isRecording {
                self.stopRecording { _ in }
            }
        }
        recordingTimer = timer
        timer.resume()
    }

    private func temporaryURL(extension ext: String) -> URL {
        let fileName = UUID().uuidString + "." + ext
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    }

    private func cleanupRecordingFile(_ url: URL?) {
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let completion = photoCompletion
        photoCompletion = nil

        if let error {
            completion?(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion?(.failure(CameraSessionError.configurationFailed))
            return
        }

        let url = temporaryURL(extension: "jpg")
        do {
            try data.write(to: url)
            completion?(.success(url.path))
        } catch {
            completion?(.failure(error))
        }
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording,
              let writer = assetWriter,
              CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Start writer on first *video* frame (audio may arrive first).
        if writer.status == .unknown, output != videoOutput {
            return
        }

        // Ensure video writer input matches the actual incoming frame size.
        if writer.status == .unknown, output == videoOutput, videoWriterInput == nil {
            do {
                try configureVideoWriterInputIfNeeded(from: sampleBuffer, writer: writer)
            } catch {
                // If we can't configure the writer, stop recording and report.
                isRecording = false
                let delegate = self.delegate
                DispatchQueue.main.async {
                    delegate?.cameraSessionManager(self, didFailRecording: error)
                }
                return
            }
        }

        // Start writer on first video frame
        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
            recordingStartTime = timestamp
        }

        guard writer.status == .writing else { return }

        if output == videoOutput {
            handleVideoSampleBuffer(sampleBuffer, timestamp: timestamp)
        } else if output == audioOutput {
            handleAudioSampleBuffer(sampleBuffer, timestamp: timestamp)
        }
    }

    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        guard let videoInput = videoWriterInput,
              let adaptor = pixelBufferAdaptor,
              videoInput.isReadyForMoreMediaData else {
            return
        }

        // 수정: 카메라 전환 시 timestamp가 점프하면(예: +1~2초) 영상에 공백이 생기고,
        // 그 공백 동안 오디오가 먼저 재생되는 문제가 생깁니다.
        // => timeOffset을 누적해 '점프한 시간만큼' 타임라인을 압축합니다.
        if let lastWritten = lastWrittenVideoTimestamp {
            let frameDuration = CMSampleBufferGetDuration(sampleBuffer).isValid
                ? CMSampleBufferGetDuration(sampleBuffer)
                : CMTime(value: 1, timescale: 30)
            let currentAdjusted = CMTimeSubtract(timestamp, timeOffset)
            let expectedNext = CMTimeAdd(lastWritten, frameDuration)
            let gap = CMTimeSubtract(currentAdjusted, expectedNext)
            if abs(CMTimeGetSeconds(gap)) > 0.1 {
                timeOffset = CMTimeAdd(timeOffset, gap)
            }
        }

        let adjustedTimestamp = CMTimeSubtract(timestamp, timeOffset)

        // 픽셀 버퍼 추가 (프리뷰 aspectFill과 동일하게 center-crop)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let didAppend: Bool
        if let cropped = makeCroppedPixelBufferIfNeeded(from: pixelBuffer, adaptor: adaptor) {
            didAppend = adaptor.append(cropped, withPresentationTime: adjustedTimestamp)
        } else {
            didAppend = adaptor.append(pixelBuffer, withPresentationTime: adjustedTimestamp)
        }
        guard didAppend else { return }
        lastVideoTimestamp = timestamp
        lastWrittenVideoTimestamp = adjustedTimestamp
        // 수정: 카메라 전환 중이라면 "첫 정상 비디오 프레임"을 기준으로 오디오를 즉시 재개합니다.
        // (기존처럼 고정 시간(예: 3초) 기다리면 짧게 녹화하면 전환 이후 오디오가 전부 비어버릴 수 있음)
        if isSwitchingCamera {
            cancelPendingAudioResume()
            isSwitchingCamera = false
            resumeAudioAfterCameraSwitchIfNeeded()
        }
    }

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        guard let audioInput = audioWriterInput,
              audioInput.isReadyForMoreMediaData else {
            return
        }

        if isSwitchingCamera {
            lastAudioTimestamp = nil
            return
        }

        guard let lastVideoTime = lastVideoTimestamp else {
            return
        }

        _ = lastVideoTime // 주석: video 기준 timestamp 확보 (연속 타임라인 조건)

        // 수정: video와 동일한 timeOffset을 적용해 타임라인을 연속으로 만듭니다.
        // (전환 시 오디오만 먼저 재생되는 문제 해결)
        guard let adjustedBuffer = makeSampleBufferBySubtractingTimeOffset(
            sampleBuffer,
            timeOffset: timeOffset
        ) else {
            return
        }

        // 추가: (보조 안전장치) 오디오가 비디오보다 앞서지 않도록 '조정된 PTS' 기준으로 한번 더 필터링합니다.
        if let lastWrittenVideoTimestamp {
            let adjustedAudioPTS = CMSampleBufferGetPresentationTimeStamp(adjustedBuffer)
            let signedDiff = CMTimeGetSeconds(CMTimeSubtract(adjustedAudioPTS, lastWrittenVideoTimestamp))
            if signedDiff < -0.02 {
                return
            }
        }

        guard audioInput.append(adjustedBuffer) else {
            return
        }
        lastAudioTimestamp = timestamp
    }

    // 추가: CMSampleBuffer의 타임스탬프에서 timeOffset을 빼서 '연속된 타임라인'로 만드는 유틸
    private func makeSampleBufferBySubtractingTimeOffset(
        _ sampleBuffer: CMSampleBuffer,
        timeOffset: CMTime
    ) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(
            sampleBuffer,
            entryCount: 0,
            arrayToFill: nil,
            entriesNeededOut: &count
        )
        guard count > 0 else { return sampleBuffer }

        var timingInfo = Array(
            repeating: CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid),
            count: Int(count)
        )
        CMSampleBufferGetSampleTimingInfoArray(
            sampleBuffer,
            entryCount: count,
            arrayToFill: &timingInfo,
            entriesNeededOut: &count
        )

        for index in 0..<timingInfo.count {
            if timingInfo[index].presentationTimeStamp.isValid {
                timingInfo[index].presentationTimeStamp = CMTimeSubtract(
                    timingInfo[index].presentationTimeStamp,
                    timeOffset
                )
            }
            if timingInfo[index].decodeTimeStamp.isValid {
                timingInfo[index].decodeTimeStamp = CMTimeSubtract(
                    timingInfo[index].decodeTimeStamp,
                    timeOffset
                )
            }
        }

        var out: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: timingInfo.count,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &out
        )
        guard status == noErr else { return nil }
        return out
    }

    private func pauseAudioDuringCameraSwitch() {
        guard !isAudioPausedForSwitch else { return }
        cancelPendingAudioResume()
        isAudioPausedForSwitch = true
        setAudioOutputEnabled(false)
    }

    // 고정 시간 프레임 후 카메라 전환 완료 + 오디오 재개를 동시에 수행
    private func scheduleSynchronizedSwitchCompletion() {
        // 기존 타이머 취소
        cancelPendingAudioResume()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // 두 기능을 동시에 완료
            self.isSwitchingCamera = false           // 카메라 전환 완료
            self.resumeAudioAfterCameraSwitchIfNeeded() // 오디오 재개
            self.audioResumeWorkItem = nil
            self.isAudioResumeScheduled = false
        }

        isAudioResumeScheduled = true
        audioResumeWorkItem = workItem
        sessionQueue.asyncAfter(
            deadline: .now() + .milliseconds(cameraSwitchTimeFrameMs),
            execute: workItem
        )
    }

    private func resumeAudioAfterCameraSwitchIfNeeded() {
        guard isAudioPausedForSwitch else { return }
        isAudioPausedForSwitch = false
        cancelPendingAudioResume()
        setAudioOutputEnabled(true)
    }

    private func cancelPendingAudioResume() {
        audioResumeWorkItem?.cancel()
        audioResumeWorkItem = nil
        isAudioResumeScheduled = false
    }

    private func setAudioOutputEnabled(_ isEnabled: Bool) {
        audioOutput.connections.forEach { connection in
            connection.isEnabled = isEnabled
        }
    }

    private func configureVideoWriterInputIfNeeded(from sampleBuffer: CMSampleBuffer, writer: AVAssetWriter) throws {
        guard videoWriterInput == nil, pixelBufferAdaptor == nil else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw CameraSessionError.configurationFailed
        }

        let inputWidth = CVPixelBufferGetWidth(pixelBuffer)
        let inputHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard inputWidth > 0, inputHeight > 0 else {
            throw CameraSessionError.configurationFailed
        }

        let targetAspect = previewAspectRatio ?? (CGFloat(inputWidth) / CGFloat(inputHeight))
        recordingAspectRatio = targetAspect
        let cropSize = computeCenterCropSize(
            inputWidth: inputWidth,
            inputHeight: inputHeight,
            targetAspect: targetAspect
        )
        let width = cropSize.width
        let height = cropSize.height

        // Scale bitrate roughly with pixel count; clamp to sane bounds.
        let referencePixels = Double(1920 * 1080)
        let pixelCount = Double(width * height)
        let scaledBitrate = Int((6000000.0 * (pixelCount / referencePixels)).rounded())
        let averageBitrate = max(2_000_000, min(12_000_000, scaledBitrate))

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: averageBitrate,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        videoInput.transform = .identity

        guard writer.canAdd(videoInput) else {
            throw CameraSessionError.configurationFailed
        }
        writer.add(videoInput)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        self.videoWriterInput = videoInput
        self.pixelBufferAdaptor = adaptor
    }

    private struct CropSize {
        let width: Int
        let height: Int
    }

    private func computeCenterCropSize(inputWidth: Int, inputHeight: Int, targetAspect: CGFloat) -> CropSize {
        let inputAspect = CGFloat(inputWidth) / CGFloat(inputHeight)
        var cropWidth = CGFloat(inputWidth)
        var cropHeight = CGFloat(inputHeight)

        if inputAspect > targetAspect {
            // Input is wider: crop left/right.
            cropWidth = cropHeight * targetAspect
        } else if inputAspect < targetAspect {
            // Input is taller: crop top/bottom.
            cropHeight = cropWidth / targetAspect
        }

        // Encoder friendliness: ensure even dimensions.
        var outW = max(2, Int(cropWidth.rounded(.down)))
        var outH = max(2, Int(cropHeight.rounded(.down)))
        if outW % 2 == 1 { outW -= 1 }
        if outH % 2 == 1 { outH -= 1 }

        // Clamp just in case.
        outW = min(outW, inputWidth - (inputWidth % 2))
        outH = min(outH, inputHeight - (inputHeight % 2))
        return CropSize(width: outW, height: outH)
    }

    private func makeCroppedPixelBufferIfNeeded(from pixelBuffer: CVPixelBuffer, adaptor: AVAssetWriterInputPixelBufferAdaptor) -> CVPixelBuffer? {
        guard let targetAspect = recordingAspectRatio else { return nil }
        let inputWidth = CVPixelBufferGetWidth(pixelBuffer)
        let inputHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard inputWidth > 0, inputHeight > 0 else { return nil }

        let cropSize = computeCenterCropSize(
            inputWidth: inputWidth,
            inputHeight: inputHeight,
            targetAspect: targetAspect
        )

        // No-op crop
        if cropSize.width == inputWidth, cropSize.height == inputHeight {
            return nil
        }

        guard let pool = adaptor.pixelBufferPool else { return nil }
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputBuffer)
        guard status == kCVReturnSuccess, let out = outputBuffer else { return nil }

        let originX = CGFloat(inputWidth - cropSize.width) / 2.0
        let originY = CGFloat(inputHeight - cropSize.height) / 2.0
        let cropRect = CGRect(x: originX, y: originY, width: CGFloat(cropSize.width), height: CGFloat(cropSize.height))

        let croppedImage = CIImage(cvPixelBuffer: pixelBuffer)
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
        cropContext.render(
            croppedImage,
            to: out,
            bounds: CGRect(x: 0, y: 0, width: cropRect.width, height: cropRect.height),
            colorSpace: cropColorSpace
        )
        return out
    }
}

// MARK: - Preview bridge
fileprivate final class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
    private let sessionManager: CameraSessionManager

    init(sessionManager: CameraSessionManager) {
        self.sessionManager = sessionManager
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        CameraPreviewView(frame: frame, sessionManager: sessionManager)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

fileprivate final class CameraPreviewView: NSObject, FlutterPlatformView, UIGestureRecognizerDelegate {
    private let previewView = PreviewView()
    private let sessionManager: CameraSessionManager
    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
        // 추가: 두 손가락 핀치로 프리뷰를 자연스럽게 확대/축소합니다.
        let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self // 추가: 핀치/드래그가 동시에 동작할 수 있게 delegate 설정
        return recognizer
    }()
    private lazy var verticalPanGestureRecognizer: UIPanGestureRecognizer = {
        // 추가: 1손가락 세로 드래그로 줌 인/아웃 (위로 드래그: 줌 인 / 아래로 드래그: 줌 아웃)
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalPan(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.minimumNumberOfTouches = 1
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = self
        return recognizer
    }()

    init(frame: CGRect, sessionManager: CameraSessionManager) {
        self.sessionManager = sessionManager
        super.init()
        previewView.frame = frame
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        previewView.isUserInteractionEnabled = true // 추가: 핀치/드래그 제스처 입력을 받기 위해 활성화
        previewView.addGestureRecognizer(pinchGestureRecognizer) // 추가
        previewView.addGestureRecognizer(verticalPanGestureRecognizer) // 추가
        sessionManager.registerPreviewLayer(previewView.previewLayer)
        previewView.onLayout = { [weak sessionManager] bounds in
            sessionManager?.updatePreviewBounds(bounds)
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        // 추가: 프리뷰 UIView에서 들어온 제스처를 세션 매니저로 전달해 줌을 연속 제어합니다.
        sessionManager.handlePinchZoom(scale: Double(recognizer.scale), state: recognizer.state)
    }

    @objc private func handleVerticalPan(_ recognizer: UIPanGestureRecognizer) {
        // 추가: 세로 드래그의 누적 이동량(translationY)을 기반으로 연속 줌을 제어합니다.
        let translation = recognizer.translation(in: previewView)
        sessionManager.handleVerticalDragZoom(
            translationY: Double(translation.y),
            state: recognizer.state
        )
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 추가: 핀치와 드래그가 충돌하지 않도록 동시 인식을 허용합니다.
        true
    }


    func view() -> UIView {
        previewView
    }
}

fileprivate final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var onLayout: ((CGRect) -> Void)?

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        onLayout?(bounds)
    }
}

fileprivate extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
