//
//  BudgetView.swift
//  Mwallet
//
//  예결산. 사역 일정 하나의 예산과 실제 집행을 나란히 본다.
//  세부 내역은 영수증 탭에 있고, 여기서는 '얼마를 세워 얼마를 썼는가' 만 본다.
//

import Charts
import CoreData
import SwiftUI

struct BudgetView: View {

    @EnvironmentObject private var mainVM: MainViewModel

    private let store = BudgetStore()

    @State private var travels: [Travel] = []
    @State private var isEditingBudget = false
    // 예산을 저장하고 돌아왔을 때 집계를 다시 계산시키는 신호
    @State private var refreshToken = UUID()

    /// 지금 보는 여행. 기록·내역과 같은 것을 본다.
    private var selectedTravel: Travel? { mainVM.selectedTravel }

    private var summary: BudgetSummary {
        _ = refreshToken
        return store.summary(for: selectedTravel)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 12)

                if travels.isEmpty {
                    ReceiptEmptyState(
                        message: String(localized: "여행이 없어요"),
                        detail: String(localized: "여행 탭에서 여행을 먼저 만들면\n예산을 세울 수 있습니다.")
                    )
                } else {
                    travelSelector

                    Spacer()
                        .frame(height: 20)

                    content
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isEditingBudget, onDismiss: refreshAfterEditing) {
                if let travel = selectedTravel {
                    BudgetEditView(travel: travel)
                }
            }
            .onAppear(perform: reload)
        }
    }

    // MARK: - 사역 선택

    // '예산 편집' 은 고른 여행에 대한 동작이라 제목과 같은 줄에 둔다.
    // 툴바에 있을 때는 제목보다 한 층 위에 떠서 둘이 따로 놀았다.
    private var travelSelector: some View {
        TabHeaderRow {
            TravelPicker(travels: travels, selection: $mainVM.selectedTravel) {
                refreshToken = UUID()
            }
        } actions: {
            Button {
                isEditingBudget = true
            } label: {
                TabActionLabel(text: String(localized: "예산 편집"), isEnabled: selectedTravel != nil)
            }
            .disabled(selectedTravel == nil)
        }
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        if selectedTravel == nil {
            // 예산은 여행마다 세운다. 머리줄이 이미 '골라 달라' 고 말하므로
            // 여기서는 고를 것을 내놓기만 한다.
            ReceiptTravelBreakdown(entries: travelEntries) { travel in
                mainVM.selectedTravel = travel
                refreshToken = UUID()
            }
        } else if !summary.hasBudget && summary.totalSpent == 0 {
            ReceiptEmptyState(
                message: String(localized: "아직 예산이 없어요"),
                detail: String(localized: "위쪽 '예산 편집'에서\n분류별로 금액을 세워 보세요.")
            )
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    overview
                        .padding(.horizontal, ReceiptLayout.gutter)

                    Divider()
                        .padding(.top, 20)

                    BudgetChartSection(summary: summary, travel: selectedTravel)
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 20)

                    // 떠 있는 탭바가 마지막 항목을 가리지 않도록 여유를 둔다.
                    Spacer(minLength: 90)
                }
            }
        }
    }

    /// 고른 여행이 없을 때 내놓는 여행별 카드. 누르면 그 여행을 본다.
    private var travelEntries: [ReceiptTravelBreakdown.Entry] {
        travels.map { travel in
            ReceiptTravelBreakdown.Entry(travel: travel,
                                         budget: store.summary(for: travel),
                                         missingPhotoCount: 0)
        }
    }

    // MARK: - 총괄

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("예산 \(ReceiptFormat.krw(summary.totalPlanned))")
                .font(.caption2)
                .foregroundStyle(.gray300)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ReceiptFormat.krw(summary.totalSpent))
                    .font(.display4)
                    .foregroundStyle(.black)
                    .monospacedDigit()
                Text("지출")
                    .font(.caption2)
                    .foregroundStyle(.gray300)
            }
            .padding(.top, 6)

            BudgetProgressBar(ratio: summary.barRatio, isOver: summary.isOverspent)
                .padding(.top, 12)

            HStack(spacing: 0) {
                Text(BudgetFormat.remaining(summary.remaining))
                    .font(.caption2)
                    .foregroundStyle(summary.isOverspent ? Color.mainOrange : Color.gray400)
                Spacer()
                Text(BudgetFormat.percent(summary.ratio))
                    .font(.caption2)
                    .foregroundStyle(.gray400)
                    .monospacedDigit()
            }
            .padding(.top, 8)

            if !summary.overspentLines.isEmpty {
                ReceiptNotice(
                    text: String(localized: "예산을 넘긴 항목이 \(summary.overspentLines.count)개 있습니다")
                )
                .padding(.top, 10)
            }

            if summary.hasUnconvertible {
                ReceiptNotice(
                    text: String(localized: "환율을 받지 못한 \(summary.unconvertibleCount)건은 합계에서 빠졌습니다")
                )
                .padding(.top, 6)
            }
        }
    }

    // MARK: - 동작

    // 예산을 저장하고 돌아오면 집계를 다시 계산한다.
    private func refreshAfterEditing() {
        refreshToken = UUID()
        publishWidgetSnapshot()
    }

    private func reload() {
        travels = store.availableTravels()
        mainVM.dropSelectionIfDeleted()
        refreshToken = UUID()
        publishWidgetSnapshot()
    }

    // 위젯이 읽을 예결산 스냅샷을 발행한다.
    private func publishWidgetSnapshot() {
        let pending = store.expenses(for: selectedTravel).filter { $0.needsPhoto }.count
        MwalletBridge.publish(
            summary: store.summary(for: selectedTravel),
            travelName: selectedTravel?.name ?? String(localized: "여행"),
            pendingReceiptCount: pending,
            in: store.context
        )
    }
}

