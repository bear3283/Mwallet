//
//  RecordView.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/12/23.
//

import CoreLocation
import OSLog
import SwiftUI

struct RecordView: View {

    let recordButtonAnimationLength = 0.25

    @StateObject var viewModel = RecordViewModel()
    @EnvironmentObject var mainVM: MainViewModel

    /// 여행 선택 시트에 건네줄 목록. 예결산·내역과 같은 규칙으로 뽑는다.
    @State private var travelChoices: [Travel] = []
    private let travelStore = TravelStore()
    private let receiptStore = ReceiptStore()
    private let budgetStore = BudgetStore()

    /// 새로 적는 폼에 건넬 초안. 값이 들어오면 폼이 뜬다.
    @State private var formDraft: RecordFormDraft?
    /// 방금 저장한 지출. 문장 자리에 결과를 보여 주고 되돌릴 수 있게 한다.
    @State private var savedExpense: Expense?
    @State private var editingExpense: Expense?
    @State private var savedCardTimer: Task<Void, Never>?

    @GestureState private var isDetectingPress = false
    @State private var isDetectingPress_showOnButton = false {
        didSet {
            if isDetectingPress_showOnButton {
                withAnimation(.linear(duration: 0.01).delay(0.01)) {
                    isDetectingPress_letButtonBigger = true
                }
            }
        }
    }
    @State private var isDetectingPress_letButtonBigger = false {
        didSet {
            if !isDetectingPress_letButtonBigger {
                withAnimation(.linear(duration: 0.01).delay(recordButtonAnimationLength)) {
                    isDetectingPress_showOnButton = false
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            screen(RecordLayout.forCurrentScreen)
            .ignoresSafeArea()
            .onAppear {
                travelChoices = travelStore.availableTravels()
                mainVM.dropSelectionIfDeleted()
                viewModel.resetInStringProperties()
                viewModel.recordButtonResetTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    // 메인 런루프에 걸린 타이머라 항상 메인에서 깨어난다.
                    MainActor.assumeIsolated {
                        guard !isDetectingPress else { return }
                        viewModel.stopSTT()
                    }
                }
                openManualEntryIfAsked()
            }
            .onDisappear {
                viewModel.recordButtonResetTimer?.invalidate()
            }
            // 큰 위젯의 ＋ 칸이 mwallet://record/manual 로 들어온다.
            // 신호를 보면 폼을 열고, 열면서 도로 내린다 — 내리지 않으면
            // 폼을 닫고 돌아왔을 때 곧바로 다시 열린다.
            .onChange(of: mainVM.opensManualEntry) { _, _ in
                openManualEntryIfAsked()
            }
            .sheet(item: $formDraft) { box in
                ExpenseFormView(mode: .create(box.draft)) { expense in
                    showSaved(expense)
                }
            }
            .sheet(item: $editingExpense) { expense in
                ExpenseFormView(mode: .edit(expense))
            }
        }
    }

}

// 화면의 짜임. 상태와 body 는 위에 두고 조각들은 여기 모은다.
extension RecordView {

    // MARK: - 화면 짜임
    //
    // SE 계열(4.7인치)은 세로가 짧아 넉넉한 여백으로는 아래가 잘린다.
    // 예전에는 화면 전체를 두 벌 적어 두고 갈랐는데, 54줄 중 46줄이 같았고
    // 다른 것은 여백 네 값뿐이었다. 한쪽만 고치면 작은 화면에서만 어긋나는
    // 일이 생기므로, 짜임은 한 벌로 두고 값만 갈아 끼운다.

    private func screen(_ metrics: RecordLayout) -> some View {
        ZStack {
            Color(.white)
            RecordTravelCover(travel: mainVM.selectedTravel)
            mainColumn(metrics)
            alertLayer(metrics)
            recordButtonLayer(metrics)
        }
    }

