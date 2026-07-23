//
//  MissionHomeView.swift
//  Mwallet
//
//  사역 재정 탭의 진입점.
//  현재는 AddExpenseView 로 들어가는 통로와 저장 결과 확인만 담당한다.
//  목록·상세·통계 화면은 이후 단계에서 이 자리에 채운다.
//

import SwiftUI

struct MissionHomeView: View {

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)],
        animation: .default
    )
    private var receipts: FetchedResults<Receipt>

    @State private var isAddingExpense = false

    var body: some View {
        NavigationStack {
            List {
                if receipts.isEmpty {
                    ContentUnavailableView(
                        "기록된 영수증이 없습니다",
                        systemImage: "doc.text",
                        description: Text("오른쪽 위 + 를 눌러 첫 영수증을 추가하세요.")
                    )
                } else {
                    ForEach(receipts) { receipt in
                        row(for: receipt)
                    }
                }
            }
            .navigationTitle("사역 재정")
            .toolbar {
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
        }
    }

    private func row(for receipt: Receipt) -> some View {
        HStack(spacing: 12) {
            if let data = receipt.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchantName)
                Text("\(receipt.missionTitle) · \(receipt.categoryName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(receipt.formattedDate(style: .short))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(receipt.formattedAmount)
                if receipt.currencyCode != ReceiptCurrency.base {
                    Text(receipt.formattedAmountInKRW)
                        .font(.caption)
                        .foregroundStyle(receipt.needsExchangeRate ? .orange : .secondary)
                }
            }
        }
    }
}

#Preview {
    MissionHomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
