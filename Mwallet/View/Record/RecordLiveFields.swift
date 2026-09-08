//
//  RecordLiveFields.swift
//  Mwallet
//
//  기록 화면에서 떼어 낸 두 조각.
//
//    말한 결과가 채워지는 곳 — 이 화면의 주인공
//    알림 방울 — 저장할 수 없을 때 뜨는 말
//

import SwiftUI

// MARK: - 말한 결과가 채워지는 곳

// 말이 들어오는 대로 결제 내역·금액·결제 방식이 하나씩 차오르고,
// 무엇이 아직 비었는지가 한눈에 보여야 한다.

struct RecordLiveFields: View {

    @ObservedObject var viewModel: RecordViewModel
    /// 사용자가 고른 글자 크기. 여백을 여기에 맞춘다.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 아직 안 채워진 자리에 흐리게 적을 예시.
    ///
    /// 위 예시 말풍선('점심 15000원 카드')이 가르치는 문장을 세 조각으로
    /// 나눠 각자의 자리에 놓은 것이다. 화면 하나가 한 문장을 가르치고, 그
    /// 문장의 어느 조각이 어디로 들어가는지를 자리로 보여 준다.
    ///
    /// 말풍선을 쪼개 쓰지 않고 따로 둔다. 언어마다 어순이 달라 쪼개는 규칙을
    /// 세울 수 없고, 금액도 그 나라에서 말이 되는 값이어야 한다 — 한국어는
    /// 15,000원이지만 영어 예시는 15달러다.
    static let infoHint = String(localized: "예: 점심",
                                 comment: "결제 내역 자리에 흐리게 적는 예시. 예시 말풍선의 내역 부분과 맞춘다")
    static let amountHint = String(localized: "예: 15,000",
                                   comment: "결제 금액 자리에 흐리게 적는 예시. 예시 말풍선의 금액과 맞춘다")

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(.gray100)
                        .layoutPriority(-1)
            
