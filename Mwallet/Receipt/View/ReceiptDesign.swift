//
//  ReceiptDesign.swift
//  Mwallet
//
//  영수증 탭이 나머지 탭과 같은 시각 언어를 쓰도록 맞춘 공용 조각들.
//  새 스타일을 만들지 않고 기존 화면(TodayExpenseView, AllExpenseView,
//  ManualRecordView)에서 쓰는 규칙을 그대로 따른다.
//
//    거터        .padding(.horizontal, 20)
//    수직 리듬    spacing 0 스택 + 명시적 Spacer().frame(height:)
//    금액        display4_fixed / display3_fixed
//    제목        display1_fixed, 항목 제목 subhead3_1_fixed
//    보조 텍스트  caption2_fixed + gray300
//    구분        Divider()
//    강조        mainPink
//

import SwiftUI

enum ReceiptLayout {
    static let gutter: CGFloat = 20
}

// MARK: - 섹션 제목

struct ReceiptSectionTitle: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.subhead1_fixed)
                .foregroundStyle(.gray400)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subhead1_fixed)
                    .foregroundStyle(.gray400)
            }
        }
    }
}

// MARK: - 선택 칩

// 기존 AllExpenseView 의 국가 선택 칩과 같은 규격.
struct ReceiptChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .font(.caption2_fixed)
                .foregroundStyle(isSelected ? Color.white : Color.gray300)
                .background(isSelected ? Color.black : Color.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - 값 표시 행

struct ReceiptValueRow: View {
    let label: String
    let value: String
    var valueColor: Color = .black
    var isMonospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.body1_fixed)
                .foregroundStyle(.gray400)
            Spacer(minLength: 8)
            Group {
                if isMonospaced {
                    Text(value).monospacedDigit()
                } else {
                    Text(value)
                }
            }
            .font(.subhead2_1_fixed)
            .foregroundStyle(valueColor)
            .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - 입력 행

// ManualRecordView 의 gray100 필드 규격을 따른다.
struct ReceiptFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption2_fixed)
                .foregroundStyle(.gray400)
            content
        }
        .padding(.vertical, 10)
    }
}

struct ReceiptTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body1_fixed)
            .foregroundStyle(.black)
            .tint(.mainPink)
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .background(Color.gray100)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension View {
    func receiptField() -> some View { modifier(ReceiptTextFieldStyle()) }
}

// MARK: - 버튼

// ButtonTheme 의 LargeButtonActive 규격을 화면 안에서 쓸 수 있게 옮긴 것.
struct ReceiptPrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subhead2_1_fixed)
                .foregroundStyle(.white)
                .padding(.vertical, 14.5)
                .frame(maxWidth: .infinity)
        }
        .background(isEnabled ? Color.black : Color.gray200)
        .cornerRadius(12)
        .disabled(!isEnabled)
    }
}

// MARK: - 빈 상태

struct ReceiptEmptyState: View {
    let message: String
    var detail: String?

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.subhead3_2_fixed)
                .foregroundStyle(.gray300)
            if let detail {
                Text(detail)
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray300)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 130)
    }
}

// MARK: - 경고 문구

struct ReceiptNotice: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13))
            Text(text)
                .font(.caption1_fixed)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.mainOrange)
    }
}
