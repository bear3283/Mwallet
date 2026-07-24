//
//  BudgetView.swift
//  Mwallet
//
//  예결산. 사역 일정 하나의 예산과 실제 집행을 나란히 본다.
//  세부 내역은 영수증 탭에 있고, 여기서는 '얼마를 세워 얼마를 썼는가' 만 본다.
//

import SwiftUI

struct BudgetView: View {

    @EnvironmentObject private var mainVM: MainViewModel

    private let store = BudgetStore()

    @State private var travels: [Travel] = []
    @State private var selectedTravel: Travel?
    @State private var isEditingBudget = false
    // 예산을 저장하고 돌아왔을 때 집계를 다시 계산시키는 신호
    @State private var refreshToken = UUID()

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
                        message: "사역 일정이 없어요",
                        detail: "여행 탭에서 일정을 먼저 만들면\n예산을 세울 수 있습니다."
                    )
                } else {
                    travelChips

                    Spacer()
                        .frame(height: 20)

                    content
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 상단 타이틀 헤더는 두지 않는다. 탭바가 현재 위치를 알려준다.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditingBudget = true
                    } label: {
                        Text("예산 편집")
                            .font(.subhead2_2_fixed)
                            .foregroundStyle(selectedTravel == nil ? Color.gray200 : Color.black)
                    }
                    .disabled(selectedTravel == nil)
                }
            }
            .sheet(isPresented: $isEditingBudget, onDismiss: refreshAfterEditing) {
                if let travel = selectedTravel {
                    BudgetEditView(travel: travel)
                }
            }
            .onAppear(perform: reload)
        }
    }

    // MARK: - 사역 선택

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
                    }
                }
            }
            .padding(.horizontal, ReceiptLayout.gutter)
        }
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        if !summary.hasBudget && summary.totalSpent == 0 {
            ReceiptEmptyState(
                message: "아직 예산이 없어요",
                detail: "오른쪽 위 '예산 편집'에서\n카테고리별로 금액을 세워 보세요."
            )
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    overview
                        .padding(.horizontal, ReceiptLayout.gutter)

                    Divider()
                        .padding(.top, 20)

                    ReceiptSectionTitle(text: "카테고리별", trailing: "집행률")
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 20)

                    ForEach(summary.lines) { line in
                        categoryRow(line)
                            .padding(.horizontal, ReceiptLayout.gutter)
                    }

                    // 떠 있는 탭바가 마지막 항목을 가리지 않도록 여유를 둔다.
                    Spacer(minLength: 90)
                }
            }
        }
    }

    // MARK: - 총괄

    private var overview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("예산 \(ReceiptFormat.krw(summary.totalPlanned))")
                .font(.caption2_fixed)
                .foregroundStyle(.gray300)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ReceiptFormat.krw(summary.totalSpent))
                    .font(.display4_fixed)
                    .foregroundStyle(.black)
                    .monospacedDigit()
                Text("집행")
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray300)
            }
            .padding(.top, 6)

            progressBar(ratio: summary.barRatio, isOver: summary.isOverspent)
                .padding(.top, 12)

            HStack(spacing: 0) {
                Text(BudgetFormat.remaining(summary.remaining))
                    .font(.caption2_fixed)
                    .foregroundStyle(summary.isOverspent ? Color.mainOrange : Color.gray400)
                Spacer()
                Text(BudgetFormat.percent(summary.ratio))
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray400)
                    .monospacedDigit()
            }
            .padding(.top, 8)

            if !summary.overspentLines.isEmpty {
                ReceiptNotice(
                    text: "예산을 넘긴 항목이 \(summary.overspentLines.count)개 있습니다"
                )
                .padding(.top, 10)
            }

            if summary.hasUnconvertible {
                ReceiptNotice(
                    text: "환율을 받지 못한 \(summary.unconvertibleCount)건은 집행액에서 빠졌습니다"
                )
                .padding(.top, 6)
            }
        }
    }

    // MARK: - 카테고리 행

    private func categoryRow(_ line: BudgetLine) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ReceiptCategoryPalette.color(for: line.category.description))
                        .frame(width: 10, height: 10)

                    Text(line.category.description)
                        .font(.body1_fixed)
                        .foregroundStyle(.black)

                    if line.spentCount > 0 {
                        Text("\(line.spentCount)건")
                            .font(.caption1_fixed)
                            .foregroundStyle(.gray300)
                    }

                    Spacer(minLength: 8)

                    Text(BudgetFormat.percent(line.ratio))
                        .font(.subhead2_1_fixed)
                        .foregroundStyle(line.isOverspent ? Color.mainOrange : Color.black)
                        .monospacedDigit()
                }

                progressBar(ratio: line.barRatio, isOver: line.isOverspent)

                HStack(spacing: 0) {
                    Text("\(ReceiptFormat.krw(line.spent)) / \(ReceiptFormat.krw(line.planned))")
                        .font(.caption1_fixed)
                        .foregroundStyle(.gray400)
                        .monospacedDigit()
                    Spacer()
                    Text(BudgetFormat.remaining(line.remaining))
                        .font(.caption1_fixed)
                        .foregroundStyle(line.isOverspent ? Color.mainOrange : Color.gray300)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 14)

            Divider()
        }
    }

    // MARK: - 진행 막대

    private func progressBar(ratio: Double, isOver: Bool) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray100)
                Capsule()
                    .fill(isOver ? Color.mainOrange : Color.mainGreen)
                    .frame(width: geometry.size.width * ratio)
            }
        }
        .frame(height: 8)
    }

    // MARK: - 동작

    // 예산을 저장하고 돌아오면 집계를 다시 계산한다.
    private func refreshAfterEditing() {
        refreshToken = UUID()
    }

    private func reload() {
        travels = store.availableTravels()
        if selectedTravel == nil || !travels.contains(where: { $0.objectID == selectedTravel?.objectID }) {
            // 가계부 탭에서 고른 여행이 있으면 그것부터 본다.
            selectedTravel = travels.first { $0.objectID == mainVM.selectedTravelInExpense?.objectID }
                ?? travels.first
        }
        refreshToken = UUID()
    }
}
