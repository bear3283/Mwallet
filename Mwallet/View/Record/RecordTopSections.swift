//
//  RecordTopSections.swift
//  Mwallet
//
//  기록 화면 위쪽의 두 덩어리.
//
//    여행 선택   어느 여행에 넣을지
//    문장 영역   받아 적히는 말, 또는 처음 쓰는 사람을 위한 예시
//
//  RecordView 에서 떼어 냈다. 누르고 있는지(isPressing)는 화면이 제스처로
//  들고 있는 값이라 읽기만 하도록 값으로 건넨다.
//

import SwiftUI

// MARK: - 문장 영역

struct RecordSentenceArea: View {

    @ObservedObject var viewModel: RecordViewModel
    /// 녹음 버튼을 누르고 있는 중인지. 화면이 제스처로 들고 있는 값이다.
    let isPressing: Bool

    var body: some View {
        ZStack {
            Text("0000\n0000\n0000\n0000")
                .foregroundStyle(.gray300)
                .font(.title4)
                .hidden()
            
            Group {
                if (!isPressing && viewModel.voiceSentence == "") || (!viewModel.AreThereOtherTravels && !viewModel.isExplicitTempRecord) {
                    VStack(spacing: 16) {
                        // 언어마다 길이가 달라서 — 한국어 열두 자가 영어로는 스물두 자다 —
                        // 줄을 하나로 묶고 모자라면 글자를 줄인다. 두 줄로 접히면
                        // 아래 예시 말풍선이 밀려 화면이 흔들린다.
                        Text("한 문장이면 충분합니다")
                            .foregroundStyle(.gray400)
                            .font(.title4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        // 처음 쓰는 사람도 따라 할 수 있게 실제 말투를 예시 한 줄로 보여 준다.
                        // 예시는 그 언어로 실제로 말할 법한 문장이어야 한다.
                        recordExampleRow(icon: "🍽", text: String(localized: "점심 15000원 카드"))

                        // 기기 언어로 못 듣고 물러난 경우. 말없이 한국어로 들으면
                        // 사용자는 왜 아무것도 받아 적히지 않는지 알 길이 없다.
                        if !SpeechLocale.isAvailableForCurrentLanguage {
                            Text("이 언어는 아직 말하기로 받아 적지 못합니다. 직접 기록을 눌러 주세요.")
                                .font(.caption2)
                                .foregroundStyle(.gray300)
                                .multilineTextAlignment(.center)
                        }
                    }

                } else {
                    ZStack {
                        ThreeDotsView()
                            .offset(y: -74.5)
                        
                        if viewModel.voiceSentence == "" {
                            Text("듣고 있어요")
                                .foregroundStyle(.gray200)
                                .font(.title4)
                        } else {
                            Text(viewModel.voiceSentence)
                                .foregroundStyle(.black)
                                .font(.title4)
                                .lineLimit(4)
                        }
                    }
                    
                }
            }
            .padding(.horizontal, 48)
        }
    }

    private func recordExampleRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.body3)
            Text(verbatim: "\"\(text)\"")
                .font(.body2)
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color.gray100)
        .clipShape(Capsule())
    }
}

// MARK: - 고른 여행의 사진

/// 기록 화면 맨 위에 그 여행의 사진을 깐다.
///
/// 지금 어느 여행에 적고 있는지, 이름을 읽지 않아도 알게 한다. 여행 카드와
/// 같은 그림을 쓴다(TravelArtworkBuilder). 나라를 모르는 여행에는 사진이
/// 없으므로 그때는 아무것도 깔지 않는다 — 빈자리 표시 한 장을 대신 깔면
/// 어느 여행이든 같은 화면이 되어, 알려 주려던 것을 도리어 가린다.
///
/// RecordView 에서 떼어 냈다. 화면이 든 상태와 아무 상관이 없고, 고른
/// 여행 하나만 있으면 그려진다.
struct RecordTravelCover: View {

    let travel: Travel?

    /// 사진 띠의 높이. 여행 선택 글자가 앉는 자리(위에서 130 즈음)보다
    /// 아래까지 내려오되, 그 자리에 닿기 전에 흰색으로 다 녹는다.
    private static let height: CGFloat = 190

    private var photoName: String? {
        guard let travel,
              case .photo(let name) = TravelArtworkBuilder.artwork(for: travel).cover else { return nil }
        return name
    }

    var body: some View {
        if let name = photoName {
            VStack(spacing: 0) {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(height: Self.height)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    // 사진 위로 흰색을 겹쳐 아래쪽을 지운다. 글자가 앉는 자리에
                    // 이르면 흰 바탕과 구별되지 않아, 검은 글씨를 그대로 쓴다.
                    .overlay(
                        LinearGradient(stops: [
                            .init(color: .white.opacity(0), location: 0),
                            .init(color: .white.opacity(0.25), location: 0.45),
                            .init(color: .white, location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    )
                Spacer()
            }
            .accessibilityHidden(true)
        }
    }
}
