//
//  TravelPicker.swift
//  Mwallet
//
//  '지금 어느 여행을 보고 있는가' 를 고르는 컨트롤.
//  여행 지도 탭과 예결산 탭이 같은 일을 하므로 같은 컨트롤을 쓴다.
//
//  고르는 방식은 시트다. 처음에는 시스템 Menu 를 썼는데, 메뉴 항목이
//  "이름 · 기간" 한 줄짜리 작은 글씨라 이름과 날짜가 서로 붙어 읽히지
//  않았다. 시트는 한 줄에 두 층을 줄 수 있어 이름을 크게, 기간을 아래에
//  따로 놓을 수 있고, 지금 여행 중인지도 함께 보여 줄 수 있다.
//  (카테고리·국가 선택도 이미 같은 방식의 시트를 쓴다)
//

import CoreData
import SwiftUI

struct TravelPicker: View {

    let travels: [Travel]
    @Binding var selection: Travel?
    /// 선택이 바뀐 뒤에 할 일(집계 갱신, 지도 카메라 맞추기 등)
    var onChange: () -> Void = { }

    /// 아무것도 고르지 않았을 때의 제목과 설명.
    ///
    /// 예결산은 여행이 정해져야 예산을 뽑을 수 있어 '골라 달라' 고 청하지만,
    /// 영수증은 고르지 않은 것이 '모든 여행을 함께 본다' 는 뜻이라 청할 것이
    /// 없다. 같은 자리에 같은 생김새로 두되 말은 화면에 맞춘다.
    var emptyTitle = "여행 선택"
    var emptyDescription = "여행을 골라 주세요"

    @State private var isChoosing = false

    var body: some View {
        Button {
            isChoosing = true
        } label: {
            // chevron 을 이름 바로 옆에 붙인다. 오른쪽 끝은 탭 동작 버튼 자리라
            // 거기에 두면 선택기와 동작 버튼이 뒤섞여 보인다.
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(selection?.displayName ?? emptyTitle)
                        .font(.title3_fixed)
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    // 고를 수 있다는 신호. 코발트는 누를 수 있는 것에만 쓴다.
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mainAccent)
                }

                Text(metaText)
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray400)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isChoosing) {
            TravelChoiceSheet(travels: travels, selection: $selection, onChange: onChange)
                .presentationDetents([.medium, .large])
        }
    }

    private var metaText: String {
        guard let selection else { return emptyDescription }
        let people = selection.participants.count + 1
        return "\(TravelSchedule.periodText(selection)) · \(people)명"
    }
}

// MARK: - 선택 시트

private struct TravelChoiceSheet: View {

    let travels: [Travel]
    @Binding var selection: Travel?
    var onChange: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(travels, id: \.objectID) { travel in
                Button {
                    selection = travel
                    onChange()
                    dismiss()
                } label: {
                    row(travel)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("여행 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(.gray400)
                }
            }
        }
    }

    private func row(_ travel: Travel) -> some View {
        let state = TravelSchedule.state(of: travel)
        let isSelected = travel.objectID == selection?.objectID

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(travel.displayName)
                        .font(.subhead2_1_fixed)
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    // 지금 진행 중인 여행만 표시한다. 나머지는 굳이 이름표를 달지 않는다.
                    if state == .current {
                        Text("여행 중")
                            .font(.caption1_fixed)
                            .foregroundStyle(Color.mainAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.mainAccent.opacity(0.1), in: Capsule())
                    }
                }

                Text("\(TravelSchedule.periodText(travel)) · \(travel.participants.count + 1)명")
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray400)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.mainAccent)
                .opacity(isSelected ? 1 : 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - 일정 표현

enum TravelSchedule {

    enum State {
        case current, past, coming
    }

    static func state(of travel: Travel, now: Date = Date()) -> State {
        let start = travel.startDate ?? .distantPast
        let end = travel.endDate ?? .distantFuture
        if start <= now && now <= end { return .current }
        return start > now ? .coming : .past
    }

    static func periodText(_ travel: Travel) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yy.MM.dd"
        guard let start = travel.startDate else { return "기간 미정" }
        guard let end = travel.endDate else { return "\(formatter.string(from: start)) ~ 미정" }
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }
}