// MARK: - 그래프 섹션

// 같은 예결산 데이터를 두 가지 질문으로 본다.
// 집행률: 항목별로 예산을 얼마나 썼나 · 비중: 쓴 돈이 어디로 갔나
//
// '예산 대비' 그룹 막대가 하나 더 있었는데, 집행률 목록이 이미 쓴 금액과
// 예산과 초과 여부를 줄마다 적고 있어 같은 것을 다른 그림으로 보는 셈이었다.
enum BudgetChartMode: String, CaseIterable, Identifiable {
    // rawValue 는 자리를 가리키는 이름일 뿐이라 언어를 타지 않는다.
    // 화면에 적는 글자는 title 이다.
    case progress
    case share

    var id: String { rawValue }

    var title: String {
        switch self {
        case .progress: return String(localized: "예산 대비")
        case .share: return String(localized: "비중")
        }
    }
}

struct BudgetChartSection: View {

    let summary: BudgetSummary
    /// 분류를 눌러 내역으로 들어갈 때 어느 여행의 것인지 알아야 한다.
    let travel: Travel?
    @State private var mode: BudgetChartMode = .progress

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            modePicker

            Group {
                switch mode {
                case .progress: progressList
                case .share: shareChart
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: 모드 전환

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(BudgetChartMode.allCases) { chartMode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { mode = chartMode }
                } label: {
                    Text(chartMode.title)
                        .font(.subhead2_2)
                        .foregroundStyle(mode == chartMode ? Color.white : Color.gray400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(mode == chartMode ? Color.mainAccent : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.gray100, in: Capsule())
    }

    // MARK: 집행률 — 항목별 진행 막대

    private var progressList: some View {
        VStack(spacing: 0) {
            ForEach(summary.lines) { line in
                categoryRow(line)
            }
        }
    }

    /// 분류 한 줄. 누르면 그 분류가 언제 얼마씩 쌓였는지 본다.
    ///
    /// 여기서 멈추면 '식비 43,264원' 이 한 번에 나간 것인지 열 번에 걸친
    /// 것인지 알 수 없어, 영수증 탭으로 건너가 분류로 걸러야 했다.
    @ViewBuilder
    private func categoryRow(_ line: BudgetLine) -> some View {
        if let travel {
            NavigationLink {
                BudgetCategoryDetailView(travel: travel, line: line)
            } label: {
                categoryRowLabel(line)
            }
            .buttonStyle(.plain)
        } else {
            // 여행을 고르지 않았으면 들어갈 곳이 없다. 줄만 그린다.
            categoryRowLabel(line)
        }
    }

    private func categoryRowLabel(_ line: BudgetLine) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ReceiptCategoryPalette.color(for: line.category.description))
                        .frame(width: 10, height: 10)

                    Text(line.category.visibleDescription)
                        .font(.body1)
                        .foregroundStyle(.black)

                    if line.spentCount > 0 {
                        Text("\(line.spentCount)건")
                            .font(.caption1)
                            .foregroundStyle(.gray300)
                    }

                    Spacer(minLength: 8)

                    Text(BudgetFormat.percent(line.ratio))
                        .font(.subhead2_1)
                        .foregroundStyle(line.isOverspent ? Color.mainOrange : Color.black)
                        .monospacedDigit()

                    // 누를 수 있다는 신호. 없으면 눌러 볼 생각을 하지 않는다.
                    Image(systemName: "chevron.right")
                        .font(.caption1)
                        .foregroundStyle(.gray300)
                        .accessibilityHidden(true)
                }

                progressBar(ratio: line.barRatio, isOver: line.isOverspent, tint: line.category.color)

                HStack(spacing: 0) {
                    Text("\(ReceiptFormat.krw(line.spent)) / \(ReceiptFormat.krw(line.planned))")
                        .font(.caption1)
                        .foregroundStyle(.gray400)
                        .monospacedDigit()
                    Spacer()
                    Text(BudgetFormat.remaining(line.remaining))
                        .font(.caption1)
                        .foregroundStyle(line.isOverspent ? Color.mainOrange : Color.gray300)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 14)

            Divider()
        }
    }

    // 카테고리 줄의 막대는 그 카테고리 색으로 칠한다.
    // 코발트로 통일하면 왼쪽 점(카테고리 색)과 막대가 서로 다른 뜻의 색을 써서
    // 숙소처럼 점은 주황인데 막대는 파랑인 줄이 생긴다.
    private func progressBar(ratio: Double, isOver: Bool, tint: Color = .mainAccent) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray100)
                Capsule()
                    .fill(barColor(isOver: isOver, tint: tint))
                    .frame(width: geometry.size.width * ratio)
            }
        }
        .frame(height: 8)
    }

    // 초과는 이미 퍼센트 숫자와 'N원 초과' 문구가 알린다.
    // 카테고리 줄에서까지 막대를 경고색으로 덮으면, 숙소처럼 주황 계열
    // 카테고리가 초과가 아닐 때도 초과처럼 읽힌다. 총괄 막대만 경고색을 쓴다.
    private func barColor(isOver: Bool, tint: Color) -> Color {
        guard tint == .mainAccent else { return tint }
        return isOver ? .mainOrange : tint
    }

    // MARK: 비중 — 집행액 도넛

    @ViewBuilder
    private var shareChart: some View {
        let slices = shareSlices
        if slices.isEmpty {
            Text("아직 지출 내역이 없어요. 지출을 기록하면 비중이 채워집니다.")
                .font(.body1)
                .foregroundStyle(.gray300)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 0) {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("금액", slice.amount),
                        innerRadius: .ratio(0.64),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(ReceiptCategoryPalette.color(for: slice.category))
                }
                .chartLegend(.hidden)
                .frame(height: 200)
                .padding(.vertical, 8)
                .overlay {
                    VStack(spacing: 2) {
                        Text("총 지출")
                            .font(.caption1)
                            .foregroundStyle(.gray300)
                        Text(ReceiptFormat.krw(summary.totalSpent))
                            .font(.subhead3_1)
                            .foregroundStyle(.black)
                            .monospacedDigit()
                    }
                }

                ForEach(slices) { slice in
                    Divider()
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ReceiptCategoryPalette.color(for: slice.category))
                            .frame(width: 10, height: 10)
                        Text(ExpenseInfoCategory.displayName(forStored: slice.category))
                            .font(.body1)
                            .foregroundStyle(.black)
                        Spacer(minLength: 8)
                        Text(ReceiptFormat.krw(slice.amount))
                            .font(.subhead2_1)
                            .foregroundStyle(.black)
                            .monospacedDigit()
                        Text(sharePercent(slice.amount))
                            .font(.caption1)
                            .foregroundStyle(.gray300)
                            .monospacedDigit()
                            .frame(width: 46, alignment: .trailing)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private var shareSlices: [BudgetSlice] {
        summary.lines
            .filter { $0.spent > 0 }
            .map { BudgetSlice(category: $0.category.description, amount: $0.spent) }
    }

    // MARK: 포맷

    private func sharePercent(_ amount: Double) -> String {
        guard summary.totalSpent > 0 else { return "0%" }
        return String(format: "%.0f%%", amount / summary.totalSpent * 100)
    }
}

private struct BudgetSlice: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
}
