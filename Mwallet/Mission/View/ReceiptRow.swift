//
//  ReceiptRow.swift
//  Mwallet
//
//  목록 한 줄. 사역 이름은 상위에서 이미 필터링된 경우 감출 수 있다.
//

import SwiftUI

struct ReceiptRow: View {

    let receipt: Receipt
    var showsMission: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.merchantName)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(receipt.categoryName)
                    if showsMission {
                        Text("·")
                        Text(receipt.missionTitle).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !receipt.memoText.isEmpty {
                    Text(receipt.memoText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(receipt.formattedAmount)
                    .font(.body)
                    .monospacedDigit()

                if receipt.currencyCode != ReceiptCurrency.base {
                    if receipt.needsExchangeRate {
                        Label("환율 없음", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Text(receipt.formattedAmountInKRW)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Text(receipt.formattedTimeOnly)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = receipt.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