    // 말한 결과가 채워지는 곳(RecordLiveFields)이 이 화면의 주인공이라
    // 그 블록을 화면 세로 한가운데에 둔다. 위·아래 묶음이 남은 공간을
    // 똑같이 나눠 가지므로, 위쪽 항목 수가 늘어도 가운데가 밀리지 않는다.
    private func mainColumn(_ metrics: RecordLayout) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: metrics.topInset)
                // 예결산·내역과 같은 컨트롤을 쓴다. 세 탭이 같은 것을 묻는
                // 자리라 생김새도 하나여야 한다. 고르지 않으면 미분류로 적힌다.
                TravelPicker(travels: travelChoices,
                             selection: $mainVM.selectedTravel,
                             emptyTitle: String(localized: "여행 선택"),
                             emptyDescription: String(localized: "눌러서 여행을 고르세요"),
                             allowsAll: true,
                             allTitle: String(localized: "미분류"),
                             alignment: .center)
                    .accessibilityIdentifier("record.travelChoice")
                todayLine
                Spacer()
                    .frame(height: 36)
                sentenceOrSavedCard
                Spacer()
                    .frame(height: 36)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)

            RecordLiveFields(viewModel: viewModel)

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: metrics.manualTopGap)
                manualRecordButtonView
                Spacer(minLength: metrics.manualBottomInset)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// 오늘 쓴 돈과 남은 예산 한 줄.
    ///
    /// 적으러 들어온 화면에서 가장 자주 궁금한 숫자다. 여기 없으면 한 건
    /// 적을 때마다 예결산 탭을 다녀와야 한다. 여행을 고르지 않았으면
    /// 견줄 예산이 없어 내지 않는다.
    @ViewBuilder
    private var todayLine: some View {
        if let travel = mainVM.selectedTravel, !travel.isDeleted {
            let budget = budgetStore.summary(for: travel)
            let today = budgetStore.expenses(for: travel)
                .filter { Calendar.current.isDateInToday($0.paidDate) }
                .compactMap(\.amountInKRW)
                .reduce(0, +)

            HStack(spacing: 6) {
                Text("오늘 \(ReceiptFormat.krw(today))")
                if budget.hasBudget {
                    Text("·")
                        .accessibilityHidden(true)
                    Text(BudgetFormat.remaining(budget.remaining))
                        .foregroundStyle(budget.isOverspent ? Color.mainOrange : Color.gray400)
                }
            }
            .font(.caption2)
            .foregroundStyle(.gray400)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.top, 10)
            // 방금 저장한 것이 바로 반영되도록, 저장할 때마다 다시 그린다.
            .id(savedExpense?.objectID)
        }
    }

    /// 문장 자리. 방금 저장한 것이 있으면 그 결과를 같은 자리에 보여 준다.
    ///
    /// 문장 영역을 지우지 않고 가리기만 하는 것은 높이를 지키기 위해서다.
    /// 자리가 바뀌면 그 아래 세 칸이 들썩인다.
    private var sentenceOrSavedCard: some View {
        ZStack {
            RecordSentenceArea(viewModel: viewModel, isPressing: isDetectingPress)
                .opacity(showsSavedCard ? 0.0000001 : 1)
                .accessibilityHidden(showsSavedCard)

            if showsSavedCard, let savedExpense {
                RecordSavedCard(expense: savedExpense,
                                onUndo: { undo(savedExpense) },
                                onEdit: {
                                    hideSavedCard()
                                    editingExpense = savedExpense
                                })
                    .transition(.opacity)
            }
        }
    }

    private var showsSavedCard: Bool {
        guard let savedExpense, !isDetectingPress else { return false }
        return !savedExpense.isDeleted && savedExpense.managedObjectContext != nil
    }

    // 알림이 떠 있는 동안에는 이 층이 화면 전체의 탭을 받아 알림을 닫는다.
    private func alertLayer(_ metrics: RecordLayout) -> some View {
        ZStack {
            Color(.white)
                .opacity(0.0000001)

            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .bottom) {
                    speakWhilePressingView
                    RecordAlertBubble(message: String(localized: "소비내역이나 금액 중 한 가지는\n반드시 기록해야 저장할 수 있어요"),
                                      isShown: viewModel.alertView_emptyIsShown)
                    RecordAlertBubble(message: String(localized: "길게 누른 채로 말해주세요"),
                                      isShown: viewModel.alertView_shortIsShown)
                }
                Spacer()
                    .frame(height: 16)
                // 녹음 버튼과 같은 자리를 차지해 위 묶음의 높이를 잡아 준다.
                recordButtonView
                    .hidden()
                Spacer()
                    .frame(height: metrics.tabBarInset)
            }
        }
        .allowsHitTesting(viewModel.alertView_emptyIsShown || viewModel.alertView_shortIsShown)
        .onTapGesture {
            viewModel.alertView_emptyIsShown = false
            viewModel.alertView_shortIsShown = false
        }
    }

    private func recordButtonLayer(_ metrics: RecordLayout) -> some View {
        VStack(spacing: 0) {
            Spacer()
            recordButtonView
            Spacer()
                .frame(height: metrics.tabBarInset)
        }
    }

    private var manualRecordButtonView: some View {
        ManualRecordLink(isHidden: isDetectingPress) {
            openForm(with: newDraft())
        }
        .disabled(isDetectingPress)
    }

    private var recordButtonView: some View {
        ZStack {
            Image("recordButtonOff")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                .accessibilityHidden(true)
            Image("recordButtonOn")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .shadow(color: Color(0xfa395c, alpha: 0.7), radius: isDetectingPress_letButtonBigger ? 8 : 0)
                .scaleEffect(isDetectingPress_letButtonBigger ? 1 : (28.0 / 84.0))
                .animation(.easeInOut(duration: recordButtonAnimationLength), value: isDetectingPress_letButtonBigger)
                .opacity(isDetectingPress_showOnButton ? 1 : 0.0000001)
                // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                .accessibilityHidden(true)
        }
        .gesture(continuousPress)
        // 이 앱의 핵심 동작인데 VoiceOver 에는 아무것도 없는 자리였다.
        // 그림 셋을 장식으로 숨기고 나면 남는 것이 없으므로 요소를 직접 세운다.
        // (누른 채로 있는 동작 자체는 실기기에서 확인해야 한다)
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("녹음")
        .accessibilityHint("두 번 누른 채로 있으면 말한 내용을 받아 적습니다")
        .onChange(of: isDetectingPress) { oldValue, newValue in
            // 손을 뗐을 때만 본다. 누르기 시작한 쪽은 제스처가 맡는다.
            guard oldValue && !newValue else { return }

            viewModel.endRecordTime = CFAbsoluteTimeGetCurrent()
            isDetectingPress_letButtonBigger = false
            viewModel.stopSTT()

            // 예전에는 여기서 0.4초를 셌다. 인식 결과가 비동기로 오는데
            // 손을 뗀 그 순간에 읽으면 마지막 한 마디가 아직 도착하지
            // 않아, 말을 했는데도 '아무것도 못 알아들었다' 가 됐다.
            //
            // 시간을 세는 대신 인식이 끝났다는 신호를 기다린다.
            // 짧게 말하면 짧게, 길게 말하면 그만큼 기다린다.
            Task { @MainActor in
                await viewModel.awaitFinalTranscription()

                let pressed = Double(viewModel.endRecordTime - viewModel.startRecordTime)
                switch RecordOutcome.decide(pressedSeconds: pressed,
                                            info: viewModel.info,
                                            payAmount: viewModel.payAmount) {
                case .tooShort:
                    viewModel.alertView_shortIsShown = true
                    viewModel.resetInStringProperties()
                case .nothingHeard:
                    viewModel.resetTranscribedString()
                    viewModel.alertView_emptyIsShown = true
                    viewModel.resetInStringProperties()
                case .proceed:
                    finishVoiceRecord()
                }
            }
        }
    }

    private var continuousPress: some Gesture {
        LongPressGesture(minimumDuration: 0.01, maximumDistance: 40)
            .sequenced(before: LongPressGesture(minimumDuration: .infinity, maximumDistance: 40))
            .updating($isDetectingPress) { value, state, _ in
                switch value {
                case .second(true, nil):
                    // 녹음 시작 (Publishing changes from within view updates 오류 발생 가능)
                    state = true

                    viewModel.startRecordTime = CFAbsoluteTimeGetCurrent()
                    DispatchQueue.main.async {
                        // 지출에는 결제 위치가 함께 남는다. 녹음을 시작한 이
                        // 시점이 위치 권한을 청할 맥락이다. (이미 준비됐으면 무시된다)
                        DateGapHandler.shared.requestAuthorization()
                        do {
                            try viewModel.startSTT()
                        } catch {
                            Logger.record.error("녹음 시작 실패: \(error.localizedDescription, privacy: .public)")
                        }

                        isDetectingPress_showOnButton = true
                        viewModel.alertView_emptyIsShown = false
                        viewModel.alertView_shortIsShown = false
                        hideSavedCard()
                    }

                default:
                    break
                }
            }
    }

    private var speakWhilePressingView: some View {
        Text("누르는 동안 말하기")
            .font(.subhead3_2)
            .foregroundStyle(.gray300)
            .multilineTextAlignment(.center)
            .opacity(!isDetectingPress && !viewModel.alertView_emptyIsShown && !viewModel.alertView_shortIsShown ? 1 : 0.0000001)
            .allowsHitTesting(false)
    }

}

