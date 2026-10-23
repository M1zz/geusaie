import Foundation
import Speech
import AVFoundation

// MARK: - "다음" 한 마디로 단계를 넘긴다
//
// 요리 중엔 손이 젖어 있거나 기름이 묻어 있다. 화면을 만지지 않고 말로 넘길 수 있게
// 앱이 보이는 언어로 음성인식을 켜 두고 그 언어의 '다음'(버튼 글자와 같은 말)만 듣는다.
// 가능하면 기기 안에서만 처리한다.

@MainActor
final class VoiceCue: ObservableObject {

    enum State: Equatable {
        case off          // 꺼짐 (사용자가 껐거나 아직 시작 전)
        case listening    // 듣는 중
        case denied       // 권한 없음
        case unavailable  // 이 기기에서 그 언어 인식을 못 씀
    }

    @Published private(set) var state: State = .off

    /// "다음"이 들렸을 때
    var onNext: (() -> Void)?

    private let engine = AVAudioEngine()
    private let language = VoiceCue.appLanguage
    private lazy var recognizer = SFSpeechRecognizer(locale: Locale(identifier: VoiceCue.speechLocale(for: language)))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastFired = Date.distantPast
    private var restarts = 0              // 소리가 전혀 안 들어올 때 무한 재시작 방지
    private var restartWork: Task<Void, Never>?

    var isListening: Bool { state == .listening }

    /// 사용자가 직접 껐는지 — 그렇다면 재개·복귀 때 저절로 다시 켜지 않는다
    private(set) var userTurnedOff = false

    func toggle() {
        if isListening {
            turnOff()
        } else {
            userTurnedOff = false
            start()
        }
    }

    /// 사용자가 끈 것 (자동으로 끈 것과 구분)
    func turnOff() {
        userTurnedOff = true
        stop()
    }

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
                        if Self.hearsNext(text, language: self.language) { self.fire() }
                    }
                    if error != nil || result?.isFinal == true { self.restart() }
                }
            }
        } catch {
            state = .unavailable
            stopAudio()
        }
    }

    // MARK: 언어

    /// 지금 앱 화면이 쓰는 언어(번역 묶음 이름: ko · en · en-GB · zh-Hans …)
    static var appLanguage: String { Bundle.main.preferredLocalizations.first ?? "ko" }

    /// 음성 인식기에 줄 지역 로케일 — 화면 언어와 같은 말로 듣는다
    static func speechLocale(for language: String) -> String {
        let map = ["ko": "ko-KR", "en": "en-US", "en-GB": "en-GB", "ja": "ja-JP",
                   "zh-Hans": "zh-CN", "zh-Hant": "zh-TW", "ru": "ru-RU", "es": "es-ES",
                   "de": "de-DE", "fr": "fr-FR", "it": "it-IT", "pt-BR": "pt-BR", "th": "th-TH",
                   "vi": "vi-VN", "cs": "cs-CZ", "da": "da-DK", "el": "el-GR", "fi": "fi-FI",
                   "id": "id-ID", "nb": "nb-NO", "nl": "nl-NL", "pl": "pl-PL", "sv": "sv-SE",
                   "tr": "tr-TR"]
        return map[language] ?? map[String(language.prefix(2))] ?? "ko-KR"
    }

    /// 언어마다 '다음'으로 알아들을 말 — 첫 번째가 화면 버튼에 적힌 말이다
    static func nextWords(for language: String) -> [String] {
        let words: [String: [String]] = [
            "ko": ["다음"],
            "en": ["next"], "en-GB": ["next"],
            "ja": ["次へ", "次", "つぎ", "ネクスト"],
            "zh-Hans": ["下一步", "下一个", "下一"], "zh-Hant": ["下一步", "下一個", "下一"],
            "ru": ["далее", "дальше", "следующ"],
            "es": ["siguiente"], "de": ["weiter"], "fr": ["suivant"],
            "it": ["avanti", "successivo"], "pt-BR": ["próximo"],
            "th": ["ถัดไป", "ต่อไป"], "vi": ["tiếp theo", "tiếp"],
            "cs": ["další"], "da": ["næste"], "el": ["επόμενο"], "fi": ["seuraava"],
            "id": ["berikutnya", "lanjut"], "nb": ["neste"], "nl": ["volgende"],
            "pl": ["dalej", "następn"], "sv": ["nästa"], "tr": ["ileri", "sonraki"],
        ]
        return words[language] ?? words[String(language.prefix(2))] ?? ["다음"]
    }

    /// 방금 한 말의 끝이 '다음'인지 — 앞에서 한 번 나온 말이 계속 걸리지 않게 뒤만 본다
    static func hearsNext(_ text: String, language: String = "ko") -> Bool {
        let fold: (String) -> String = {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                       locale: Locale(identifier: language))
        }
        let tail = fold(text.split(separator: " ").suffix(2).joined(separator: " "))
        let squeezed = tail.replacingOccurrences(of: " ", with: "")
        return nextWords(for: language).map(fold).contains {
            tail.contains($0) || squeezed.contains($0.replacingOccurrences(of: " ", with: ""))
        }
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
