//
//  ReceiptRow.swift
//  Mwallet
//
//  목록 한 줄. 썸네일과 본문이 서로 다른 곳으로 간다.
//    썸네일 → 사진 첨부 (미첨부일 때)
//    본문   → 상세 화면
//  그래서 한 덩어리로 묶지 않고 두 조각으로 나눠 둔다.
//

import SwiftUI

// MARK: - 썸네일

struct ReceiptThumbnail: View {

    let receipt: Receipt
    let onTapWhenMissing: () -> Void

    private let side: CGFloat = 40

    var body: some View {
        if receipt.needsPhoto {
            Button(action: onTapWhenMissing) {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color.gray300,
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                    )
                    .frame(width: side, height: side)
                    .overlay {
                        Image(systemName: "camera")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray400)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("영수증 사진 첨부")
        } else if let data = receipt.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - 본문

struct ReceiptRowContent: View {

    let receipt: Receipt
    var showsMission: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.merchantName)
                    .font(.subhead2_2_fixed)
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(metaLine)
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(receipt.formattedAmount)
                    .font(.subhead2_1_fixed)
                    .foregroundStyle(.black)
                    .monospacedDigit()

                secondaryLine
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var secondaryLine: some View {
        if receipt.currencyCode != ReceiptCurrency.base {
            if receipt.needsExchangeRate {
                Text("환율 없음")
                    .font(.caption1_fixed)
                    .foregroundStyle(.mainOrange)
            } else {
                Text(receipt.formattedAmountInKRW)
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
                    .monospacedDigit()
            }
        } else {
            Text(receipt.formattedTimeOnly)
                .font(.caption1_fixed)
                .foregroundStyle(.gray300)
        }
    }

    // 시각은 넣지 않는다. 시간대 약어까지 붙으면 줄이 넘쳐 상호명이 잘린다.
    private var metaLine: String {
        var parts = [receipt.categoryName]
        if showsMission { parts.append(receipt.missionTitle) }
        return parts.joined(separator: " · ")
    }
}
