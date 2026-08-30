//
//  TravelPicker.swift
//  Mwallet
//
//  '지금 어느 여행을 보고 있는가' 를 고르는 자리. 예결산과 영수증이 쓴다.
//
//  여기 있는 것은 누르는 자리(고른 여행의 이름과 기간)뿐이고, 고르는 일
//  자체는 TravelChoiceSheet 이 맡는다. 기록 탭은 이 자리가 화면 안에
//  따로 있어 시트만 바로 띄운다.
//
//  고르는 방식은 시트다. 처음에는 시스템 Menu 를 썼는데, 메뉴 항목이
//  "이름 · 기간" 한 줄짜리 작은 글씨라 이름과 날짜가 서로 붙어 읽히지
//  않았다.
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
    var emptyTitle = String(localized: "여행 선택")
    var emptyDescription = String(localized: "여행을 골라 주세요")

    /// 영수증처럼 '고르지 않음' 이 '모두 본다' 는 뜻인 화면에서 켠다.
    var allowsAll = false

    /// 글을 어느 쪽으로 붙일지.
    ///
    /// 예결산·영수증은 머리줄 왼쪽에 앉아 왼쪽 정렬이고, 기록 탭은 화면
    /// 한가운데 놓이는 초점이라 가운데 정렬이다. 짜임은 같고 정렬만 다르다.
    var alignment: HorizontalAlignment = .leading

    @State private var isChoosing = false

    var body: some View {
        Button {
            isChoosing = true
        } label: {
            // chevron 을 이름 바로 옆에 붙인다. 오른쪽 끝은 탭 동작 버튼 자리라
            // 거기에 두면 선택기와 동작 버튼이 뒤섞여 보인다.
            VStack(alignment: alignment, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(chosen?.displayName ?? emptyTitle)
                        .font(.title3)
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    // 고를 수 있다는 신호. 코발트는 누를 수 있는 것에만 쓴다.
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mainAccent)
                }

                Text(metaText)
                    .font(.caption2)
                    .foregroundStyle(.gray400)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isChoosing) {
            // 높이(두 단)와 짜임은 시트가 스스로 안다. 부르는 쪽이 정하면
            // 화면마다 조금씩 달라져 다시 갈라진다.
            TravelChoiceSheet(travels: travels,
                              selection: $selection,
                              allowsAll: allowsAll,
                              onChange: onChange)
        }
    }

    /// 화면에 이름을 적을 여행.
    ///
    /// 기본함('임시 기록')은 고르지 않은 것으로 본다. 사용자가 만든 일정이
    /// 아니라 여행을 안 고른 지출이 담기는 자리라, 이름과 기간을 그대로
    /// 적으면 오늘 하루짜리 여행을 다니는 것처럼 읽힌다.
    private var chosen: Travel? {
        guard let selection, selection.isUserCreated else { return nil }
        return selection
    }

    private var metaText: String {
        guard let chosen else { return emptyDescription }
        let people = chosen.participants.count + 1
        return String(localized: "\(TravelSchedule.periodText(chosen)) · \(people)명")
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
        formatter.setLocalizedDateFormatFromTemplate("yyMMd")
        guard let start = travel.startDate else { return String(localized: "기간 미정") }
        guard let end = travel.endDate else { return String(localized: "\(formatter.string(from: start)) ~ 미정") }
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    /// 연도를 뺀 기간. 선택 시트의 카드에 쓴다.
    ///
    /// 카드는 110pt 남짓이라 'yy.MM.dd ~ yy.MM.dd' 가 들어가지 않는다.
    /// 해는 묶음 머리글이 이미 말하고 있어 카드에서는 덜어 낼 수 있다.
    static func dayRangeText(_ travel: Travel) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMd")
        guard let start = travel.startDate else { return String(localized: "날짜 미정") }
        let from = formatter.string(from: start)
        guard let end = travel.endDate else { return "\(from) ~" }
        // 하루짜리는 물결표 뒤가 같은 말이라 한 번만 적는다.
        let to = formatter.string(from: end)
        return from == to ? from : "\(from) – \(to)"
    }
}
