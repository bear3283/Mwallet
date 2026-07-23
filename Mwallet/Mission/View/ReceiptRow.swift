//
//  ReceiptRow.swift
//  Mwallet
//
//  목록 한 줄. 가계부 탭의 항목 행과 같은 타이포·색을 쓴다.
//

import SwiftUI

struct ReceiptRow: View {

    let receipt: Receipt
    var showsMission: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                thumbnail

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
            }
            .padding(.vertical, 12)

            Divider()
        }
        .contentShape(Rectangle())
    }

    // 시각은 넣지 않는다. 시간대 약어까지 붙으면 줄이 넘쳐 상호명이 잘린다.
    // 정확한 시각과 기록 지역은 상세 화면에서 보여준다.
    private var metaLine: String {
        var parts = [receipt.categoryName]
        if showsMission { parts.append(receipt.missionTitle) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = receipt.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray100)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "doc.text")
                        .font(.system(size: 15))
                        .foregroundStyle(.gray300)
                }
        }
    }
}
