//
//  TravelListView.swift
//  Mwallet
//
//  여행 탭. 지금까지의 사역을 한 장씩 늘어놓는다.
//
//  예전에는 이 탭이 '고른 여행 하나의 지도' 였다. 지도는 한 여행 안에서
//  어디를 들렀는지 보는 도구인데 탭 첫 화면을 차지하고 있었고, 정작
//  '여러 여행을 다녔다' 는 사실은 선택기 한 줄로만 드러났다.
//  지도는 여행 상세로 옮기고, 이 탭은 목록이 됐다.
//
//  카드가 답해야 할 질문은 '언제, 어디를 몇 군데, 얼마 썼나' 다.
//  그중 '몇 군데' 를 여정 레일의 축소판으로 보여 준다 — 상세의 지도·목록과
//  같은 카테고리 색을 순서대로 이어, 카드만 봐도 동선이 읽힌다.
//

import SwiftUI

struct TravelListView: View {

    @EnvironmentObject private var mainVM: MainViewModel

    private let budgetStore = BudgetStore()

    @State private var travels: [Travel] = []
    @State private var refreshToken = UUID()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 12)

                headerRow

                if travels.isEmpty {
                    ReceiptEmptyState(
                        message: "아직 여행이 없어요",
                        detail: "오른쪽 위 + 로 여행을 만들면\n지출이 그 여행에 모입니다."
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(travels, id: \.objectID) { travel in
                                NavigationLink {
                                    TravelDetailView(travel: travel)
                                        .environmentObject(mainVM)
                                } label: {
                                    TravelCard(travel: travel,
                                               stops: stops(for: travel),
                                               summary: budgetStore.summary(for: travel))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 16)
                        // 떠 있는 탭바가 마지막 카드를 가리지 않도록 비워 둔다.
                        .padding(.bottom, 16)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarTitleDisplayMode(.inline)
            // 동작 버튼을 본문 첫 줄로 옮겼다. 네비게이션 바를 남겨 두면
            // 빈 밴드가 하나 더 생겨 본문 전체가 아래로 밀린다.
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: reload)
        }
    }

    // MARK: - 첫 줄

    private var headerRow: some View {
        TabHeaderRow {
            VStack(alignment: .leading, spacing: 4) {
                Text("여행")
                    .font(.title3_fixed)
                    .foregroundStyle(.black)
                Text(travels.isEmpty ? "여행을 만들어 시작하세요" : "\(travels.count)개의 여행")
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray400)
            }
        } actions: {
            NavigationLink { SettingView() } label: { TabActionIcon(systemName: "gearshape") }
            NavigationLink { AddTravelView() } label: { TabActionIcon(systemName: "plus") }
        }
    }

    // MARK: - 동작

    private func stops(for travel: Travel) -> [TravelExpenseStop] {
        _ = refreshToken
        return TravelExpenseStop.stops(from: budgetStore.expenses(for: travel))
    }

    private func reload() {
        travels = budgetStore.availableTravels()
        refreshToken = UUID()
    }
}

// MARK: - 여행 한 장

struct TravelCard: View {

    let travel: Travel
    let stops: [TravelExpenseStop]
    let summary: BudgetSummary

    private var isOngoing: Bool { TravelSchedule.state(of: travel) == .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            details
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray100, lineWidth: 1)
        )
    }

    // MARK: 사진

    @ViewBuilder
    private var cover: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let data = travel.coverImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image("DefaultImage")
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(height: 132)
            .frame(maxWidth: .infinity)
            .clipped()

            if isOngoing {
                Text("여행 중")
                    .font(.caption1_fixed)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.mainAccent, in: Capsule())
                    .padding(10)
            }
        }
    }

    // MARK: 본문

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(travel.displayName)
                .font(.title1_fixed)
                .foregroundStyle(.black)
                .lineLimit(1)

            Text("\(TravelSchedule.periodText(travel)) · \((travel.participantArray?.count ?? 0) + 1)명")
                .font(.caption1_fixed)
                .foregroundStyle(.gray300)

            HStack(alignment: .center, spacing: 0) {
                stopRail
                Spacer(minLength: 12)
                Text(ReceiptFormat.krw(summary.totalSpent))
                    .font(.subhead2_1_fixed)
                    .foregroundStyle(.black)
                    .monospacedDigit()
            }
        }
        .padding(14)
    }

    // 지도의 번호 핀과 같은 카테고리 색을 순서대로 잇는다.
    // 카드만 봐도 '몇 군데를, 어떤 성격의 지출로' 다녔는지 읽힌다.
    private var stopRail: some View {
        HStack(spacing: 5) {
            if stops.isEmpty {
                Text("기록된 장소 없음")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
            } else {
                HStack(spacing: 0) {
                    // 점이 너무 많으면 줄이 넘치므로 앞의 여섯 곳만 그린다.
                    ForEach(Array(stops.prefix(6).enumerated()), id: \.element.id) { index, stop in
                        if index > 0 {
                            Rectangle()
                                .fill(Color.gray200)
                                .frame(width: 8, height: 1.5)
                        }
                        Circle()
                            .fill(stop.category.color)
                            .frame(width: 9, height: 9)
                    }
                }

                Text("\(stops.count)곳")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray400)
                    .padding(.leading, 3)
            }
        }
    }
}
