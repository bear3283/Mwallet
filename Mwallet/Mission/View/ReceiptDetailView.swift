//
//  ReceiptDetailView.swift
//  Mwallet
//
//  영수증 상세. 수정은 AddExpenseView 를 편집 모드로 재사용한다.
//

import SwiftUI

struct ReceiptDetailView: View {

    @Environment(\.dismiss) private var dismiss

    @ObservedObject var receipt: Receipt

    private let store = ReceiptStore()

    @State private var isEditing = false
    @State private var isViewingImage = false
    @State private var isConfirmingDeletion = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let data = receipt.imageData, let image = UIImage(data: data) {
                Section {
                    Button {
                        isViewingImage = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text("사진을 누르면 크게 볼 수 있습니다. \(ReceiptImageProcessor.formattedSize(of: data))")
                }
            }

            amountSection
            detailSection

            Section {
                Button("삭제", role: .destructive) {
                    isConfirmingDeletion = true
                }
            }
        }
        .navigationTitle(receipt.merchantName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("편집") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            AddExpenseView(mode: .edit(receipt))
        }
        .fullScreenCover(isPresented: $isViewingImage) {
            imageViewer
        }
        .confirmationDialog(
            "이 영수증을 삭제할까요?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { delete() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("첨부한 사진도 함께 삭제되며 되돌릴 수 없습니다.")
        }
        .alert("처리하지 못했습니다", isPresented: errorBinding) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 금액

    private var amountSection: some View {
        Section("금액") {
            LabeledContent("결제 금액") {
                Text(receipt.formattedAmount)
                    .monospacedDigit()
            }

            if receipt.currencyCode != ReceiptCurrency.base {
                LabeledContent("원화 환산") {
                    Text(receipt.formattedAmountInKRW)
                        .monospacedDigit()
                }

                if let rate = receipt.validExchangeRate {
                    LabeledContent("적용 환율") {
                        Text("1 \(receipt.currencyCode) = \(ReceiptFormat.exchangeRate(rate))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else {
                    unavailableRateRow
                }
            }
        }
    }

    // 오프라인에서 기록해 환율을 못 받은 건을 되살리는 통로.
    // 목록에서 "합계에서 빠졌습니다" 라고 알리기만 하고 고칠 방법이 없으면 막다른 길이 된다.
    private var unavailableRateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("환율을 받지 못해 원화 합계에서 빠져 있습니다", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)

            Button("현재 환율 적용") { applyCurrentRate() }
                .font(.footnote)

            Text("지출 당일이 아닌 오늘 기준 환율이 적용됩니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 상세

    private var detailSection: some View {
        Section("상세") {
            LabeledContent("사역", value: receipt.missionTitle)
            LabeledContent("카테고리", value: receipt.categoryName)
            LabeledContent("결제 일자", value: receipt.formattedDate())

            if receipt.recordedTimeZone.identifier != TimeZone.current.identifier {
                LabeledContent("기록 지역") {
                    Text(receipt.recordedTimeZone.identifier)
                        .foregroundStyle(.secondary)
                }
            }

            if !receipt.memoText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("메모")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(receipt.memoText)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 사진 전체 화면

    private var imageViewer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let data = receipt.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isViewingImage = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }

    // MARK: - 동작

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private func applyCurrentRate() {
        do {
            try store.applyCurrentExchangeRate(to: receipt)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try store.delete(receipt)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
