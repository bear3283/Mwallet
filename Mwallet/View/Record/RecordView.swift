//
//  RecordView.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/12/23.
//

import OSLog
import SwiftUI

struct RecordView: View {
    
    init() {
    }
    
    let recordButtonAnimationLength = 0.25
    
    @StateObject var viewModel = RecordViewModel()
    @EnvironmentObject var mainVM: MainViewModel
    
    /// 여행 선택 시트에 건네줄 목록. 예결산·영수증과 같은 규칙으로 뽑는다.
    @State private var travelChoices: [Travel] = []
    private let travelStore = TravelStore()

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
                viewModel.resetInStringProperties()
                viewModel.wantToActivateAutoSaveTimer = true
                viewModel.recordButtonResetTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    // 메인 런루프에 걸린 타이머라 항상 메인에서 깨어난다.
                    MainActor.assumeIsolated {
                        guard !isDetectingPress else { return }
                        viewModel.stopSTT()
                        viewModel.stopRecording()
                    }
                }
                
                // MARK: - decide record button action
                
                // 기본함밖에 없으면 녹음 버튼이 여행 추가를 먼저 권한다.
                let sampleTravel = findInitialTravelInExpense()
                viewModel.AreThereOtherTravels = sampleTravel?.isUserCreated ?? false
            }
            .onDisappear {
                viewModel.recordButtonResetTimer?.invalidate()
            }
            .sheet(isPresented: $viewModel.addTravelRequestModalIsShown) {
                AddTravelRequestModal(viewModel: viewModel)
                    .presentationDetents([.height(247 - 34)])
            }
            .navigationDestination(isPresented: $viewModel.manualRecordViewIsShown) {
                ManualRecordView(
                    given_wantToActivateAutoSaveTimer: viewModel.wantToActivateAutoSaveTimer,
                    given_payAmount: viewModel.payAmount,
                    given_info: viewModel.info,
                    given_infoCategory: viewModel.infoCategory,
                    given_paymentMethod: viewModel.paymentMethod,
                    given_soundRecordFileName: viewModel.soundRecordFileName
                )
                .environmentObject(mainVM)
            }
        }
    }
    
    // MARK: - 화면 짜임
    //
    // SE 계열(4.7인치)은 세로가 짧아 넉넉한 여백으로는 아래가 잘린다.
    // 예전에는 화면 전체를 두 벌 적어 두고 갈랐는데, 54줄 중 46줄이 같았고
    // 다른 것은 여백 네 값뿐이었다. 한쪽만 고치면 작은 화면에서만 어긋나는
    // 일이 생기므로, 짜임은 한 벌로 두고 값만 갈아 끼운다.

    private func screen(_ metrics: RecordLayout) -> some View {
        ZStack {
            Color(.white)
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
                // 예결산·영수증과 같은 컨트롤을 쓴다. 세 탭이 같은 것을 묻는
                // 자리라 생김새도 하나여야 한다.
                TravelPicker(travels: travelChoices,
                             selection: $mainVM.selectedTravel,
                             emptyTitle: "여행 선택",
                             emptyDescription: "눌러서 여행을 고르세요",
                             alignment: .center)
                    .accessibilityIdentifier("record.travelChoice")
                Spacer()
                    .frame(height: 36)
                RecordSentenceArea(viewModel: viewModel, isPressing: isDetectingPress)
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

    // 알림이 떠 있는 동안에는 이 층이 화면 전체의 탭을 받아 알림을 닫는다.
    private func alertLayer(_ metrics: RecordLayout) -> some View {
        ZStack {
            Color(.white)
                .opacity(0.0000001)

            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .bottom) {
                    speakWhilePressingView
                    RecordAlertBubble(message: "소비내역이나 금액 중 한 가지는\n반드시 기록해야 저장할 수 있어요",
                                      isShown: viewModel.alertView_emptyIsShown)
                    RecordAlertBubble(message: "길게 누른 채로 말해주세요",
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
        ManualRecordLink(isHidden: isDetectingPress
                         && (viewModel.AreThereOtherTravels || viewModel.isExplicitTempRecord)) {
            viewModel.wantToActivateAutoSaveTimer = false
            viewModel.manualRecordViewIsShown = true
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
            if !oldValue && newValue {
                // 녹음 시작 (지점 1: 녹음 끝과 순서 뒤집히는 오류 발생 가능)
            } else if oldValue && !newValue {
                // 녹음 끝
                
                if viewModel.AreThereOtherTravels || viewModel.isExplicitTempRecord {
                    viewModel.endRecordTime = CFAbsoluteTimeGetCurrent()
                    isDetectingPress_letButtonBigger = false
                    viewModel.stopSTT()
                    viewModel.stopRecording()
                    // 0.4초를 기다리는 것은 아직 오는 중인 인식 결과 때문이다.
                    //
                    // 음성 인식은 결과를 비동기로 흘려 보내고, 받은 문장은
                    // voiceSentence 의 didSet 에서 다시 한 번 메인 큐로 미뤄져
                    // 내역·금액으로 나뉜다. 손을 뗀 그 순간에 읽으면 마지막
                    // 한 마디가 아직 도착하지 않아, 말을 했는데도 '아무것도
                    // 못 알아들었다' 로 잘못 판단한다.
                    //
                    // 제대로 고치려면 시간이 아니라 인식이 끝났다는 신호
                    // (result.isFinal)를 기다려야 한다. 지금은 stopSTT 가
                    // 작업을 취소해 그 신호가 오지 않으므로, endAudio 로
                    // 바꿔 마지막 결과를 받고 판단하는 구조가 되어야 한다.
                    //
                    // 그 길은 실기기 마이크가 있어야 확인할 수 있어 남겨 둔다.
                    // 눈감고 바꾸면 이 앱의 핵심인 '말해서 기록하기' 가
                    // 조용히 어긋난다.
                    if Double(viewModel.endRecordTime - viewModel.startRecordTime) < 1.5 {
                        DispatchQueue.main.async {
                            viewModel.alertView_shortIsShown = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            viewModel.resetInStringProperties()
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if viewModel.info == nil && viewModel.payAmount == -1 {
                                viewModel.resetTranscribedString()
                                viewModel.alertView_emptyIsShown = true
                                viewModel.resetInStringProperties()
                            } else {
                                viewModel.manualRecordViewIsShown = true
                            }
                        }
                    }
                } else {
                    _ = 0
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
                    // 녹음 시작 (지점 2: Publishing changes from within view updates 오류 발생 가능)
                    state = true
                    
                    if viewModel.AreThereOtherTravels || viewModel.isExplicitTempRecord {
                        viewModel.startRecordTime = CFAbsoluteTimeGetCurrent()
                        Task {
                            await viewModel.startRecording()
                        }
                        DispatchQueue.main.async {
                            do {
                                try viewModel.startSTT()
                            } catch {
                                Logger.record.error("녹음 시작 실패: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                        
                        DispatchQueue.main.async {
                            isDetectingPress_showOnButton = true
                            viewModel.alertView_emptyIsShown = false
                            viewModel.alertView_shortIsShown = false
                            viewModel.recordButtonIsFocused = true
                            viewModel.wantToActivateAutoSaveTimer = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            viewModel.addTravelRequestModalIsShown = true
                        }
                    }
                    
                default:
                    break
                }
            }
    }

//    private var alertView_saved: some View {
//        ZStack {
//            RoundedRectangle(cornerRadius: 18)
//                .foregroundStyle(.white)
//                .opacity(mainVM.alertView_savedIsShown ? 1 : 0.0000001)
//                .shadow(color: Color(0xCCCCCC), radius: 5)
//                .layoutPriority(-1)
//            
//            VStack(spacing: 8) {
//                Image("recordBigMainPinkCheck")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 24, height: 24)
//                Text("지출 기록이 저장되었습니다")
//                    .font(.subhead2_2)
//                    .foregroundStyle(.gray300)
//                    .multilineTextAlignment(.center)
//                    .padding(.horizontal, 41)
//            }
//            .padding(.top, 12)
//            .padding(.bottom, 16)
//            .opacity(mainVM.alertView_savedIsShown ? 1 : 0.0000001)
//        }
//        .padding(.horizontal, 30)
//    }
    
    private var speakWhilePressingView: some View {
        Text("누르는 동안 말하기")
            .font(.subhead3_2)
            .foregroundStyle(.gray300)
            .multilineTextAlignment(.center)
            .opacity(!isDetectingPress && !viewModel.alertView_emptyIsShown && !viewModel.alertView_shortIsShown ? 1 : 0.0000001)
            .allowsHitTesting(false)
    }

    // 무엇을·얼마·어떻게 순서로 말하면 된다는 걸 실제 예시로 보여 준다.
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
