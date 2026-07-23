//
//  ReceiptHomeView.swift
//  Mwallet
//
//  영수증 탭. 레이아웃과 타이포그래피는 가계부 탭과 같은 규칙을 따른다.
//  집계는 ReceiptSummary 에 위임해 통계·CSV 화면과 같은 값을 쓴다.
//

import SwiftUI

struct ReceiptHomeView: View {

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)],
        animation: .default
    )
    private var allReceipts: FetchedResults<Receipt>

    private let store = ReceiptStore()

    @State private var filter = ReceiptFilter()
    @State private var isAddingExpense = false
    @State private var deletionTarget: Receipt?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 12)

                searchField
                    .padding(.horizontal, ReceiptLayout.gutter)

                if allReceipts.isEmpty {
                    ReceiptEmptyState(
                        message: "아직 영수증이 없어요",
                        detail: "지출이 생기면 바로 남겨두세요.\n오프라인에서도 저장됩니다."
                    )
                } else {
                    Spacer()
                        .frame(height: 16)

                    missionChips

                    Spacer()
                        .frame(height: 20)

                    summaryBlock
                        .padding(.horizontal, ReceiptLayout.gutter)

                    Spacer()
                        .frame(height: 20)

                    Divider()

                    receiptList
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("영수증")
                        .font(.display1_fixed)
                        .foregroundStyle(.black)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 18) {
                        NavigationLink {
                            ReceiptStatsView(receipts: filtered, missionName: filter.missionName)
                        } label: {
                            Image(systemName: "chart.pie")
                                .foregroundStyle(allReceipts.isEmpty ? Color.gray200 : Color.black)
                        }
                        .disabled(allReceipts.isEmpty)

                        Button {
                            isAddingExpense = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
            .sheet(isPresented: $isAddingExpense) {
                AddReceiptView()
            }
            .confirmationDialog(
                "이 영수증을 삭제할까요?",
                isPresented: deletionBinding,
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) { confirmDeletion() }
                Button("취소", role: .cancel) { deletionTarget = nil }
            } message: {
                Text("첨부한 사진도 함께 삭제되며 되돌릴 수 없습니다.")
            }
            .alert("삭제하지 못했습니다", isPresented: errorBinding) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 검색

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.gray300)
            TextField("상호명, 메모, 카테고리", text: $filter.searchText)
                .font(.body1_fixed)
                .foregroundStyle(.black)
                .tint(.mainPink)
                .autocorrectionDisabled()
            if !filter.searchText.isEmpty {
                Button {
                    filter.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.gray300)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 사역 필터

    private var missionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ReceiptChip(title: "전체", isSelected: filter.missionName == nil) {
                    filter.missionName = nil
                }
                ForEach(missionNames, id: \.self) { name in
                    ReceiptChip(title: name, isSelected: filter.missionName == name) {
                        filter.missionName = name
                    }
                }
            }
            .padding(.horizontal, ReceiptLayout.gutter)
        }
    }

    // MARK: - 합계

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(filter.missionName ?? "전체 사역")
                .font(.caption2_fixed)
                .foregroundStyle(.gray300)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ReceiptFormat.krw(summaryValue.totalInKRW))
                    .font(.display4_fixed)
                    .foregroundStyle(.black)
                    .monospacedDigit()
                Text("\(summaryValue.totalCount)건")
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray300)
            }
            .padding(.top, 6)

            if summaryValue.hasUnconvertible {
                ReceiptNotice(text: "환율을 받지 못한 \(summaryValue.unconvertibleCount)건은 합계에서 빠졌습니다")
                    .padding(.top, 8)
            }

            if summaryValue.byCurrency.count > 1 {
                HStack(spacing: 0) {
                    ForEach(Array(summaryValue.byCurrency.enumerated()), id: \.element.id) { index, entry in
                        Text("\(entry.currency) \(decimalText(entry.amount))")
                            .font(.caption2_fixed)
                            .foregroundStyle(.gray300)
                        if index != summaryValue.byCurrency.count - 1 {
                            Text("·")
                                .font(.caption2_fixed)
                                .foregroundStyle(.gray200)
                                .padding(.horizontal, 6)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - 목록

    private var receiptList: some View {
        ScrollView(showsIndicators: false) {
            if filtered.isEmpty {
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

                        ForEach(section.receipts) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                ReceiptRow(receipt: receipt, showsMission: filter.missionName == nil)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("삭제", role: .destructive) { deletionTarget = receipt }
                            }
                        }
                    }
                }
                .padding(.horizontal, ReceiptLayout.gutter)
                // 떠 있는 탭바가 마지막 항목을 가리지 않도록 여유를 둔다.
                .padding(.bottom, 90)
            }
        }
    }

    // MARK: - 파생 값

    private var filtered: [Receipt] {
        allReceipts.filter { filter.matches($0) }
    }

    private var daySections: [ReceiptDaySection] {
        ReceiptGrouping.byDay(filtered)
    }

    private var summaryValue: ReceiptSummary {
        ReceiptSummary(receipts: filtered)
    }

    private var missionNames: [String] {
        ReceiptGrouping.missionNames(in: Array(allReceipts))
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { deletionTarget != nil },
            set: { isPresented in
                if !isPresented { deletionTarget = nil }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private func decimalText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    // MARK: - 동작

    private func confirmDeletion() {
        guard let target = deletionTarget else { return }
        do {
            try store.delete(target)
        } catch {
            errorMessage = error.localizedDescription
        }
        deletionTarget = nil
    }
}

#Preview {
    ReceiptHomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
