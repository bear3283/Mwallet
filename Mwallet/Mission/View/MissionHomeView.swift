//
//  MissionHomeView.swift
//  Mwallet
//
//  사역 재정 탭의 목록 대시보드.
//  집계는 ReceiptSummary 에 위임해 통계·CSV 화면과 같은 값을 쓴다.
//

import SwiftUI

struct MissionHomeView: View {

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
            Group {
                if allReceipts.isEmpty {
                    emptyState
                } else {
                    receiptList
                }
            }
            .navigationTitle("사역 재정")
            .searchable(text: $filter.searchText, prompt: "상호명, 메모, 카테고리")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !missionNames.isEmpty {
                        missionMenu
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingExpense = true
                    } label: {
                        Label("지출 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingExpense) {
                AddExpenseView()
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

    // MARK: - 목록

    private var receiptList: some View {
        List {
            Section {
                summaryCard
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            if filtered.isEmpty {
                Section {
                    ContentUnavailableView.search(text: filter.searchText)
                }
            } else {
                ForEach(daySections) { section in
                    Section {
                        ForEach(section.receipts) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                ReceiptRow(receipt: receipt, showsMission: filter.missionName == nil)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("삭제", role: .destructive) {
                                    deletionTarget = receipt
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(ReceiptFormat.dayTitle(section.day))
                            Spacer()
                            Text(ReceiptFormat.krw(section.dayTotal.totalInKRW))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 합계 카드

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(filter.missionName ?? "전체 사역")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(summary.totalCount)건")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(ReceiptFormat.krw(summary.totalInKRW))
                .font(.largeTitle.weight(.semibold))
                .monospacedDigit()

            if summary.hasUnconvertible {
                Label(
                    "환율을 받지 못한 \(summary.unconvertibleCount)건은 합계에서 빠졌습니다",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if summary.byCurrency.count > 1 {
                Divider()
                ForEach(summary.byCurrency) { entry in
                    HStack {
                        Text(entry.currency)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formattedDecimal(entry.amount)) · \(entry.count)건")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - 사역 선택

    private var missionMenu: some View {
        Menu {
            Button {
                filter.missionName = nil
            } label: {
                Label("전체 사역", systemImage: filter.missionName == nil ? "checkmark" : "")
            }
            ForEach(missionNames, id: \.self) { name in
                Button {
                    filter.missionName = name
                } label: {
                    Label(name, systemImage: filter.missionName == name ? "checkmark" : "")
                }
            }
        } label: {
            Label("사역 선택", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        ContentUnavailableView {
            Label("기록된 영수증이 없습니다", systemImage: "doc.text")
        } description: {
            Text("사역 중 지출이 생기면 바로 남겨두세요.\n오프라인에서도 저장됩니다.")
        } actions: {
            Button("첫 영수증 추가") { isAddingExpense = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 파생 값

    private var filtered: [Receipt] {
        allReceipts.filter { filter.matches($0) }
    }

    private var daySections: [ReceiptDaySection] {
        ReceiptGrouping.byDay(filtered)
    }

    private var summary: ReceiptSummary {
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

    private func formattedDecimal(_ value: Double) -> String {
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
    MissionHomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
