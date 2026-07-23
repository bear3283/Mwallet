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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                photo

                amountBlock
                    .padding(.top, 24)

                Divider()
                    .padding(.top, 20)

                MissionSectionTitle(text: "상세")
                    .padding(.top, 20)

                detailBlock
                    .padding(.top, 4)

                Divider()

                Button {
                    isConfirmingDeletion = true
                } label: {
                    Text("영수증 삭제")
                        .font(.body1_fixed)
                        .foregroundStyle(.mainPink)
                        .padding(.vertical, 16)
                }

                // 떠 있는 탭바가 마지막 항목을 가리지 않도록 여유를 둔다.
                Spacer(minLength: 100)
            }
            .padding(.horizontal, MissionLayout.gutter)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(receipt.merchantName)
                    .font(.subhead3_1_fixed)
                    .foregroundStyle(.black)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("편집") { isEditing = true }
                    .font(.subhead2_2_fixed)
                    .foregroundStyle(.black)
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

    // MARK: - 사진

    @ViewBuilder
    private var photo: some View {
        if let data = receipt.imageData, let image = UIImage(data: data) {
            Button {
                isViewingImage = true
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)

            Text("사진을 누르면 크게 볼 수 있어요 · \(ReceiptImageProcessor.formattedSize(of: data))")
                .font(.caption1_fixed)
                .foregroundStyle(.gray300)
                .padding(.top, 8)
        }
    }

    // MARK: - 금액

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(receipt.formattedAmount)
                .font(.display4_fixed)
                .foregroundStyle(.black)
                .monospacedDigit()

            if receipt.currencyCode != ReceiptCurrency.base {
                if let rate = receipt.validExchangeRate {
                    Text("\(receipt.formattedAmountInKRW) · 1 \(receipt.currencyCode) = \(ReceiptFormat.exchangeRate(rate))")
                        .font(.caption2_fixed)
                        .foregroundStyle(.gray300)
                        .padding(.top, 6)
                } else {
                    unavailableRate
                        .padding(.top, 10)
                }
            }
        }
    }

    // 오프라인에서 기록해 환율을 못 받은 건을 되살리는 통로.
    // 목록에서 "합계에서 빠졌습니다" 라고 알리기만 하고 고칠 방법이 없으면 막다른 길이 된다.
    private var unavailableRate: some View {
        VStack(alignment: .leading, spacing: 8) {
            MissionNotice(text: "환율을 받지 못해 원화 합계에서 빠져 있어요")

            Button {
                applyCurrentRate()
            } label: {
                Text("현재 환율 적용")
                    .font(.caption2_fixed)
                    .foregroundStyle(.black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("지출 당일이 아닌 오늘 기준 환율이 적용됩니다.")
                .font(.caption1_fixed)
                .foregroundStyle(.gray300)
        }
    }

    // MARK: - 상세

    private var detailBlock: some View {
        VStack(spacing: 0) {
            MissionValueRow(label: "사역", value: receipt.missionTitle)
            Divider()
            MissionValueRow(label: "카테고리", value: receipt.categoryName)
            Divider()
            MissionValueRow(label: "결제 일자", value: receipt.formattedDate())

            if receipt.recordedTimeZone.identifier != TimeZone.current.identifier {
                Divider()
                MissionValueRow(label: "기록 지역", value: receipt.recordedTimeZone.identifier)
            }

            if !receipt.memoText.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("메모")
                        .font(.body1_fixed)
                        .foregroundStyle(.gray400)
                    Text(receipt.memoText)
                        .font(.body1_fixed)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)
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
