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
                    Spacer()
                        .frame(width: 12)
                    Text("-")
                        .foregroundStyle(.gray200)
                        .font(.subhead3_2)
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
                    Spacer()
                        .frame(width: 12)
                    Text("-")
                        .foregroundStyle(.gray200)
                        .font(.subhead3_2)
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
                    }
                case .cash:
                    HStack(spacing: 0) {
                        Image("recordMainPinkCheck")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
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
                    }
                default:
                    HStack(spacing: 0) {
                        Image("recordGray100Check")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
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
                    }
                }
                Spacer()
                    .frame(minWidth: 0)
                    .layoutPriority(-2)
            }
        }
        .padding(.horizontal, 63)
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
