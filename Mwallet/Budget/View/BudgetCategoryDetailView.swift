//
//  BudgetCategoryDetailView.swift
//  Mwallet
//
//  예결산의 한 줄을 눌렀을 때 열리는 화면. 그 분류가 언제 얼마씩 쌓였는지 본다.
//
//  예결산은 '식비 43,264원 / 90,000원' 에서 멈춘다. 그 43,264원이 한 번에
//  나간 것인지 열 번에 걸쳐 쌓인 것인지, 어느 날 몰렸는지는 알 수 없었다.
//  알려면 영수증 탭으로 건너가 분류로 걸러야 했는데, 그러면 예산이라는 맥락을
//  두고 오게 된다.
//
//  날짜별로 묶는 일과 줄을 그리는 일은 영수증 탭이 이미 하고 있다
//  (ReceiptGrouping · ReceiptRowContent · ReceiptSectionTitle). 같은 것을
//  다시 만들지 않고 가져다 쓴다 — 두 벌이 되면 한쪽만 고쳐지는 날이 온다.
//

import CoreData
import SwiftUI

struct BudgetCategoryDetailView: View {

    let travel: Travel
    let line: BudgetLine

    private let store = BudgetStore()

    @State private var sections: [ReceiptDaySection] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                summaryBlock
                    .padding(.top, 12)

                if sections.isEmpty {
                    emptyNotice
                } else {
                    ForEach(sections) { section in
                        daySection(section)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, ReceiptLayout.gutter)
        }
        .background(Color.white)
        .navigationTitle(line.category.description)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    // MARK: - 머리

    /// 예결산에서 보던 값을 그대로 이어 보여 준다.
    ///
    /// 여기까지 눌러 들어온 사람은 방금 그 숫자를 보고 왔다. 다시 적어 주지
    /// 않으면 '내가 누른 게 이거 맞나' 를 확인하러 되돌아가야 한다.
    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ReceiptFormat.krw(line.spent))
                    .font(.display2)
                    .foregroundStyle(.black)
                    .monospacedDigit()

                if line.planned > 0 {
                    Text("/ \(ReceiptFormat.krw(line.planned))")
                        .font(.subhead1)
                        .foregroundStyle(.gray400)
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                Text(BudgetFormat.percent(line.ratio))
                    .font(.subhead2_1)
                    .foregroundStyle(line.isOverspent ? Color.mainOrange : .black)
                    .monospacedDigit()
            }

            // '몇 건' 만으로는 하루에 몰아 쓴 것인지 여러 날에 걸친 것인지 모른다.
            Text(spreadText)
                .font(.caption1)
                .foregroundStyle(.gray400)

            if line.unconvertibleCount > 0 {
                ReceiptNotice(text: "환율을 받지 못한 \(line.unconvertibleCount)건은 합계에서 빠졌습니다")
            }
        }
        .padding(.bottom, 4)
    }

    private var spreadText: String {
        guard !sections.isEmpty else { return "\(line.spentCount)건" }
        return "\(line.spentCount)건 · \(sections.count)일에 걸쳐"
    }

    private var emptyNotice: some View {
        VStack(spacing: 6) {
            Text("아직 이 분류로 적은 지출이 없습니다")
                .font(.subhead1)
                .foregroundStyle(.gray400)
            Text(line.planned > 0 ? "예산만 세워 두고 아직 쓰지 않았습니다" : "예산도 지출도 없습니다")
                .font(.caption1)
                .foregroundStyle(.gray300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - 하루치

    private func daySection(_ section: ReceiptDaySection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ReceiptSectionTitle(
                text: ReceiptFormat.dayTitle(section.day),
                trailing: ReceiptFormat.krwOrDash(section.dayTotal)
            )
            .padding(.top, 20)
            .padding(.bottom, 2)

            ForEach(section.expenses, id: \.objectID) { expense in
                NavigationLink {
                    ReceiptDetailView(expense: expense)
                } label: {
                    ReceiptRowContent(expense: expense)
                }
                .buttonStyle(.plain)

                if expense.objectID != section.expenses.last?.objectID {
                    Divider()
                }
            }
        }
    }

    // MARK: - 불러오기

    private func load() {
        let code = Int64(line.category.rawValue)
        let expenses = store.expenses(for: travel).filter { $0.category == code }
        sections = ReceiptGrouping.byDay(expenses)
    }
}
