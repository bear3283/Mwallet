//
//  CategoryColorCheck.swift
//  Mwallet
//
//  고른 색이 다른 분류와 너무 닮았는지 본다.
//
//  왜 필요한가 — 예결산의 도넛은 조각끼리 색으로만 갈린다. 붙어 있는 두
//  조각이 비슷한 색이면 한 덩어리로 보인다. 원래 팔레트 열 색은 그 인접쌍을
//  따져 고른 것이었는데, 사용자가 직접 고르게 되면 그 보장이 사라진다.
//
//  막지는 않는다. 자기 장부의 색은 자기가 정하는 것이고, 우리가 아는 것은
//  '읽기 어려울 수 있다' 까지다. 대신 모르고 지나치지 않게 알린다.
//
//  재는 법 — 눈이 느끼는 차이는 RGB 거리와 다르다. 파랑 계열의 10 차이와
//  초록 계열의 10 차이가 같게 보이지 않는다. 그래서 Lab 으로 옮겨 재고(CIE76),
//  적록색각 이상 두 가지를 흉내 낸 색으로도 한 번씩 더 잰다. 셋 중 가장 가까운
//  값이 그 색쌍의 실제 위험도다.
//

import Foundation

enum CategoryColorCheck {

    /// 이 아래면 '닮았다' 로 본다.
    ///
    /// CIE76 에서 1 은 훈련된 눈이 겨우 알아채는 차이다. 도넛 조각처럼 넓은
    /// 면끼리는 20 을 넘으면 대체로 갈리고, 15 아래로 내려가면 붙여 놨을 때
    /// 헷갈리기 시작한다.
    static let threshold: Double = 15

    struct Conflict: Equatable {
        /// 부딪히는 상대 분류의 이름.
        let name: String
        /// 얼마나 가까운지. 작을수록 닮았다.
        let distance: Double
        /// 보통 눈에는 갈리는데 색각 이상에서만 닮은 경우.
        let onlyForColorVision: Bool
    }

    /// 고른 색이 기존 색들과 부딪히는지. 가장 가까운 하나만 돌려준다.
    ///
    /// 여럿과 부딪혀도 한 번에 하나만 알린다. 목록으로 늘어놓으면 읽지 않는다.
    static func conflict(of candidate: String,
                         against others: [(name: String, hex: String)]) -> Conflict? {
        var worst: Conflict?

        for other in others {
            let plain = distance(candidate, other.hex)
            let deutan = distance(simulate(candidate, .deuteranopia),
                                  simulate(other.hex, .deuteranopia))
            let protan = distance(simulate(candidate, .protanopia),
                                  simulate(other.hex, .protanopia))
            let closest = min(plain, deutan, protan)

            guard closest < threshold else { continue }
            if let worst, worst.distance <= closest { continue }
            worst = Conflict(name: other.name,
                             distance: closest,
                             onlyForColorVision: plain >= threshold)
        }
        return worst
    }

    // MARK: - 눈이 느끼는 거리

    /// CIE76 색차. 두 색을 Lab 으로 옮겨 잰다.
    static func distance(_ lhs: String, _ rhs: String) -> Double {
        let a = lab(of: lhs)
        let b = lab(of: rhs)
        let dl = a.lightness - b.lightness
        let da = a.greenRed - b.greenRed
        let db = a.blueYellow - b.blueYellow
        return (dl * dl + da * da + db * db).squareRoot()
    }

    /// 눈이 느끼는 색 공간의 한 점. 밝기(L)와 두 축(a·b).
    struct LabColor: Equatable {
        let lightness: Double
        let greenRed: Double
        let blueYellow: Double
    }

    /// sRGB → CIE Lab (D65).
    static func lab(of hex: String) -> LabColor {
        let rgb = CategoryColor.components(hex)

        func linear(_ c: CGFloat) -> Double {
            let value = Double(c)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = linear(rgb.red), green = linear(rgb.green), blue = linear(rgb.blue)

        // sRGB → XYZ (D65 백색점으로 나눠 정규화까지 함께)
        let x = (red * 0.4124 + green * 0.3576 + blue * 0.1805) / 0.95047
        let y = (red * 0.2126 + green * 0.7152 + blue * 0.0722) / 1.00000
        let z = (red * 0.0193 + green * 0.1192 + blue * 0.9505) / 1.08883

        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0 / 3) : (7.787 * t) + (16.0 / 116)
        }
        let fx = f(x), fy = f(y), fz = f(z)
        return LabColor(lightness: 116 * fy - 16,
                        greenRed: 500 * (fx - fy),
                        blueYellow: 200 * (fy - fz))
    }

    // MARK: - 색각 이상 흉내

    enum Vision {
        /// 녹색 원뿔세포가 없는 경우. 적록색각 이상 중 가장 흔하다.
        case deuteranopia
        /// 적색 원뿔세포가 없는 경우.
        case protanopia
    }

    /// 그 눈에 보일 색으로 옮긴다. (Brettel/Viénot 계열의 선형 근사)
    static func simulate(_ hex: String, _ vision: Vision) -> String {
        let components = CategoryColor.components(hex)
        let red = Double(components.red)
        let green = Double(components.green)
        let blue = Double(components.blue)

        let simulatedRed: Double
        let simulatedGreen: Double
        let simulatedBlue: Double

        switch vision {
        case .deuteranopia:
            simulatedRed = 0.625 * red + 0.700 * green - 0.325 * blue
            simulatedGreen = 0.700 * red + 0.300 * green
            simulatedBlue = 0.300 * green + 0.700 * blue
        case .protanopia:
            simulatedRed = 0.567 * red + 0.433 * green
            simulatedGreen = 0.558 * red + 0.442 * green
            simulatedBlue = 0.242 * green + 0.758 * blue
        }

        func byte(_ value: Double) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
        return String(format: "%02X%02X%02X",
                      byte(simulatedRed), byte(simulatedGreen), byte(simulatedBlue))
    }
}