// 저장과 그 뒤의 일. 화면의 짜임과 갈라 둔다.
extension RecordView {

    // MARK: - 저장

    /// 지금 고른 여행에 맞춘 빈 초안.
    private func newDraft() -> ReceiptDraft {
        receiptStore.newDraft(for: mainVM.selectedTravel,
                              coordinate: DateGapHandler.shared.lastKnownCoordinate)
    }

    private func openForm(with draft: ReceiptDraft) {
        hideSavedCard()
        formDraft = RecordFormDraft(draft: draft)
    }

    private func openManualEntryIfAsked() {
        guard mainVM.opensManualEntry else { return }
        mainVM.opensManualEntry = false
        openForm(with: newDraft())
    }

    /// 말로 들은 것을 지출로 적는다.
    ///
    /// 묻지 않고 바로 저장한다. 예전에는 확인 화면을 띄우고 8초를 센 뒤
    /// 저장했는데, 세는 것이 마지막 3초에만 보여 언제 저장되는지 알 수
    /// 없었다. 저장하고 나서 되돌리거나 고칠 수 있게 하는 편이 빠르고 분명하다.
    ///
    /// 다만 짐작해야 하는 것이 있으면 폼을 열어 묻는다 — 금액을 못 들었거나,
    /// 그 여행에 적은 것이 아직 없어 통화를 모를 때다. 위젯과 같은 규칙이다.
    private func finishVoiceRecord() {
        var draft = newDraft()
        draft.merchant = viewModel.info ?? ""
        if viewModel.payAmount > 0 {
            draft.amountText = ReceiptDraft.editableAmountText(viewModel.payAmount)
        }
        draft.category = viewModel.infoCategory.description
        draft.paymentMethod = viewModel.paymentMethod
        viewModel.resetInStringProperties()

        guard draft.isValid, receiptStore.inheritedMoney(for: draft.travel) != nil else {
            openForm(with: draft)
            return
        }

        do {
            let expense = try receiptStore.create(from: draft)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSaved(expense)
            fillPlace(of: expense, at: draft.coordinate)
        } catch {
            Logger.data.error("지출 저장 실패: \(error.localizedDescription, privacy: .public)")
            openForm(with: draft)
        }
    }