                    Text("결제 내역")
                        .foregroundStyle(.gray400)
                        .font(.subhead2_2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                }
                Spacer()
                    .frame(width: 12)
                if viewModel.info != nil {
                    Image("recordMainPinkCheck")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                        .accessibilityHidden(true)
                    Spacer()
                        .frame(width: 12)
                    Text(viewModel.info!)
                        .foregroundStyle(.black)
                        .font(.subhead3_2)
                        .lineLimit(3)
                } else {
                    Image("recordGray100Check")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                        .accessibilityHidden(true)
                    Spacer()
                        .frame(width: 12)
                    // 아직 안 채워진 자리. 예전에는 '-' 한 글자였는데, 그것만으로는
                    // 여기에 무엇이 들어오는지 알 수 없었다. 아래 결제 방식이
                    // '현금 / 카드' 로 고를 것을 미리 보여 주는 것과 같은 방식으로,
                    // 위 예시 말풍선이 가르치는 문장의 해당 조각을 흐리게 적는다.
                    Text(Self.infoHint)
                        .foregroundStyle(.gray200)
                        .font(.subhead3_2)
                        .lineLimit(1)
                }
                Spacer()
                    .frame(minWidth: 0)
                    .layoutPriority(-2)
            }
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(.gray100)
                        .layoutPriority(-1)
            
                    // 뷰 크기 설정하기 위한 히든 뷰
                    Text("결제 내역")
                        .foregroundStyle(.gray400)
                        .font(.subhead2_2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                        .hidden()
            
                    Text("결제 금액")
                        .foregroundStyle(.gray400)
                        .font(.subhead2_2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                }
                Spacer()
                    .frame(width: 12)
                if viewModel.payAmount != -1 {
                    Image("recordMainPinkCheck")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                        .accessibilityHidden(true)
                    Spacer()
                        .frame(width: 12)
                    Group {
                        if let formattedString = viewModel.payAmount.getStringFraction0To2() {
                            Text(formattedString)
                        } else {
                            Text(" ")
                        }
                    }
                    .foregroundStyle(.black)
                    .font(.subhead3_2)
                    .lineLimit(3)
                } else {
                    Image("recordGray100Check")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                        .accessibilityHidden(true)
                    Spacer()
                        .frame(width: 12)
                    Text(Self.amountHint)
                        .foregroundStyle(.gray200)
                        .font(.subhead3_2)
                        .lineLimit(1)
                }
                Spacer()
                    .frame(minWidth: 0)
                    .layoutPriority(-2)
            }
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(.gray100)
                        .layoutPriority(-1)
            
                    // 뷰 크기 설정하기 위한 히든 뷰
                    Text("결제 내역")
                        .foregroundStyle(.gray400)
                        .font(.subhead2_2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                        .hidden()
            
                    Text("결제 방식")
                        .foregroundStyle(.gray400)
                        .font(.subhead2_2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                }
                Spacer()
                    .frame(width: 12)
                switch viewModel.paymentMethod {
                case .card:
                    HStack(spacing: 0) {
                        Image("recordMainPinkCheck")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                            .accessibilityHidden(true)
                        Spacer()
                            .frame(width: 12)
                        Group {
                            Text("현금")
                                .foregroundStyle(.gray200)
                            Text(" / ")
                                .foregroundStyle(.gray200)
                            Text("카드")
                                .foregroundStyle(.black)
                        }
                        .font(.subhead3_2)
                        // 글자를 키우면 이 세 낱말이 한 글자씩 세로로 쪼개져
                        // 읽을 수 없었다. 제 너비를 지키게 한다.
                        .fixedSize()
                    }
                case .cash:
                    HStack(spacing: 0) {
                        Image("recordMainPinkCheck")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                            .accessibilityHidden(true)
                        Spacer()
                            .frame(width: 12)
                        Group {
                            Text("현금")
                                .foregroundStyle(.black)
                            Text(" / ")
                                .foregroundStyle(.gray200)
                            Text("카드")
                                .foregroundStyle(.gray200)
                        }
                        .font(.subhead3_2)
                        // 글자를 키우면 이 세 낱말이 한 글자씩 세로로 쪼개져
                        // 읽을 수 없었다. 제 너비를 지키게 한다.
                        .fixedSize()
                    }
                default:
                    HStack(spacing: 0) {
                        Image("recordGray100Check")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                            .accessibilityHidden(true)
                        Spacer()
                            .frame(width: 12)
                        Group {
                            Text("현금")
                                .foregroundStyle(.gray200)
                            Text(" / ")
                                .foregroundStyle(.gray200)
                            Text("카드")
                                .foregroundStyle(.gray200)
                        }
                        .font(.subhead3_2)
                        // 글자를 키우면 이 세 낱말이 한 글자씩 세로로 쪼개져
                        // 읽을 수 없었다. 제 너비를 지키게 한다.
                        .fixedSize()
                    }
                }
                Spacer()
                    .frame(minWidth: 0)
                    .layoutPriority(-2)
            }
        }
        // 큰 글자에서는 좌우 여백을 줄인다. 63pt 를 그대로 두면 남는 폭이
        // 모자라 글자가 눌린다.
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 63)
    }
}

// MARK: - 알림 방울

// 두 알림은 문구와 어느 깃발을 보는지만 달랐다. 나머지 스무 줄이 같아
// 한쪽만 고치면 다른 쪽이 조용히 어긋났다. 한 벌로 합치고 다른 것만 받는다.

struct RecordAlertBubble: View {

    let message: String
    let isShown: Bool

    /// 완전히 숨기지 않고 거의 투명하게만 둔다. 자리를 그대로 차지해야
    /// 알림이 뜨고 질 때 아래 묶음이 흔들리지 않는다.
    private var opacity: Double { isShown ? 1 : 0.0000001 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .foregroundStyle(.white)
                .opacity(opacity)
                .shadow(color: Color(0xCCCCCC), radius: 5)
                .layoutPriority(-1)

            VStack(spacing: 8) {
                Image("recordAlert")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    // 장식이라 소리로는 건너뛴다. 숨기지 않으면 자산 이름이 그대로 읽힌다.
                    .accessibilityHidden(true)
                Text(message)
                    .font(.subhead2_2)
                    .foregroundStyle(.gray300)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 41)
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            .opacity(opacity)
        }
        .padding(.horizontal, 30)
    }
}
