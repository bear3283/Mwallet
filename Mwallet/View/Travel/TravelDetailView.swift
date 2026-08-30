//
//  TravelDetailView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/26.
//
//  여행 상세. 지도와 지출 흐름이 주인공이다.
//  기간·국가·인원은 한 번 확인하면 되는 값이라 위쪽 한 줄로 접어 두고,
//  화면의 대부분은 '어디서 어떤 순서로 썼는가' 에 쓴다.
//

import CoreData
import MapKit
import OSLog
import SwiftUI

struct TravelDetailView: View {

    @EnvironmentObject var mainVM: MainViewModel
    @Environment(\.dismiss) private var dismiss

    private let budgetStore = BudgetStore()
    private let travelStore = TravelStore()

    let travel: Travel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var highlightedID: NSManagedObjectID?
    @State private var isWarningOn = false
    @State private var refreshToken = UUID()

    init(travel: Travel) {
        self.travel = travel
    }

    // MARK: - 파생 값

    private var expenses: [Expense] {
        _ = refreshToken
        return budgetStore.expenses(for: travel)
    }

    private var stops: [TravelExpenseStop] {
        TravelExpenseStop.stops(from: expenses)
    }

    /// 목록의 한 줄에서 그 지출로 돌아가는 길. 상세에서 고치고 지운다.
    private func expense(for stop: TravelExpenseStop) -> Expense? {
        expenses.first { $0.objectID == stop.id }
    }

    private var summary: BudgetSummary {
        _ = refreshToken
        return budgetStore.summary(for: travel)
    }

    private var travelName: String {
        let name = travel.name ?? ""
        return name.isEmpty ? String(localized: "이름 없는 여행") : name
    }

    private var isOngoing: Bool {
        let now = Date()
        return (travel.startDate ?? .distantFuture) <= now && now <= (travel.endDate ?? .distantFuture)
    }

