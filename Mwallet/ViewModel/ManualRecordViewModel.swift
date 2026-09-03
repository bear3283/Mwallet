//
//  ManualRecordViewModel.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/21/23.
//

import AVFoundation
import Combine
import CoreLocation
import OSLog

// 화면이 직접 들고 있는 상태다. @Published 갱신은 메인에서만 일어나야 하므로
// 클래스 전체를 메인 액터에 묶는다.
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
final class ManualRecordViewModel: NSObject, ObservableObject {
    
    let viewContext = PersistenceController.shared.container.viewContext
    let exchangeHandler = ExchangeRateHandler.shared
    
    // MARK: - 위치 정보
    
    var location: CLLocation?
    
    func getLocation(completion: @escaping @MainActor @Sendable () -> Void) {
        location = DateGapHandler.shared.currentLocation
        if location == nil {
            let latitude = UserDefaults.standard.object(forKey: "currentLocationLatitude") as? CLLocationDegrees
            let longitude = UserDefaults.standard.object(forKey: "currentLocationLongitude") as? CLLocationDegrees
            if let latitude, let longitude {
                location = CLLocation(latitude: latitude, longitude: longitude)
            }
        }

        // 좌표가 없으면(권한 거부·첫 실행·실내) 국가를 정할 수 없다.
        // 예전에는 여기서 completion 을 부르지 않고 끝나 통화 후보가 초기값에 묶였고,
        // 그 초기값이 달러라 한국에서도 달러로만 기록할 수 있었다.
        guard let location else {
            completion()
            return
        }

        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _  in
            // @Published 를 건드리므로 메인에서 처리한다.
            DispatchQueue.main.async {
                if let newPlacemark = placemarks?.first {
                    let code = newPlacemark.isoCountryCode ?? ""
                    let countryKey = CountryInfoModel.shared.countryResult.first { _, info in
                        let pairCode = info.locationNm.components(separatedBy: "-")
                        return pairCode.count == 2 && pairCode[1] == code
                    }?.key ?? -1
                    self.currentCountry = countryKey
                    self.currentLocation = "\(newPlacemark.locality ?? "")"
                }
                completion()
            }
        }
    }

    // MARK: - 화폐

    // 통화 인덱스는 CurrencyList.csv 의 행 번호다. 숫자를 코드에 박아 두면
    // CSV 순서가 바뀔 때 조용히 다른 통화가 선택되므로 ISO 코드로 찾는다.
    static let krwIndex = Int(ExpenseCode.currencyIndex(for: "KRW"))
    static let usdIndex = Int(ExpenseCode.currencyIndex(for: "USD"))

    // 그 나라의 주요 통화를 앞에, 어디서나 통하는 원화·달러를 뒤에 붙인다.
    // 국가를 모르면(-1) 원화가 첫 후보가 된다.
    private func currencyCandidates(for country: Int) -> [Int] {
        let codes = CountryInfoModel.shared.countryResult[country]?.relatedCurrencyArray ?? []
        var candidates: [Int] = []

        for code in codes {
            let index = Int(ExpenseCode.currencyIndex(for: code))
            // currencyIndex 는 못 찾으면 원화로 떨어진다. 코드가 실제로 일치할 때만
            // 후보로 받아 "[Unknown]" 같은 값이 원화를 앞세우지 않게 한다.
            guard CurrencyInfoModel.shared.currencyResult[index]?.isoCodeNm.uppercased() == code.uppercased(),
                  !candidates.contains(index) else { continue }
            candidates.append(index)
        }

        for fallback in [Self.krwIndex, Self.usdIndex] where !candidates.contains(fallback) {
            candidates.append(fallback)
        }
        return candidates
    }

    // 위치 조회가 끝난 뒤 View 가 부른다.
    // 국가를 알아냈다면 country 의 didSet 이 이미 후보를 맞춰 두었으므로,
    // 여기서는 현재 선택이 후보에 없을 때만 바로잡는다.
    func setInitialCurrency() {
        applyCurrencyCandidates(for: country, resetSelection: false)
    }

    private func applyCurrencyCandidates(for country: Int, resetSelection: Bool) {
        let candidates = currencyCandidates(for: country)
        currencyCandidateArray = candidates

        if resetSelection || !candidates.contains(currency) {
            currency = candidates.first ?? Self.krwIndex
        }
    }
    
    // MARK: - combine
    
    var travelPublisher: AnyPublisher<Travel?, Never> {
        MainViewModel.shared.$chosenTravelInManualRecord
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    var travelStream: AnyCancellable?
    
    // MARK: - in-string property
    
    var payAmount: Double = -1 { // passive
        didSet {
            if payAmount == -1 || currency == -1 {
                payAmountInWon = -1
            } else {
                if let exchangeRate = exchangeHandler.getExchangeRateFromKRW(currencyCode: CurrencyInfoModel.shared.currencyResult[currency]?.isoCodeNm ?? "") {
                    payAmountInWon = payAmount * exchangeRate
                } else {
                    payAmountInWon = -1
                }
            }
        }
    }
    @Published var visiblePayAmount: String = "" {
        didSet {
            guard visiblePayAmount != "" else {
                payAmount = -1
                return
            }
            
            var tempVisiblePayAmount = visiblePayAmount.filter { [.arabicNumeric, .arabicDot].contains($0.getCharacterForm()) }
            if let dotIndex = tempVisiblePayAmount.firstIndex(of: ".") {
                if let twoMovesIndex = tempVisiblePayAmount.index(dotIndex, offsetBy: 3, limitedBy: tempVisiblePayAmount.endIndex) {
                    tempVisiblePayAmount = String(tempVisiblePayAmount[..<twoMovesIndex])
                }
                
            }

            var tempPayAmount = Double(tempVisiblePayAmount) ?? -1 // 음수 걸러내기
            if tempPayAmount < 0 {
                visiblePayAmount = "" // didSet is called again
                return
            } else if tempPayAmount > 1_000_000_000.99 { // 10억.99 초과 걸러내기; 소숫점 이하 2자리 정보 보존
                tempPayAmount = 1_000_000_000.0 + (tempPayAmount - floor(tempPayAmount))
                if abs(tempPayAmount - floor(tempPayAmount)) < 0.0000001 {
                    visiblePayAmount = String(format: "%.0f", tempPayAmount) // didSet is called again
                } else {
                    visiblePayAmount = String(tempPayAmount) // didSet is called again
                }
                return
            }
            
            if visiblePayAmount != tempVisiblePayAmount {
                visiblePayAmount = tempVisiblePayAmount
            }
            payAmount = tempPayAmount
        }
    }
    @Published var payAmountInWon: Double = -1 // passive

    var info: String? // passive
    @Published var visibleInfo: String = "" {
        didSet {
            guard visibleInfo != "" else {
                info = nil
                return
            }
            
            var weightedLength: Double = 0
            var tempVisibleInfo: String = ""
            
            for letter in visibleInfo {
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
            if visibleInfo != tempVisibleInfo {
                visibleInfo = tempVisibleInfo.reduce("") { $0 + String($1)} // didSet is called again
                return
            }
            
            info = visibleInfo
        }
    }
    
    @Published var category: ExpenseInfoCategory = .unknown
    @Published var paymentMethod: PaymentMethod = .unknown
    
    // MARK: - not-in-string property
    
    @Published var travelArray: [Travel] = []
    
    // 이름은 저장되는 값이라 여기에는 저장용을 담는다. 화면에 그릴 때만
    // Travel.participantDisplayName 을 거친다.
    @Published var participantTupleArray: [(name: String, isOn: Bool)] = [(Travel.selfParticipantName, true)] // passive
    
    @Published var payDate: Date = Date()
    var currentDate: Date = Date()

    @Published var country: Int = -1 {
        didSet {
            countryExpression = CountryInfoModel.shared.countryResult[country]?.displayName
                ?? CountryInfoModel.shared.countryResult[-1]?.displayName
                ?? String(localized: "알 수 없음")

            // 국가가 바뀌면 그 나라 통화로 맞춘다.
            // 미국을 따로 분기하던 코드가 있었는데, CountryList.csv 의 미국 행이
            // [USD] 라 일반 경로와 결과가 같아 지웠다.
            applyCurrencyCandidates(for: country, resetSelection: true)
        }
    }
    @Published var countryExpression: String = "" // passive
    @Published var locationExpression: String = ""

    var currentCountry: Int = -1 {
        didSet {
            if !otherCountryCandidateArray.contains(currentCountry) {
                otherCountryCandidateArray.append(currentCountry)
            }

            // 역지오코딩 응답은 네트워크 왕복이라 몇 초 뒤에 온다.
            // 그 사이 사용자가 국가를 직접 골랐다면 그 선택을 덮어쓰지 않는다.
            guard !countryIsModified else { return }
            country = currentCountry
        }
    }
    var currentLocation: String = "" {
        didSet {
            locationExpression = currentLocation
        }
    }
    var otherCountryCandidateArray: [Int] = [] // passive
    
    // 기본값은 원화. 위치를 못 잡아도 한국 사용자가 곧바로 기록할 수 있어야 한다.
    @Published var currency: Int = ManualRecordViewModel.krwIndex {
        didSet {
            if payAmount == -1 || currency == -1 {
                payAmountInWon = -1
            } else {
                if let exchangeRate = exchangeHandler.getExchangeRateFromKRW(currencyCode: CurrencyInfoModel.shared.currencyResult[currency]?.isoCodeNm ?? "") {
                    payAmountInWon = payAmount * exchangeRate
                } else {
                    payAmountInWon = -1
                }
            }
        }
    }
    // 화폐 Picker 가 이 배열을 순회한다. 비어 있거나 한 개뿐이면 사용자가
    // 통화를 바꿀 수 없으므로, 위치를 못 잡았을 때도 최소 원화·달러는 남겨 둔다.
    var currencyCandidateArray: [Int] = [ManualRecordViewModel.krwIndex, ManualRecordViewModel.usdIndex]
    
    var soundRecordFileName: URL?
    
    // MARK: - view state
    
    @Published var wantToActivateAutoSaveTimer = false
    @Published var travelChoiceModalIsShown = false
    @Published var categoryChoiceModalIsShown = false
    @Published var countryChoiceModalIsShown = false
    @Published var dateChoiceModalIsShown = false
    @Published var backButtonAlertIsShown = false
    @Published var addingParticipant = false
    @Published var countryIsModified = false {
        didSet {
            if countryIsModified {
                locationExpression = ""
            }
        }
    }
    @Published var playingRecordSound = false
    @Published var savingIsDone = false
    
    // MARK: - timer
    
    var autoSaveTimer: Timer?
    @Published var afterSavingTimer: Timer?
    @Published var secondCounter: Int?
    
    override init() {
        super.init()
        
        // MainViewModel의 chosenTravelInManualRecord가 변화할 때 자동으로 이루어질 일을 sink로 처리
        travelStream = travelPublisher.sink { chosenTravel in
            if let chosenTravel {
                // 참가자가 없으면 빈 배열이라 '나' 만 남는다. 갈래를 나눌 것이 없다.
                self.participantTupleArray = [(Travel.selfParticipantName, true)] + chosenTravel.participants.map { ($0, true) }
                var expenseArray: [Expense] = []
                if let expenseArrayOfChosenTravel = chosenTravel.expenseArray {
                    expenseArray = expenseArrayOfChosenTravel.allObjects as? [Expense] ?? []
                }
                self.otherCountryCandidateArray = Array(Set(expenseArray.map { Int($0.country) })).sorted()
            } else {
                self.participantTupleArray = [(Travel.selfParticipantName, true)]
                self.otherCountryCandidateArray = []
            }
        }
    }
    
    deinit {
        // 메인 액터 메서드를 부를 수 없으므로 플레이어를 직접 멈춘다.
        audioPlayer?.stop()
    }
        
    func save() {
        
        let expense = Expense(context: viewContext)
        expense.category = Int64(category.rawValue)
        expense.country = Int64(country)
        expense.currency = Int64(currency)
        let code = CurrencyInfoModel.shared.currencyResult[currency]?.isoCodeNm ?? "Unknown"
        expense.exchangeRate = exchangeHandler.getExchangeRateFromKRW(currencyCode: code) ?? Expense.unknownExchangeRate
        expense.info = info
        expense.location = locationExpression
        expense.participants = participantTupleArray.filter { $0.1 == true }.map { $0.0 }
        expense.payAmount = payAmount
        expense.payDate = payDate
        expense.paymentMethod = Int64(paymentMethod.rawValue)
        
        if let soundRecordFileName, let soundData = try? Data(contentsOf: soundRecordFileName) {
            expense.voiceRecordFile = soundData
        }
        
        if let chosenTravel = MainViewModel.shared.chosenTravelInManualRecord {
            var fetchedTravel: Travel?
            do {
                fetchedTravel = try viewContext.fetch(Travel.fetchRequest()).filter { travel in
                        return travel.id == chosenTravel.id
                }.first
            } catch {
                Logger.data.error("여행 목록 조회 실패: \(error.localizedDescription, privacy: .public)")
            }
            fetchedTravel?.lastUpdate = Date()
            fetchedTravel?.addToExpenseArray(expense)
        }
        do {
            try viewContext.save()
        } catch {
            Logger.data.error("지출 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - voice
    
    // 재생은 메인에서만 다루지만 deinit 은 어느 스레드에서 불릴지 모른다.
    // 해제 시점에 재생을 멈추려면 격리 밖에서도 닿아야 해 nonisolated 로 둔다.
    private nonisolated(unsafe) var audioPlayer: AVAudioPlayer?
    
    func startPlayingAudio(url: URL) {
        
        let playSession = AVAudioSession.sharedInstance()
        
        do {
            try playSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        } catch {
            Logger.record.error("스피커 출력 전환에 실패했습니다")
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self // 
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
        } catch {
            Logger.record.error("녹음 재생에 실패했습니다")
        }
    }
    
    func stopPlayingAudio() {
        audioPlayer?.stop()
    }
    
    func deleteUselessAudioFiles() {
        let soundRecordPath: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
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
    }
}

extension ManualRecordViewModel: AVAudioPlayerDelegate {

    // AVAudioPlayerDelegate 는 메인 액터에 묶여 있지 않다. 이 콜백이 어느 스레드로
    // 올지 보장이 없으므로 nonisolated 로 받고, 상태 변경만 메인으로 넘긴다.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else {
            Logger.record.error("녹음 재생이 끝나지 못했습니다")
            return
        }
        Task { @MainActor in
            self.playingRecordSound = false
        }
    }
}
