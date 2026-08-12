//
//  ReceiptListSections.swift
//  Mwallet
//
//  영수증 탭의 아래 두 덩어리 — 합계와 목록.
//
//  ReceiptHomeView 에서 떼어 냈다. 둘 다 이미 걸러진 결과만 받아 그리므로
//  무엇을 어떻게 걸렀는지는 알 필요가 없다. 거르는 일은 그대로 화면의 몫이다.
//

import SwiftUI

// MARK: - 합계

struct ReceiptSummaryBlock: View {

    let summaryValue: ReceiptSummary
    /// 고른 여행 이름. nil 이면 모든 여행을 함께 본다는 뜻이다.
    let missionName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(missionName ?? "전체 여행")
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

            if summaryValue.hasMissingPhoto {
                ReceiptNotice(text: "영수증 사진이 없는 항목이 \(summaryValue.missingPhotoCount)건 있습니다")
                    .padding(.top, 8)
            }

            if summaryValue.hasUnconvertible {
                ReceiptNotice(text: "환율을 받지 못한 \(summaryValue.unconvertibleCount)건은 합계에서 빠졌습니다")
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

// MARK: - 날짜별 목록

struct ReceiptDayList: View {

    let daySections: [ReceiptDaySection]
    let isEmpty: Bool
    /// 여행을 하나로 좁혀 보고 있으면 줄마다 여행 이름을 되풀이하지 않는다.
    let showsMission: Bool
    var onAttachPhoto: (Expense) -> Void
    var onDelete: (Expense) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            if isEmpty {
                ReceiptEmptyState(message: "검색 결과가 없어요")
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
                                ReceiptThumbnail(expense: expense) {
                                    onAttachPhoto(expense)
                                }
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