    private var dayCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: travel.startDate ?? Date())
        let today = calendar.startOfDay(for: Date())
        return max(calendar.dateComponents([.day], from: start, to: today).day ?? 0, 0) + 1
    }

    private var periodText: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMd")
        guard let start = travel.startDate else { return String(localized: "미정") }
        guard let end = travel.endDate else { return String(localized: "\(formatter.string(from: start)) ~ 미정") }
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    // 지출에 남은 국가 코드로 방문 국가를 만든다.
    private var countries: [CountryInfo] {
        _ = refreshToken
        let indices = Set(budgetStore.expenses(for: travel).map { Int($0.country) })
        return indices
            .sorted()
            .compactMap { CountryInfoModel.shared.countryResult[$0] }
            .filter { $0.koreanNm != "알 수 없음" }
    }

    private var participants: [String] {
        ["나"] + travel.participants
    }

    // MARK: - 본문

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    TravelDetailHeader(travel: travel,
                                       travelName: travelName,
                                       isOngoing: isOngoing,
                                       dayCount: dayCount)
                    TravelBasicInfoStrip(
                        periodText: periodText,
                        countryText: countries.isEmpty ? String(localized: "기록 없음") : countries.map(\.displayName).joined(separator: ", "),
                        peopleCount: participants.count)
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 16)

                    TravelBudgetStrip(summary: summary)
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 10)

                    mapSection
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 20)

                    expenseListSection
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 24)

                    TravelSettlementSection(summary: SettlementSummary(expenses: expenses))
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 28)

                    // 떠 있는 탭바가 마지막 항목을 가리지 않도록 비워 둔다.
                    Spacer(minLength: 110)
                }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // 하단 탭바를 그대로 둔다. 여행 상세에서도 다른 탭으로 바로 건너갈 수
        // 있어야 하고, 탭바가 사라졌다 나타나면 현재 위치를 잃기 쉽다.
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.black)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    NavigationLink {
                        TravelEditView(travel: travel)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.black)
                    }
                    // 화면 테스트가 이름으로 찾는다. 순서로 집으면 버튼이
                    // 하나 늘거나 줄 때 조용히 다른 것을 누른다.
                    .accessibilityIdentifier("travelDetail.edit")

                    Button {
                        isWarningOn = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.black)
                    }
                    .accessibilityIdentifier("travelDetail.delete")
                }
            }
        }
        .alert("여행 삭제하기", isPresented: $isWarningOn) {
            Button("삭제하기", role: .destructive, action: deleteTravel)
            Button("취소", role: .cancel) { }
        } message: {
            Text("현재 선택한 여행방에 저장된 지출 기록 및 관련 데이터를 모두 삭제할까요?")
        }
        // 편집에서 돌아왔을 때 이름·기간·인원을 다시 읽는다.
        .onAppear {
            refreshToken = UUID()
            cameraPosition = TravelMapCamera.fitted(to: stops)
        }
    }

    // MARK: - 머리말

    // MARK: - 기본 정보 (기간 · 국가 · 인원)

    // MARK: - 예산 집행 (간략)

    // 여기까지 얼마를 썼는지는 여행을 열 때마다 묻게 되는 값이라, 예결산 탭까지
    // 가지 않고도 한눈에 보이게 둔다. 자세한 카테고리별 내역은 예결산의 몫이다.

    // MARK: - 지도

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Text("지출한 곳")
                    .font(.subhead1)
                    .foregroundStyle(.gray400)
                Spacer()
                if !stops.isEmpty {
                    Text("\(stops.count)곳 · 기록 순서")
                        .font(.caption1)
                        .foregroundStyle(.gray300)
                }
            }

            TravelExpenseMap(
                stops: stops,
                cameraPosition: $cameraPosition,
                height: 360,
                highlightedID: highlightedID,
                onSelect: focus(on:),
                onResetCamera: resetCamera
            )
        }
    }

    // MARK: - 지출 순서 목록

    private var expenseListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Text("지출 순서")
                    .font(.subhead1)
                    .foregroundStyle(.gray400)
                Spacer()
                Text(ReceiptFormat.krw(summary.totalSpent))
                    .font(.subhead1)
                    .foregroundStyle(.gray400)
                    .monospacedDigit()
            }

            if stops.isEmpty {
                // 빈 화면은 다음에 할 일을 알려 준다.
                Text("아직 위치가 남은 지출이 없습니다.\n기록할 때 위치를 함께 남기면 들른 순서가 지도에 그려집니다.")
                    .font(.caption2)
                    .foregroundStyle(.gray300)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        let row = TravelExpenseRow(
                            stop: stop,
                            isHighlighted: stop.id == highlightedID,
                            isFirst: index == 0,
                            isLast: index == stops.count - 1,
                            onFocus: { focus(on: stop) }
                        )

                        if let expense = expense(for: stop) {
                            NavigationLink {
                                ReceiptDetailView(expense: expense)
                            } label: {
                                row
                            }
                            .buttonStyle(.plain)
                            // 화면 테스트가 이름으로 첫 줄을 집는다. 상호명으로
                            // 집으면 어느 여행이 먼저 오느냐에 따라 못 찾는다.
                            .accessibilityIdentifier("travelDetail.expenseRow")
                        } else {
                            row
                        }
                    }
                }
            }
        }
    }

    // MARK: - 동작

    // 목록이나 핀을 누르면 그 지점을 지도 가운데로 옮기고 강조한다.
    private func focus(on stop: TravelExpenseStop) {
        withAnimation(.snappy) {
            highlightedID = stop.id
            cameraPosition = TravelMapCamera.focused(on: stop)
        }
    }

    // 처음 화면으로 되돌린다. 강조도 함께 푼다 —
    // 모두 보이는 화면에서 한 곳만 굵게 남아 있으면 그것만 고른 것처럼 읽힌다.
    private func resetCamera() {
        withAnimation(.snappy) {
            highlightedID = nil
            cameraPosition = TravelMapCamera.fitted(to: stops)
        }
    }

    private func deleteTravel() {
        let deletedID = travel.id

        // 화면이 사라진 뒤에 지워야, 삭제된 객체를 그리려다 죽지 않는다.
        dismiss()

        DispatchQueue.main.async {
            do {
                try travelStore.delete(travel)
            } catch {
                Logger.data.error("여행 삭제 실패: \(error.localizedDescription, privacy: .public)")
            }

            if let deletedID,
               deletedID == mainVM.selectedTravel?.id || deletedID == mainVM.selectedTravelInExpense?.id {
                mainVM.selectedTravelInExpense = findInitialTravelInExpense()
                mainVM.selectedTravel = findCurrentTravel()
            }
        }
    }
}
