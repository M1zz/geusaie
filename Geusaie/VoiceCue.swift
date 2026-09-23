import Foundation
import Speech
import AVFoundation

// MARK: - "다음" 한 마디로 단계를 넘긴다
//
// 요리 중엔 손이 젖어 있거나 기름이 묻어 있다. 화면을 만지지 않고 말로 넘길 수 있게
// 한국어 음성인식을 켜 두고 '다음'만 듣는다. 가능하면 기기 안에서만 처리한다.

@MainActor
final class VoiceCue: ObservableObject {

    enum State: Equatable {
        case off          // 꺼짐 (사용자가 껐거나 아직 시작 전)
        case listening    // 듣는 중
        case denied       // 권한 없음
        case unavailable  // 이 기기에서 한국어 인식을 못 씀
    }

    @Published private(set) var state: State = .off

    /// "다음"이 들렸을 때
    var onNext: (() -> Void)?

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko_KR"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastFired = Date.distantPast
    private var restarts = 0              // 소리가 전혀 안 들어올 때 무한 재시작 방지
    private var restartWork: Task<Void, Never>?

    var isListening: Bool { state == .listening }

    func toggle() { isListening ? stop() : start() }

    // MARK: 켜기

    func start() {
        guard state != .listening else { return }
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            Task { @MainActor in
                guard let self else { return }
                guard auth == .authorized else { self.state = .denied; return }
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        guard granted else { self.state = .denied; return }
                        self.restarts = 0
                        self.listen()
                    }
                }
            }
        }
    }

    private func listen() {
        guard let recognizer, recognizer.isAvailable else { state = .unavailable; return }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playAndRecord, mode: .measurement,
                                  options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try audio.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            request = req

            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024,
                             format: input.outputFormat(forBus: 0)) { buffer, _ in
                req.append(buffer)
            }
            engine.prepare()
            try engine.start()

            state = .listening
            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let text = result?.bestTranscription.formattedString, !text.isEmpty {
                        self.restarts = 0          // 소리가 들어오고 있다
                        if Self.hearsNext(text) { self.fire() }
                    }
                    if error != nil || result?.isFinal == true { self.restart() }
                }
            }
        } catch {
            state = .unavailable
            stopAudio()
        }
    }

    /// 방금 한 말의 끝이 '다음'인지 — 앞에서 한 번 나온 말이 계속 걸리지 않게 뒤만 본다
    static func hearsNext(_ text: String) -> Bool {
        let tail = text.split(separator: " ").suffix(2).joined()
        return tail.contains("다음")
    }

    private func fire() {
        guard Date().timeIntervalSince(lastFired) > 1.5 else { return }
        lastFired = Date()
        onNext?()
        restart()   // 인식 버퍼를 비워 같은 말이 또 잡히지 않게
    }

    private func restart() {
        guard state == .listening else { return }
        restarts += 1
        guard restarts < 8 else { stop(); state = .unavailable; return }
        stopAudio()
        restartWork?.cancel()
        restartWork = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, self.state == .listening else { return }
            self.listen()
        }
    }

    // MARK: 끄기

    func stop() {
        restartWork?.cancel()
        restartWork = nil
        stopAudio()
        state = .off
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopAudio() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }
}
