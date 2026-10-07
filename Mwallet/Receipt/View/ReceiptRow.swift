//
//  ReceiptRow.swift
//  Mwallet
//
//  목록 한 줄. 썸네일과 본문이 서로 다른 곳으로 간다.
//    썸네일 → 사진 첨부 메뉴 (미첨부일 때)
//    본문   → 상세 화면
//  그래서 한 덩어리로 묶지 않고 두 조각으로 나눠 둔다.
//

import SwiftUI

// MARK: - 썸네일

struct ReceiptThumbnail: View {

    let expense: Expense
    let onPickLibrary: () -> Void
    let onTakePhoto: () -> Void

    private let side: CGFloat = 40

    var body: some View {
        if expense.needsPhoto {
            // 어디서 가져올지는 누른 자리에서 바로 묻는다. 예전에는 화면에
            // 붙은 선택창을 띄웠는데, 누른 썸네일과 동떨어진 곳에 떠서
            // 무엇에 대한 물음인지 알기 어려웠다. 메뉴는 누른 곳에 붙는다.
            Menu {
                ReceiptPhotoSourceButtons(onPickLibrary: onPickLibrary, onTakePhoto: onTakePhoto)
            } label: {
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
                    // 그림은 40pt 지만 누르는 자리는 44pt 다. 줄 높이는
                    // 그대로 두려고 바깥 여백을 그만큼 되돌린다.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .padding(-2)
            }
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
        return count > 1 ? String(localized: "영수증 사진 \(count)장") : String(localized: "영수증 사진")
    }
}

// MARK: - 사진을 가져올 곳

/// 사진 첨부 메뉴의 항목. 목록의 썸네일과 상세의 첨부 버튼이 함께 쓴다.
///
/// 두 곳의 항목이 따로 적혀 있으면 한쪽만 늘거나 줄기 쉽다 — 상세는
/// 한동안 보관함만 열 수 있었다.
struct ReceiptPhotoSourceButtons: View {

    let onPickLibrary: () -> Void
    let onTakePhoto: () -> Void

    var body: some View {
        Button(action: onPickLibrary) {
            Label("사진 보관함에서 선택", systemImage: "photo.on.rectangle")
        }
        // 카메라가 없는 기기(시뮬레이터 등)에서는 고를 수 없는 항목을 보이지 않는다.
        if CameraPicker.isAvailable {
            Button(action: onTakePhoto) {
                Label("사진 촬영", systemImage: "camera")
            }
        }
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
        var parts = [ExpenseInfoCategory.displayName(forStored: expense.categoryName)]
        if showsMission { parts.append(expense.missionTitle) }
        return parts.joined(separator: " · ")
    }
}
