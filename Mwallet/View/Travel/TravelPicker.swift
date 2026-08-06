//
//  TravelPicker.swift
//  Mwallet
//
//  '지금 어느 여행을 보고 있는가' 를 고르는 컨트롤.
//
//  여행 지도 탭과 예결산 탭이 같은 일을 하므로 같은 컨트롤을 쓴다.
//  화면 제목이 곧 선택기다 — 두 화면 모두 '한 여행을 펼쳐 놓은 상태' 라
//  그 여행 이름이 제목이어야 맞고, 그러면 선택기 밴드가 따로 필요 없어
//  본문이 그만큼 위로 올라온다.
//
//  가로 스크롤 칩을 쓰던 시절에는 여행이 늘어나면 뒤쪽이 화면 밖으로 밀려
//  보이지 않았고, 두 탭이 각자 칩을 그려 스타일이 갈라질 위험도 있었다.
//

import CoreData
import SwiftUI

struct TravelPicker: View {

    let travels: [Travel]
    @Binding var selection: Travel?
    /// 선택이 바뀐 뒤에 할 일(집계 갱신, 지도 카메라 맞추기 등)
    var onChange: () -> Void = { }

    var body: some View {
        Menu {
            Picker("여행", selection: binding) {
                ForEach(travels, id: \.objectID) { travel in
                    Text(menuLabel(travel)).tag(travel.objectID as NSManagedObjectID?)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(selection?.displayName ?? "여행 선택")
                        .font(.display2_fixed)
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    // 고를 수 있다는 신호. 코발트는 누를 수 있는 것에만 쓴다.
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.mainAccent)

                    Spacer(minLength: 0)
                }

                Text(metaText)
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    // MARK: - 값

    // Travel 은 Hashable 비교가 번거로워 objectID 로 고른다.
    private var binding: Binding<NSManagedObjectID?> {
        Binding(
            get: { selection?.objectID },
            set: { newValue in
                guard let newValue,
                      let travel = travels.first(where: { $0.objectID == newValue }) else { return }
                selection = travel
                onChange()
            }
        )
    }

    // 제목 아래 한 줄. 기간과 인원은 확인용이라 작게 붙인다.
    private var metaText: String {
        guard let selection else { return "여행을 골라 주세요" }
        let people = (selection.participantArray?.count ?? 0) + 1
        return "\(Self.periodText(selection)) · \(people)명"
    }

    private func menuLabel(_ travel: Travel) -> String {
        "\(travel.displayName)  ·  \(Self.periodText(travel))"
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
