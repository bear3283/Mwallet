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
                        Text("한 문장이면 충분합니다")
                            .foregroundStyle(.gray400)
                            .font(.title4)

                        // 처음 쓰는 사람도 따라 할 수 있게 실제 말투를 예시 한 줄로 보여 준다.
                        recordExampleRow(icon: "🍽", text: "점심 15000원 카드")
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
            Text("\"\(text)\"")
                .font(.body2)
                .foregroundStyle(.black)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color.gray100)
        .clipShape(Capsule())
    }
}
