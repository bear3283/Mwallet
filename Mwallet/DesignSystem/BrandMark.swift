//
//  BrandMark.swift
//  Mwallet
//
//  브랜드 마크 'M'. Mission wallet 의 M 이다.
//
//  아이콘(docs/app-icon.swift)과 같은 글자를 그린다. 아이콘이 W 에서 지갑과
//  M 으로 바뀌었는데 이 화면만 한동안 W 를 긋고 있었다 — 아이콘을 눌러 들어온
//  사람에게 첫 화면이 다른 글자를 그려 보이면, 두 마크가 서로 남처럼 읽힌다.
//
//  예전에는 뒤에 와이어프레임 지구본이 있었다. 글자를 키우면서 걷어냈다 —
//  아이콘이 먼저 할 일은 뜻을 설명하는 것이 아니라 한눈에 골라지는 것이고,
//  여행이라는 뜻은 앱 안의 지도와 여행 탭이 맡는다.
//
//  아래 값을 고칠 때는 docs/app-icon.swift 도 함께 고쳐야 둘의 인상이
//  어긋나지 않는다. 아이콘은 PNG 한 장이라 코드를 공유할 수 없다.
//

import SwiftUI

enum BrandMarkGeometry {

    /// M 의 다섯 꼭짓점. 0~1 정규화 좌표라 어떤 크기로 그려도 비율이 유지된다.
    ///
    /// 왼쪽 아래에서 시작해 위로 긋고, 가운데로 내려왔다가, 다시 위로 올라
    /// 오른쪽 아래로 내린다. 손으로 M 을 쓰는 차례 그대로다 — 스플래시에서
    /// 획이 그어지는 애니메이션이 이 차례를 따라가므로 순서에 뜻이 있다.
    ///
    /// 가운데 골은 바닥까지 내리지 않는다(0.62). 끝까지 내리면 네 획이 고르게
    /// 촘촘해져 M 이 아니라 지그재그로 읽힌다. 아이콘의 M 과 같은 이유다.
    ///
    /// 값은 아이콘 M 이 가진 두 비율을 그대로 지켜 이 정사각 화면에 키워 넣은
    /// 것이다 — 획틀의 가로세로비(1.479)와, 획틀 높이 대비 굵기(0.30).
    /// 아이콘에서는 M 이 지갑 몸통 안에 작게 들어앉지만 여기서는 화면을 채운다.
    /// 크기만 다르고 글자꼴은 같다.
    static let walletPoints: [CGPoint] = [
        CGPoint(x: 0.0843, y: 0.7810),
        CGPoint(x: 0.0843, y: 0.2190),
        CGPoint(x: 0.5000, y: 0.5674),
        CGPoint(x: 0.9157, y: 0.2190),
        CGPoint(x: 0.9157, y: 0.7810)
    ]

    static let walletLineWidth: CGFloat = 0.1686
}

// MARK: - M

struct WalletMark: Shape {

    /// 획이 그어지는 진행도. 스플래시에서 0 → 1 로 애니메이션한다.
    var progress: CGFloat = 1

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = BrandMarkGeometry.walletPoints.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path.trimmedPath(from: 0, to: max(0, min(1, progress)))
    }
}

// MARK: - 마크

struct BrandMarkView: View {

    /// 획이 그어지는 진행도.
    var progress: CGFloat = 1
    var color: Color = .white

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            WalletMark(progress: progress)
                .stroke(color,
                        style: StrokeStyle(lineWidth: BrandMarkGeometry.walletLineWidth * side,
                                           lineCap: .round,
                                           lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.mainAccent, Color(0x17307F)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        BrandMarkView()
            .frame(width: 200, height: 200)
    }
}
