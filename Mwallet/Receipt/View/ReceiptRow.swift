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

    let expense: Expense
    let onTapWhenMissing: () -> Void

    private let side: CGFloat = 40

    var body: some View {
        if expense.needsPhoto {
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
        } else if let data = expense.photoDataList.first, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                // 여러 장이면 몇 장인지 겹쳐 둔다. 줄에서 열지 않고도
                // 뒷면·전표까지 붙어 있는지 알 수 있다.
                .overlay(alignment: .bottomTrailing) {
                    if expense.photoDataList.count > 1 {
                        Text("\(expense.photoDataList.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(3)
                    }
                }
                // 줄 전체가 이미 상호명·금액을 읽어 준다. 사진에 이름이
                // 없으면 소리로는 정체 모를 '이미지' 하나가 끼어든다.
                .accessibilityLabel(photoLabel)
        }
    }

    /// 사진 자리를 소리로 읽는 말. 장수까지 알려 준다.
    private var photoLabel: String {
        let count = expense.photoDataList.count
        return count > 1 ? "영수증 사진 \(count)장" : "영수증 사진"
    }
}

// MARK: - 본문

struct ReceiptRowContent: View {

    let expense: Expense
    var showsMission: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.merchantName)
                    .font(.subhead2_2)
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text(metaLine)
                    .font(.caption1)
                    .foregroundStyle(.gray300)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.formattedAmount)
                    .font(.subhead2_1)
                    .foregroundStyle(.black)
                    .monospacedDigit()

                secondaryLine
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var secondaryLine: some View {
        if expense.currencyCode != ExpenseCode.baseCurrency {
            if expense.needsExchangeRate {
                Text("환율 없음")
                    .font(.caption1)
                    .foregroundStyle(.mainOrange)
            } else {
                Text(expense.formattedAmountInKRW)
                    .font(.caption1)
                    .foregroundStyle(.gray300)
                    .monospacedDigit()
            }
        } else {
            Text(expense.formattedTimeOnly)
                .font(.caption1)
                .foregroundStyle(.gray300)
        }
    }

    // 시각은 넣지 않는다. 시간대 약어까지 붙으면 줄이 넘쳐 상호명이 잘린다.
    private var metaLine: String {
        var parts = [expense.categoryName]
        if showsMission { parts.append(expense.missionTitle) }
        return parts.joined(separator: " · ")
    }
}
