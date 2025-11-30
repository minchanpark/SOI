import Flutter
import UIKit
import AVFoundation

// MARK: - Flutter Plugin Entry Point
public final class SwiftCameraPlugin: NSObject, FlutterPlugin {
    private static let channelName = "com.soi.camera"

    private let sessionManager = CameraSessionManager()
    private var channel: FlutterMethodChannel?

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
    private var isSwitchingCamera = false
    private var isAudioPausedForSwitch = false
    private var audioResumeWorkItem: DispatchWorkItem?
    private var isAudioResumeScheduled = false

    // 카메라 전환 시간 프레임 (밀리초) - 이 시간 동안 오디오 일시정지 유지
    private let cameraSwitchTimeFrameMs: Int = 3000

    var supportsLiveSwitch: Bool {
        availablePositions.count > 1
    }

    func ensureConfigured(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            if self.isConfigured {
                self.startSessionIfNeeded()
                self.waitForSessionToStart(completion: completion)
                return
            }

            do {
                try self.configureSession()
                self.isConfigured = true
                self.startSessionIfNeeded()
                self.waitForSessionToStart(completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func waitForSessionToStart(completion: @escaping (Result<Void, Error>) -> Void) {
        if captureSession.isRunning {
            // 세션이 실행 중이면 최소한의 대기로 즉시 프리뷰 표시 (1.0s → 0.1s)
            sessionQueue.asyncAfter(deadline: .now() + 0.1) {
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
                    // 최소한의 대기로 즉시 프리뷰 표시 (1.0s → 0.1s)
                    self.sessionQueue.asyncAfter(deadline: .now() + 0.1) {
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

    func capturePhoto(completion: @escaping (Result<String, Error>) -> Void) {
        ensureConfigured { [weak self] result in
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
                // 녹화 중이면 타이머 종료 시 두 기능 동시 완료 (scheduleSynchronizedSwitchCompletion에서 처리)                completion(.success(()))
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
                let minValue = max(1.0, value)
                let clamped = min(Double(device.activeFormat.videoMaxZoomFactor), minValue)
                device.videoZoomFactor = CGFloat(clamped)
                device.unlockForConfiguration()
                completion(.success(()))
            } catch {
                completion(.failure(error))
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
                        let url = self.temporaryURL(extension: "mov")
                        self.currentMovieURL = url
                        self.isCancellingRecording = false

                        // Setup AVAssetWriter
                        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

                        // Video settings
                        let videoSettings: [String: Any] = [
                            AVVideoCodecKey: AVVideoCodecType.h264,
                            AVVideoWidthKey: 1920,
                            AVVideoHeightKey: 1080,
                            AVVideoCompressionPropertiesKey: [
                                AVVideoAverageBitRateKey: 6000000,
                                AVVideoMaxKeyFrameIntervalKey: 30
                            ]
                        ]

                        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                        videoInput.expectsMediaDataInRealTime = true

                        // No transform needed - orientation is already handled by AVCaptureConnection
                        // The video data comes in portrait orientation from videoOutput
                        videoInput.transform = .identity

                        // Audio settings
                        let audioSettings: [String: Any] = [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVNumberOfChannelsKey: 1,
                            AVSampleRateKey: 44100,
                            AVEncoderBitRateKey: 64000
                        ]

                        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                        audioInput.expectsMediaDataInRealTime = true

                        // Pixel buffer adaptor
                        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                            assetWriterInput: videoInput,
                            sourcePixelBufferAttributes: [
                                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                            ]
                        )

                        if writer.canAdd(videoInput) {
                            writer.add(videoInput)
                        }
                        if writer.canAdd(audioInput) {
                            writer.add(audioInput)
                        }

                        self.assetWriter = writer
                        self.videoWriterInput = videoInput
                        self.audioWriterInput = audioInput
                        self.pixelBufferAdaptor = pixelBufferAdaptor
                        self.recordingStartTime = nil
                        self.lastVideoTimestamp = nil
                        self.lastAudioTimestamp = nil
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
        ensureConfigured { _ in }
    }

    // MARK: - Private Helpers
    private func configureSession() throws {
        // AVAudioSession 설정 (AVCaptureSession 설정 전에 필수!)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .videoRecording,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try audioSession.setActive(true)
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        try replaceVideoInput(position: currentPosition, desiredZoomFactor: 1.0)

        // 오디오 입력 추가 (비디오 녹화에 필수)
        if audioInput == nil, let audioDevice = AVCaptureDevice.default(for: .audio) {
            let input = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                audioInput = input
            }
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

                // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            
            // Set video orientation to portrait
            if let connection = videoOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                // 비디오 미러링 설정 (전면 카메라의 경우)
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (currentPosition == .front)
                }
            }
        }

        // Configure audio output
        audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        }

        captureSession.commitConfiguration()
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

        // Start writer on first frame
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

        // 타임스탬프 불연속성 감지 (카메라 전환 감지)
        if let lastTimestamp = lastVideoTimestamp {
            let timeDiff = CMTimeGetSeconds(CMTimeSubtract(timestamp, lastTimestamp))
            if timeDiff > 0.1 || timeDiff < 0 {
                // 타임스탬프 초기화만 수행, 오디오 처리는 타이머가 담당
                lastVideoTimestamp = nil
                return
            }
        }

        // 픽셀 버퍼 추가
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            adaptor.append(pixelBuffer, withPresentationTime: timestamp)
            lastVideoTimestamp = timestamp
            // 오디오 재개는 타이머가 담당하므로 여기서는 처리하지 않음
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

        let timeDiff = abs(CMTimeGetSeconds(CMTimeSubtract(timestamp, lastVideoTime)))

        // Skip audio samples that are too far from video (> 1.0s)
        if timeDiff > 1.0 {
            return
        }

        audioInput.append(sampleBuffer)
        lastAudioTimestamp = timestamp
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

fileprivate final class CameraPreviewView: NSObject, FlutterPlatformView {
    private let previewView = PreviewView()

    init(frame: CGRect, sessionManager: CameraSessionManager) {
        super.init()
        previewView.frame = frame
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sessionManager.registerPreviewLayer(previewView.previewLayer)
    }


    func view() -> UIView {
        previewView
    }
}

fileprivate final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
    }
}

fileprivate extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
