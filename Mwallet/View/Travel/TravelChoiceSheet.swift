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

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color.white)
        .presentationDetents([.fraction(0.36), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 머리

    private var header: some View {
        HStack(spacing: 12) {
            Text("여행 선택")
                .font(.title3_fixed)
                .foregroundStyle(.black)

            Spacer(minLength: 0)

            yearMenu

            Button("닫기") { dismiss() }
                .font(.subhead1_fixed)
                .foregroundStyle(.gray400)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    /// 해를 고르는 달력. Picker 를 메뉴 안에 두면 고른 것에 체크가 붙는다.
    private var yearMenu: some View {
        Menu {
            Picker("연도", selection: $year) {
                Text("전체 기간").tag(Int?.none)
                ForEach(years, id: \.self) { value in
                    Text("\(String(value))년").tag(Int?.some(value))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .semibold))
                if let year {
                    Text("\(String(year))년")
                        .font(.caption1_fixed)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(year == nil ? Color.gray400 : Color.mainAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(year == nil ? Color.gray100 : Color.mainAccent.opacity(0.12),
                        in: Capsule())
        }
        .accessibilityLabel(year == nil ? "연도 고르기" : "\(String(year!))년만 보는 중")
    }

    // MARK: - 몸

    @ViewBuilder
    private var content: some View {
        if travels.isEmpty {
            emptyNotice
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    if allowsAll {
                        Section {
                            Button {
                                choose(nil)
                            } label: {
                                TravelAllCard(isSelected: selection == nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(groups) { group in
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
                            sectionHeader(group)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    /// 해와 건수. 카드가 월·일만 지는 것은 이 머리글이 해를 맡기 때문이다.
    private func sectionHeader(_ group: TravelYearGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(group.title)
                .font(.subhead2_1_fixed)
                .foregroundStyle(.black)
                .monospacedDigit()

            Text("\(group.travels.count)")
                .font(.caption1_fixed)
                .foregroundStyle(.gray300)
                .monospacedDigit()

            Spacer(minLength: 8)
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }

    private var emptyNotice: some View {
        VStack(spacing: 6) {
            Text("아직 여행이 없습니다")
                .font(.subhead1_fixed)
                .foregroundStyle(.gray400)
            Text("여행 탭에서 먼저 여행을 만들어 주세요")
                .font(.caption2_fixed)
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