    /// 주소 찾기는 몇 초 걸리는 왕복이라 저장한 뒤에 채운다.
    private func fillPlace(of expense: Expense, at coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else { return }
        Task { @MainActor in
            guard let place = await ExpensePlace.resolve(coordinate) else { return }
            receiptStore.fillPlace(place, for: expense)
        }
    }

    private func showSaved(_ expense: Expense) {
        withAnimation(.easeInOut(duration: 0.2)) { savedExpense = expense }
        savedCardTimer?.cancel()
        savedCardTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { savedExpense = nil }
        }
    }

    private func hideSavedCard() {
        savedCardTimer?.cancel()
        savedExpense = nil
    }

    private func undo(_ expense: Expense) {
        hideSavedCard()
        do {
            try receiptStore.delete(expense)
        } catch {
            Logger.data.error("되돌리기 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// 폼을 띄울 때 건네는 초안. 시트가 값으로 뜨려면 이름표(id)가 있어야 한다.
struct RecordFormDraft: Identifiable {
    let id = UUID()
    let draft: ReceiptDraft
}

// MARK: - 방금 저장한 것

/// 저장한 직후 문장 자리에 뜨는 결과. 되돌리거나 고칠 수 있다.
struct RecordSavedCard: View {

    let expense: Expense
    var onUndo: () -> Void
    var onEdit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.mainAccent)
                    .accessibilityHidden(true)
                Text("저장되었습니다")
                    .font(.subhead2_2)
                    .foregroundStyle(.gray400)
            }

            VStack(spacing: 4) {
                Text(expense.formattedAmount)
                    .font(.title4)
                    .foregroundStyle(.black)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(expense.merchantName) · \(expense.missionTitle)")
                    .font(.caption2)
                    .foregroundStyle(.gray400)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button(action: onUndo) {
                    Text("되돌리기")
                        .font(.subhead2_2)
                        .foregroundStyle(.gray400)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Color.gray100, in: Capsule())
                }
                Button(action: onEdit) {
                    Text("편집")
                        .font(.subhead2_2)
                        .foregroundStyle(Color.mainAccent)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Color.mainAccent.opacity(0.12), in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
    }
}

struct ThreeDotsView: View {
    
    @State var timer: Timer?
    @State var level = 0
    @State var flicker = true
    
    let stepLength = 0.5
    
    func levelUp() {
        level = (level + 1) % 3
    }
    
    var body: some View {
        Group {
            ZStack {
                Color(.red)
                    .opacity(0.0000001)
                    .onAppear {
                        timer = Timer.scheduledTimer(withTimeInterval: stepLength, repeats: true) { _ in
                            MainActor.assumeIsolated { levelUp() }
                        }
                    }
                    .onDisappear {
                        timer?.invalidate()
                    }
                
                HStack(spacing: 10) {
                    Circle()
                        .foregroundStyle(.gray200)
                        .frame(width: 8, height: 8)
                        .offset(y: level == 0 ? -9 : 0)
                    Circle()
                        .foregroundStyle(.gray200)
                        .frame(width: 8, height: 8)
                        .offset(y: level == 1 ? -9 : 0)
                    Circle()
                        .foregroundStyle(.gray200)
                        .frame(width: 8, height: 8)
                        .offset(y: level == 2 ? -9 : 0)
                }
                .animation(.bouncy(duration: stepLength * 1.25), value: level)
            }
            .frame(width: 44, height: 17)
        }
    }
}

#Preview {
    RecordView()
}

// MARK: - 직접 기록으로 가는 길

/// '직접 기록' 버튼. 말로 적기 어려울 때 손으로 넣는 화면으로 간다.
///
/// 녹음하는 동안에는 자리만 지키고 사라진다. 완전히 지우지 않는 것은
/// 위 묶음의 높이가 흔들려 화면이 들썩이기 때문이다.
struct ManualRecordLink: View {

    let isHidden: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image("recordGrayPencil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                    .accessibilityHidden(true)
                Text("직접 기록")
                    .foregroundStyle(.gray300)
                    .font(.caption2)
                    .underline()
            }
            .padding(.vertical, 9.5)
            .padding(.horizontal, 16)
        }
        .opacity(isHidden ? 0.0000001 : 1)
    }
}
