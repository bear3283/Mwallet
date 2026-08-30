//
//  RecordViewModel.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/12/23.
//

import AVFoundation
import CoreML
import NaturalLanguage
import OSLog
import Speech
import SwiftUI
import Combine

// 음성 기록 준비 단계에서 복구 가능한 실패. 화면은 녹음을 시작하지 않고 넘어간다.
enum RecordError: LocalizedError {
    case speechRecognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechRecognizerUnavailable:
            // '한국어' 라고 못 박아 두면 독일어 기기에서 엉뚱한 말이 된다.
            // 실제로 어느 언어로 들으려 했는지 SpeechLocale 에게 묻는다.
            let language = SpeechLocale.resolvedLanguageName
            return String(localized: "이 기기에서 \(language) 음성 인식을 쓸 수 없습니다. 직접 기록으로 남겨 주세요.")
        }
    }
}

// 화면이 직접 들고 있는 상태다. @Published 갱신은 메인에서만 일어나야 하므로
// 클래스 전체를 메인 액터에 묶는다. 음성 인식과 오디오 콜백은 임의의 스레드로
// 오므로, 그 경계에서 메인으로 넘긴다.
@MainActor
// 이 클래스는 아직 250줄을 넘는다. 남은 무게는 대부분 오디오다 —
// AVAudioEngine 으로 소리를 받고, 음성 인식에 흘리고, 파일로 남기는
// 125줄이 여기 있다. 따로 떼어 낼 자리는 분명히 보인다.
//
// 옮기지 않은 것은 확인할 방법이 없어서다. 이 경로는 실기기 마이크가
// 있어야 돌고, 테스트도 화면 캡처도 그 길을 밟지 않는다. 옮겨서 무언가
// 어긋나도 아무것도 알려 주지 않는다. 실기기로 눌러 보며 옮길 수 있을 때
// 하기로 하고, 그때까지 이 한 줄로 예외를 눈에 보이게 남긴다.
// swiftlint:disable:next type_body_length
final class RecordViewModel: ObservableObject {

    let viewContext = PersistenceController.shared.container.viewContext
    var mlModel: MLModel?
    var infoPredictor: NLModel?
    var voiceSentencePartitionArray: [String] = [] {
        didSet {
            if voiceSentencePartitionArray.count == 0 {
                voiceSentence = ""
            } else {
                var tempVoiceSentence = voiceSentencePartitionArray.reduce("") { $0 + $1 + " " }
                tempVoiceSentence.removeLast()
                voiceSentence = tempVoiceSentence
            }
        }
    }
    @Published var voiceSentence = "" { // passive
        didSet {
            DispatchQueue.main.async {
                self.divideVoiceSentence()
                self.classifyVoiceSentenceInfo()
            }
        }
    }

    // these variables are updated by divideVoiceSentence()
    @Published var infoCategory: ExpenseInfoCategory = .unknown
    @Published var info: String? {
        didSet {
            if oldValue == nil && info != nil {
                DispatchQueue.main.async {
                    let hapticEngine = UIImpactFeedbackGenerator(style: .medium)
                    hapticEngine.impactOccurred()
                }
                
                guard info != "" else {
                    info = nil // didSet is called again
                    return
                }
                
                var weightedLength: Double = 0
                var tempVisibleInfo: String = ""
                
                for letter in info! {
                    tempVisibleInfo.append(String(letter))
                    if let safeScalar = Unicode.Scalar(String(letter)) {
                        let n = Int(safeScalar.value)
                        if (48 <= n && n <= 57) || (65 <= n && n <= 90) || (97 <= n && n <= 122) || (n == 32) || (n == 46) { // 0 ~ 9, A ~ Z, a ~ z, 공백, 마침표
                            weightedLength += 0.75
                        } else {
                            weightedLength += 1
                        }
                        if weightedLength <= 15 {
                            continue
                        } else {
                            tempVisibleInfo.removeLast()
                            break
                        }
                    }
                }
                if info! != tempVisibleInfo {
                    info! = tempVisibleInfo.reduce("") { $0 + String($1)} // didSet is called again
                    return
                }
            }
        }
    }
    @Published var payAmount: Double = -1 {
        didSet {
            if payAmount > 1_000_000_000.99 {
                payAmount = 1_000_000_000.0 + Double((Int(payAmount * 100) - Int(payAmount) * 100)) * 0.01
            }
        }
    }
    @Published var paymentMethod: PaymentMethod = .unknown {
        didSet {
            if oldValue == .unknown && paymentMethod != .unknown {
                DispatchQueue.main.async {
                    let hapticEngine = UIImpactFeedbackGenerator(style: .medium)
                    hapticEngine.impactOccurred()
                }
            }
        }
    }
    
