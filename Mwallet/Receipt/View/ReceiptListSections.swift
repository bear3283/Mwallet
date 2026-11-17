//
//  ReceiptListSections.swift
//  Mwallet
//
//  영수증 탭의 아래 두 덩어리 — 합계와 목록.
//
//  ReceiptHomeView 에서 떼어 냈다. 둘 다 이미 걸러진 결과만 받아 그리므로
//  무엇을 어떻게 걸렀는지는 알 필요가 없다. 거르는 일은 그대로 화면의 몫이다.
//

import CoreData
import SwiftUI

// MARK: - 합계

struct ReceiptSummaryBlock: View {

    let summaryValue: ReceiptSummary
    /// 고른 여행 이름. nil 이면 모든 여행을 함께 본다는 뜻이다.
    let missionName: String?
    /// 고른 여행의 예산 대비 집행. 여행을 고르지 않았거나, 기간·검색으로
    /// 좁혀 보는 중이면 nil 이다 — 좁힌 합계 옆에 여행 전체의 예산을 두면
    /// 서로 다른 것을 견주게 된다.
    var budget: BudgetSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(missionName ?? String(localized: "전체 여행"))
                .font(.caption2)
                .foregroundStyle(.gray300)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ReceiptFormat.krw(summaryValue.totalInKRW))
                    .font(.display4)
                    .foregroundStyle(.black)
                    .monospacedDigit()
                Text("\(summaryValue.totalCount)건")
                    .font(.caption2)
                    .foregroundStyle(.gray300)
            }
            .padding(.top, 6)

            if let budget, budget.hasBudget {
                BudgetProgressBar(ratio: budget.barRatio, isOver: budget.isOverspent)
                    .padding(.top, 12)

                HStack(spacing: 0) {
                    Text("예산 \(ReceiptFormat.krw(budget.totalPlanned))")
                        .font(.caption2)
                        .foregroundStyle(.gray400)
                    Spacer()
                    Text(BudgetFormat.remaining(budget.remaining))
                        .font(.caption2)
                        .foregroundStyle(budget.isOverspent ? Color.mainOrange : Color.gray400)
                        .monospacedDigit()
                }
                .padding(.top, 8)
            }

            if summaryValue.hasMissingPhoto {
                ReceiptNotice(text: String(localized: "영수증 사진이 없는 항목이 \(summaryValue.missingPhotoCount)건 있습니다"))
                    .padding(.top, 8)
            }

            if summaryValue.hasUnconvertible {
                ReceiptNotice(text: String(localized: "환율을 받지 못한 \(summaryValue.unconvertibleCount)건은 합계에서 빠졌습니다"))
                    .padding(.top, 8)
            }

            if summaryValue.byCurrency.count > 1 {
                HStack(spacing: 0) {
                    ForEach(Array(summaryValue.byCurrency.enumerated()), id: \.element.id) { index, entry in
                        Text("\(entry.currency) \(decimalText(entry.amount))")
                            .font(.caption2)
                            .foregroundStyle(.gray300)
                        if index != summaryValue.byCurrency.count - 1 {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.gray200)
                                .padding(.horizontal, 6)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func decimalText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - 진행 막대

/// 예산 대비 집행을 그리는 막대. 예결산과 영수증이 같은 것을 쓴다.
struct BudgetProgressBar: View {

    let ratio: Double
    let isOver: Bool
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray100)
                Capsule()
                    .fill(isOver ? Color.mainOrange : Color.mainAccent)
                    .frame(width: geometry.size.width * ratio)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - 여행별로 나눠 보기

/// '전체 여행' 을 볼 때 합계 아래에 놓는 여행별 카드.
///
/// 합계 하나만 있으면 여러 여행의 돈이 한 숫자로 뭉쳐, 어느 여행이 예산을
/// 얼마나 썼고 영수증을 몇 장 더 채워야 하는지 알 수 없다. 여행마다 한 칸씩
/// 나눠 보여 주고, 누르면 그 여행만 보는 화면으로 좁힌다.
struct ReceiptTravelBreakdown: View {

    struct Entry: Identifiable {
        let travel: Travel
        let budget: BudgetSummary
        let missingPhotoCount: Int

        var id: NSManagedObjectID { travel.objectID }
    }

    let entries: [Entry]
    var onSelect: (Travel) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entries) { entry in
                    Button {
                        onSelect(entry.travel)
                    } label: {
                        card(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ReceiptLayout.gutter)
        }
    }

    private func card(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.travel.displayName)
                .font(.caption1)
                .foregroundStyle(.gray400)
                .lineLimit(1)

            Text(ReceiptFormat.krw(entry.budget.totalSpent))
                .font(.subhead2_1)
                .foregroundStyle(.black)
                .monospacedDigit()
                .lineLimit(1)
                .padding(.top, 4)

            if entry.budget.hasBudget {
                BudgetProgressBar(ratio: entry.budget.barRatio,
                                  isOver: entry.budget.isOverspent,
                                  height: 5)
                    .padding(.top, 8)

                Text(BudgetFormat.remaining(entry.budget.remaining))
                    .font(.caption1)
                    .foregroundStyle(entry.budget.isOverspent ? Color.mainOrange : Color.gray400)
                    .monospacedDigit()
                    .lineLimit(1)
                    .padding(.top, 6)
            }

            if entry.missingPhotoCount > 0 {
                Text("영수증 없음 \(entry.missingPhotoCount)")
                    .font(.caption1)
                    .foregroundStyle(.gray400)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(width: 150, alignment: .leading)
        .background(Color.gray100, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 날짜별 목록

struct ReceiptDayList: View {

    let daySections: [ReceiptDaySection]
    let isEmpty: Bool
    /// 여행을 하나로 좁혀 보고 있으면 줄마다 여행 이름을 되풀이하지 않는다.
    let showsMission: Bool
    var onPickLibrary: (Expense) -> Void
    var onTakePhoto: (Expense) -> Void
    var onDelete: (Expense) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            if isEmpty {
                ReceiptEmptyState(message: String(localized: "검색 결과가 없어요"))
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(daySections) { section in
                        ReceiptSectionTitle(
                            text: ReceiptFormat.dayTitle(section.day),
                            trailing: ReceiptFormat.krwOrDash(section.dayTotal)
                        )
                        .padding(.top, 20)
                        .padding(.bottom, 2)

                        ForEach(section.expenses) { expense in
                            // 썸네일과 본문의 목적지가 달라 한 링크로 묶지 않는다.
                            HStack(spacing: 12) {
                                ReceiptThumbnail(expense: expense,
                                                 onPickLibrary: { onPickLibrary(expense) },
                                                 onTakePhoto: { onTakePhoto(expense) })
                                NavigationLink {
                                    ReceiptDetailView(expense: expense)
                                } label: {
                                    ReceiptRowContent(expense: expense, showsMission: showsMission)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 12)
                            .contextMenu {
                                Button("삭제", role: .destructive) { onDelete(expense) }
                            }

                            Divider()
                        }
                    }
                }
                .padding(.horizontal, ReceiptLayout.gutter)
                // 떠 있는 탭바가 마지막 항목을 가리지 않도록 여유를 둔다.
                .padding(.bottom, 90)
            }
        }
    }
}
