//
//  TabActionBar.swift
//  Mwallet
//
//  탭 단위 동작 버튼(설정·추가·통계·예산 편집)의 공통 자리와 모양.
//
//  규칙: 탭 단위 동작은 그 화면 '첫 줄의 오른쪽' 에 둔다.
//
//  예전에는 탭마다 제각각이었다. 여행 탭은 설정이 왼쪽·추가가 오른쪽,
//  영수증 탭은 둘 다 오른쪽, 예결산은 제목 줄 안에 있었다. 같은 성격의
//  동작인데 매번 다른 곳을 찾아야 했다.
//
//  네비게이션 툴바 대신 본문 첫 줄에 두는 이유는, 툴바를 쓰면 그만큼
//  빈 밴드가 하나 더 생겨 본문 전체가 아래로 밀리기 때문이다.
//

import SwiftUI

/// 첫 줄 오른쪽에 놓는 아이콘 버튼. 셋 다 같은 크기·색·간격을 쓴다.
struct TabActionIcon: View {

    let systemName: String
    /// 소리로 읽을 이름.
    ///
    /// 붙이지 않으면 VoiceOver 가 기호의 영어 이름을 읽는다 — 설정 버튼이
    /// 'Gear Shape' 로, 통계 버튼이 '파이 차트' 로 읽혔다. 그림에 글자가
    /// 없는 버튼이라 여기서 말해 주지 않으면 뜻이 전해지지 않는다.
    let label: String
    var isEnabled = true

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(isEnabled ? Color.black : Color.gray200)
            // 누르는 자리는 44pt 다. 34pt 였을 때는 엄지로 누르기에 좁았다.
            // 차지하는 폭은 34pt 그대로 두어(양옆 -5) 그림의 자리와 오른쪽
            // 여백 선이 예전과 같다.
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .padding(.horizontal, -5)
            // 화면 테스트가 이 버튼을 이름으로 찾는다. 툴바를 쓰지 않으므로
            // 네비게이션 바에서 순서로 집을 수 없고, 그림에는 글자가 없다.
            .accessibilityIdentifier("tabAction.\(systemName)")
            .accessibilityLabel(label)
    }
}

/// 아이콘이 아니라 글자로 된 동작(예: '예산 편집').
struct TabActionLabel: View {

    let text: String
    var isEnabled = true

    var body: some View {
        Text(text)
            .font(.subhead2_2)
            .foregroundStyle(isEnabled ? Color.mainAccent : Color.gray200)
            .frame(height: 44)
            .contentShape(Rectangle())
    }
}

/// 첫 줄: 왼쪽에 화면을 알려 주는 것, 오른쪽에 동작 버튼들.
struct TabHeaderRow<Leading: View, Actions: View>: View {

    @ViewBuilder var leading: Leading
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leading

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                actions
            }
        }
        .padding(.horizontal, ReceiptLayout.gutter)
    }
}