    // travels
    @Published var travelArray: [Travel] = []
    
    // shows other views
    @Published var travelChoiceModalIsShown = false {
        willSet {
            if newValue {
                do {
                    travelArray = try viewContext.fetch(Travel.fetchRequest())
                } catch {
                    Logger.data.error("여행 목록 조회 실패: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    // view state
    
    @Published var manualRecordViewIsShown = false
    @Published var alertView_emptyIsShown = false {
        didSet {
            if alertView_emptyIsShown {
                alertView_shortIsShown = false
            }
        }
    }
    @Published var alertView_shortIsShown = false {
        didSet {
            if alertView_shortIsShown {
                alertView_emptyIsShown = false
            }
        }
    }
    
    @Published var addTravelRequestModalIsShown = false
    @Published var recordButtonIsFocused = false
    var wantToActivateAutoSaveTimer = true
    var AreThereOtherTravels = true
    var isExplicitTempRecord = false
    
    // STT
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechRecognizer = SpeechLocale.makeRecognizer()
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // record
    private var audioRecorder: AVAudioRecorder?
    
    // variables to save record file
    var soundRecordPath: URL?
    var soundRecordFileName: URL?
    
    // variables to evaluate record button pressing time
    var startRecordTime = CFAbsoluteTimeGetCurrent()
    var endRecordTime = CFAbsoluteTimeGetCurrent()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - timer
    var recordButtonResetTimer: Timer?
    
    init() {
        do {
            mlModel = try InfoClassifier(configuration: MLModelConfiguration()).model
        } catch {
            Logger.record.error("분류 모델 생성 실패: \(error.localizedDescription, privacy: .public)")
        }
        do {
            infoPredictor = try NLModel(mlModel: mlModel!)
        } catch {
            Logger.record.error("분류기 생성 실패: \(error.localizedDescription, privacy: .public)")
        }

        $payAmount
            .removeDuplicates()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] amount in
                guard let self = self else { return }
                if amount != -1 {
                    self.generateHapticFeedback()
                }
            }
            .store(in: &cancellables)

    }
    
    // MARK: 녹음 기능
    
    /// 말한 문장을 내역·금액·결제 방식으로 나눠 화면 상태에 싣는다.
    /// 나누는 규칙 자체는 VoiceSentenceParser 가 들고 있다.
    func divideVoiceSentence() {
        let parsed = VoiceSentenceParser.parse(voiceSentence)
        paymentMethod = parsed.paymentMethod
        payAmount = parsed.amount
        info = parsed.info
    }

    func classifyVoiceSentenceInfo() {
        if let infoPredictor, let info, let label = infoPredictor.predictedLabel(for: info) {
            infoCategory = ExpenseInfoCategory(modelLabel: label)
        } else {
            infoCategory = .unknown
        }
    }

    func updateVoiceSentence(with transcribedString: String) {
        guard transcribedString.count > 0 else { // 새로운 문장이 공백인 경우
            return
        }
        if voiceSentencePartitionArray.count == 0 { // 파티션 어레이가 빈 경우
            voiceSentencePartitionArray.append(transcribedString) // 추가하기
            return
        }
        if voiceSentencePartitionArray.last!.getCharacterFormArray().getSplitVarietyAndNumericPrefixCount().0 == .noNumericInterpretation && transcribedString.getCharacterFormArray().getSplitVarietyAndNumericPrefixCount().0 == .allNumeric { // 기존의 마지막 문장은 숫자로 해석되지 않고 새로운 문장은 숫자로 해석되는 경우
            voiceSentencePartitionArray.append(transcribedString) // 추가하기
            return
        }
        if voiceSentencePartitionArray.last!.count >= 3 && transcribedString.count == 1 { // 기존의 마지막 문장 길이가 3 이상이고 새로운 문장의 길이가 1인 경우; 3은 임의로 정한 값
            voiceSentencePartitionArray.append(transcribedString) // 추가하기
            return
        }
        if transcribedString.count < voiceSentencePartitionArray.last!.count - 5 && transcribedString.count < 4 { // 기존의 마지막 문장보다 새로운 문장이 명백히 짧고 새로운 문장의 길이가 4 미만인 경우; 4와 5는 임의로 정한 값
            voiceSentencePartitionArray.append(transcribedString) // 추가하기
            return
        }
        voiceSentencePartitionArray[voiceSentencePartitionArray.count - 1] = transcribedString // 대체하기
        return
    }
    
    func resetTranscribedString() {
        voiceSentencePartitionArray = []
    }
    
    func startSTT() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let hapticEngine = UIImpactFeedbackGenerator(style: .medium)
        hapticEngine.prepare()
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        
        // 인식기가 없으면(지원하지 않는 지역 설정) 아래 recognitionTask 가 조용히
        // nil 이 되어 녹음만 돌고 받아쓰기는 아무 일도 하지 않는다. 먼저 막는다.
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw RecordError.speechRecognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // ⚠️ 이 클로저는 실시간 오디오 스레드에서 돈다.
        //    예전에는 self.recognitionRequest 를 매 콜백마다 읽었는데,
        //    메인에서 stopSTT 가 그 프로퍼티를 nil 로 바꾸는 순간과 겹칠 수 있었다.
        //    지역 상수를 붙잡아 두면 프로퍼티를 건드리지 않아 그 경합이 사라진다.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // 인식 결과는 임의의 큐로 온다. 화면 상태는 메인으로 넘겨서 바꾼다.
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcribed = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.updateVoiceSentence(with: transcribed)
                }
            }
            if error != nil {
                Task { @MainActor in
                    self.stopSTT()
                }
            }
        }
    }
    
    func stopSTT() {
        if recognitionTask != nil { // startSTT() 동작이 끝난 경우에 stopSTT() 동작
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            recognitionTask = nil
            
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                Logger.record.error("오디오 세션 해제 실패: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func startRecording() async {
        // 지출 기록에는 결제 위치가 함께 저장된다. 사용자가 녹음을 시작한
        // 이 시점이 위치 권한을 요청할 맥락이다. (이미 준비됐으면 무시된다)
        DateGapHandler.shared.requestAuthorization()

        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            Logger.record.error("녹음을 준비하지 못했습니다")
        }
        
        soundRecordPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // VOICE로 시작하는 파일 삭제
        if let soundRecordPath {
            do {
                let fileManager = FileManager.default
                let filesInDirectory = try fileManager.contentsOfDirectory(at: soundRecordPath, includingPropertiesForKeys: nil)
                for fileURL in filesInDirectory where fileURL.lastPathComponent.hasPrefix("VOICE") {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                Logger.record.error("녹음 파일 삭제 실패: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        soundRecordFileName = soundRecordPath?.appendingPathComponent("VOICE \(Date().toString(dateFormat: "dd-MM-YY HH:mm:ss")).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        if let soundRecordFileName {
            do {
                audioRecorder = try AVAudioRecorder(url: soundRecordFileName, settings: settings)
                audioRecorder?.prepareToRecord()
                audioRecorder?.record()
            } catch {
                Logger.record.error("녹음 시작에 실패했습니다")
            }
        }
    }
    
    func stopRecording() {
        if self.audioRecorder?.isRecording ?? false {
            self.audioRecorder?.stop()
        }
    }
    
    // MARK: - 프로퍼티 관리
    
    func resetInStringProperties() {
        voiceSentencePartitionArray = []
        info = nil
        infoCategory = .unknown
        payAmount = -1
        paymentMethod = .unknown
    }
    
    // MARK: - 햅틱

    /// 금액이 잡혔다는 것을 손끝으로 알린다.
    ///
    /// 예전에는 부를 때마다 100ms 씩 늦춰 내보냈다. 여러 번이 겹칠 때 서로
    /// 뭉치지 않게 하려던 것으로 보이는데, 세는 값이 되돌아가는 곳이 없어
    /// 늘기만 했다 — 열 번째는 0.9초, 백 번째는 9.9초 뒤에 울린다. 앱을
    /// 오래 켜 둘수록 손끝의 반응이 뒤로 밀리다 사라진다.
    ///
    /// 부르는 곳은 payAmount 를 0.5초 묶어 두는 sink 하나뿐이라 겹쳐 올
    /// 일이 없다. 늦출 이유가 없어 바로 울린다.
    private func generateHapticFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
