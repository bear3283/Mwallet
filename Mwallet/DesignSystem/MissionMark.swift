//
//  MissionMark.swift
//  Mwallet
//
//  브랜드 마크 'M'.
//  가운데 골짜기를 양옆 획보다 깊게 내려 체크마크로도 읽히게 했다.
//  Mission 의 M 이자 '확인된 지출'의 체크 — 선교 재정 앱의 두 축이다.
//
//  앱 아이콘과 스플래시가 이 좌표를 공유한다. 값을 바꾸면 둘 다 바뀐다.
//

import SwiftUI

struct MissionMark: Shape {

    // 획이 그려지는 진행도. 스플래시에서 0 → 1 로 애니메이션한다.
    var progress: CGFloat = 1

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    // 0~1 정규화 좌표. 어떤 크기로 그려도 비율이 유지된다.
    static let points: [CGPoint] = [
        CGPoint(x: 0.14, y: 0.78),   // 왼쪽 아래
        CGPoint(x: 0.14, y: 0.24),   // 왼쪽 위
        CGPoint(x: 0.50, y: 0.68),   // 가운데 골짜기 (양옆보다 깊다)
        CGPoint(x: 0.86, y: 0.24),   // 오른쪽 위
        CGPoint(x: 0.86, y: 0.78)    // 오른쪽 아래
    ]

    // 획 두께도 크기에 비례시켜 아이콘과 스플래시의 인상을 같게 유지한다.
    static func lineWidth(for size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.155
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = Self.points.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path.trimmedPath(from: 0, to: max(0, min(1, progress)))
    }
}

// MARK: - 브랜드 마크 뷰

struct MissionMarkView: View {

    var progress: CGFloat = 1
    var color: Color = .white

    var body: some View {
        GeometryReader { geometry in
            MissionMark(progress: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: MissionMark.lineWidth(for: geometry.size),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        MissionMarkView()
            .frame(width: 200, height: 200)
    }
}
