//
//  TravelChoiceSheet.swift
//  Mwallet
//
//  '어느 여행인가' 를 고르는 시트. 기록·예결산·영수증이 함께 쓴다.
//
//  세 탭이 같은 것을 묻는데 생김새가 서로 달랐다. 기록은 사진 카드가
//  가로로 흐르고, 예결산·영수증은 글자만 있는 세로 목록이었다. 같은 일을
//  하는 자리라 한 벌로 합쳤다.
//
//  높이는 두 단이다. 처음에는 낮게 떠서 한 줄만 보이고, 끌어올리면 나머지가
//  나온다. 낮을 때와 높을 때 짜임을 달리하지 않는 것이 중요하다 — 끌 때마다
//  카드가 자리를 옮기면 어디를 누르려던 것인지 놓친다. 격자는 한 벌이고
//  시트 높이가 창의 크기를 정할 뿐이다.
//
//  여행이 쌓이면 해가 여럿이 되므로 오른쪽 위 달력에서 한 해만 볼 수 있다.
//  이것을 또 시트로 띄우면 시트가 겹쳐, 끌어내릴 때 어느 쪽이 닫히는지
//  알 수 없다. 그래서 메뉴다.
//
//  제목과 닫기 버튼은 두지 않는다. 누른 자리가 이미 '여행 선택' 이라 시트가
//  같은 말을 되풀이할 까닭이 없고, 닫는 일은 끌어내리면 된다. 그 줄을 비운
//  덕에 맨 위가 곧 첫 해('2026년')이고, 달력은 그 줄 오른쪽에 떠 있다.
//

import SwiftUI

struct TravelChoiceSheet: View {

    let travels: [Travel]
    @Binding var selection: Travel?

    /// 영수증처럼 '고르지 않음' 이 뜻을 갖는 화면에서 켠다.
    var allowsAll = false
    /// 고른 뒤에 할 일(집계 갱신, 지도 맞추기 등).
    var onChange: () -> Void = { }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar

    /// 고른 해. nil 이면 모든 해를 본다.
    @State private var year: Int?

    private var visible: [Travel] {
        TravelGrouping.filter(travels, year: year, calendar: calendar)
    }

    private var groups: [TravelYearGroup] {
        TravelGrouping.byYear(visible, calendar: calendar)
    }

    private var years: [Int] {
        TravelGrouping.years(in: travels, calendar: calendar)
    }

    /// 석 줄. 칸이 110pt 남짓 남아 카드가 알아볼 수 있는 가장 작은 크기다.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    /// 맨 윗줄의 높이. 달력 버튼과 첫 머리글이 같은 줄에 앉도록 맞춘다.
    private let topRowHeight: CGFloat = 44
    /// 손잡이 아래로 띄우는 여백. 이보다 좁으면 첫 줄이 손잡이에 붙는다.
    private let topInset: CGFloat = 22

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            if !travels.isEmpty {
                yearMenu
                    .padding(.top, topInset)
                    .padding(.trailing, 20)
            }
        }
        .background(Color.white)
        .presentationDetents([.fraction(0.36), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 달력

    /// 해를 고르는 달력. Picker 를 메뉴 안에 두면 고른 것에 체크가 붙는다.
    ///
    /// 목록 위에 떠 있어 카드가 그 밑으로 지나간다. 바탕이 비치면 카드와
    /// 겹쳐 읽히지 않으므로 흰색을 먼저 깔고 그 위에 색을 얹는다.
    private var yearMenu: some View {
        Menu {
            Picker("연도", selection: $year) {
                Text("전체 기간").tag(Int?.none)
                ForEach(years, id: \.self) { value in
                    Text("\(String(value))년").tag(Int?.some(value))
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .medium))
                if let year {
                    Text("\(String(year))년")
                        .font(.subhead1)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(year == nil ? Color.gray400 : Color.mainAccent)
            .padding(.horizontal, 12)
            .frame(minWidth: topRowHeight, minHeight: topRowHeight)
            .background(year == nil ? Color.gray100 : Color.mainAccent.opacity(0.12),
                        in: Capsule())
            .background(Color.white, in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel(year == nil ? String(localized: "연도 고르기")
                            : String(localized: "\(String(year!))년만 보는 중"))
    }

    // MARK: - 몸

    @ViewBuilder
    private var content: some View {
        if travels.isEmpty {
            emptyNotice
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    if allowsAll {
                        Button {
                            choose(nil)
                        } label: {
                            TravelAllChip(isSelected: selection == nil)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: topRowHeight, alignment: .leading)
                        .padding(.bottom, 8)
                    }

                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                            Section {
                                ForEach(group.travels, id: \.objectID) { travel in
                                    Button {
                                        choose(travel)
                                    } label: {
                                        TravelCard(travel: travel,
                                                   artwork: TravelArtworkBuilder.artwork(for: travel),
                                                   isSelected: travel.objectID == selection?.objectID)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                // 맨 윗줄에 오는 머리글만 달력과 키를 맞춘다.
                                sectionHeader(group, sharesTopRow: index == 0 && !allowsAll)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, topInset)
                .padding(.bottom, 24)
            }
        }
    }

    /// 해와 건수. 카드가 월·일만 지는 것은 이 머리글이 해를 맡기 때문이다.
    private func sectionHeader(_ group: TravelYearGroup, sharesTopRow: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(group.title)
                .font(sharesTopRow ? .title2 : .subhead2_1)
                .foregroundStyle(.black)
                .monospacedDigit()

            Text("\(group.travels.count)")
                .font(.caption1)
                .foregroundStyle(.gray300)
                .monospacedDigit()

            Spacer(minLength: 8)
        }
        .padding(.top, sharesTopRow ? 0 : 4)
        .padding(.bottom, sharesTopRow ? 0 : 2)
        .frame(maxWidth: .infinity, minHeight: sharesTopRow ? topRowHeight : nil, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }

    private var emptyNotice: some View {
        VStack(spacing: 6) {
            Text("아직 여행이 없습니다")
                .font(.subhead1)
                .foregroundStyle(.gray400)
            Text("여행 탭에서 먼저 여행을 만들어 주세요")
                .font(.caption2)
                .foregroundStyle(.gray300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 40)
    }

    private func choose(_ travel: Travel?) {
        selection = travel
        onChange()
        dismiss()
    }
}
