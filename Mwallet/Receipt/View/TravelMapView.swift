//
//  TravelMapView.swift
//  Mwallet
//
//  여행 탭. 사진 캐러셀 대신 '돈을 쓴 곳'을 지도에 찍는다.
//  각 지출이 카테고리 색 핀으로 지도에 올라가고, 아래에 여행별 요약이 붙는다.
//

import CoreLocation
import MapKit
import SwiftUI

struct TravelMapView: View {

    @EnvironmentObject private var mainVM: MainViewModel

    private let budgetStore = BudgetStore()
    private let receiptStore = ReceiptStore()

    @State private var travels: [Travel] = []
    @State private var selectedTravel: Travel?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var refreshToken = UUID()

    // 지도에 찍을 곳들. 좌표가 있는 지출만, 기록 순서대로 번호가 붙는다.
    private var stops: [TravelExpenseStop] {
        _ = refreshToken
        return TravelExpenseStop.stops(from: budgetStore.expenses(for: selectedTravel))
    }

    private var summary: BudgetSummary {
        _ = refreshToken
        return budgetStore.summary(for: selectedTravel)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 12)

                if travels.isEmpty {
                    ReceiptEmptyState(
                        message: "아직 여행이 없어요",
                        detail: "여행을 추가하고 지출을 남기면\n돈을 쓴 곳이 지도에 표시됩니다."
                    )
                } else {
                    travelChips

                    Spacer()
                        .frame(height: 16)

                    mapCard
                        .padding(.horizontal, ReceiptLayout.gutter)

                    Spacer()
                        .frame(height: 16)

                    if let travel = selectedTravel {
                        NavigationLink {
                            TravelDetailView(travel: travel)
                                .environmentObject(mainVM)
                        } label: {
                            summaryRow
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, ReceiptLayout.gutter)
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 상단 타이틀 헤더는 두지 않는다. 탭바가 현재 위치를 알려준다.
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.black)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AddTravelView()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.black)
                    }
                }
            }
            .onAppear(perform: reload)
        }
    }

    // MARK: - 여행 선택

    private var travelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(travels, id: \.objectID) { travel in
                    ReceiptChip(
                        title: travel.name ?? "이름 없음",
                        isSelected: selectedTravel?.objectID == travel.objectID
                    ) {
                        selectedTravel = travel
                        refreshToken = UUID()
                        fitCameraToExpenses()
                    }
                }
            }
            .padding(.horizontal, ReceiptLayout.gutter)
        }
    }

    // MARK: - 지도

    private var mapCard: some View {
        TravelExpenseMap(stops: stops, cameraPosition: $cameraPosition)
    }

    // MARK: - 요약

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTravel?.name ?? "여행")
                    .font(.subhead2_1_fixed)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text("\(stops.count)곳에서 지출")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
            }

            Spacer(minLength: 12)

            if summary.hasBudget {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(BudgetFormat.percent(summary.ratio))
                        .font(.subhead2_1_fixed)
                        .foregroundStyle(summary.isOverspent ? Color.mainOrange : Color.black)
                        .monospacedDigit()
                    Text(ReceiptFormat.krw(summary.totalSpent))
                        .font(.caption1_fixed)
                        .foregroundStyle(.gray300)
                        .monospacedDigit()
                }
            } else {
                Text(ReceiptFormat.krw(summary.totalSpent))
                    .font(.subhead2_1_fixed)
                    .foregroundStyle(.black)
                    .monospacedDigit()
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(.gray300)
                .padding(.leading, 10)
        }
        .padding(16)
        .background(Color.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 동작

    private func reload() {
        travels = budgetStore.availableTravels()
        if selectedTravel == nil || !travels.contains(where: { $0.objectID == selectedTravel?.objectID }) {
            selectedTravel = travels.first
        }
        refreshToken = UUID()
        fitCameraToExpenses()
    }

    // 지출 핀이 모두 보이도록 카메라를 맞춘다.
    private func fitCameraToExpenses() {
        let fitted = TravelMapCamera.fitted(to: stops)
        withAnimation {
            cameraPosition = fitted
        }
    }
}
