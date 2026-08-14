//
//  CategoryColorCheckTests.swift
//  MwalletTests
//
//  고른 색이 다른 분류와 너무 닮았는지 재는 셈.
//
//  이 경고는 사람 대신 판단하지 않는다. 다만 '괜찮다' 고 잘못 말하면
//  그 화면은 색각 이상이 있는 분에게 읽히지 않는 채로 굳는다.
//

import XCTest
@testable import Mwallet

final class CategoryColorCheckTests: XCTestCase {

    // MARK: - 거리

    func test_같은_색은_거리가_0이다() {
        XCTAssertEqual(CategoryColorCheck.distance("2A78D6", "2A78D6"), 0, accuracy: 0.001)
    }

    func test_검정과_흰색이_가장_멀다() {
        let far = CategoryColorCheck.distance("000000", "FFFFFF")

        XCTAssertGreaterThan(far, 99, "Lab 에서 검정↔흰색은 100 언저리여야 합니다")
    }

    // 눈이 느끼는 차이는 RGB 거리와 다르다. 숫자상 같은 폭이라도
    // 색에 따라 다르게 읽혀야 한다.
    func test_같은_RGB_폭이라도_색마다_다르게_잰다() {
        let blue = CategoryColorCheck.distance("0000A0", "0000C0")
        let green = CategoryColorCheck.distance("00A000", "00C000")

        XCTAssertNotEqual(blue, green, accuracy: 0.5)
    }

    // MARK: - 부딪힘

    func test_거의_같은_색이면_알린다() {
        let conflict = CategoryColorCheck.conflict(
            of: "2A78D6", against: [("식비", "2B79D7")])

        XCTAssertEqual(conflict?.name, "식비")
        XCTAssertLessThan(conflict?.distance ?? .infinity, CategoryColorCheck.threshold)
    }

    func test_충분히_다르면_알리지_않는다() {
        XCTAssertNil(CategoryColorCheck.conflict(
            of: "2A78D6", against: [("숙소", "EB6834"), ("헌금", "6E7A18")]))
    }

    // 여럿과 부딪혀도 가장 가까운 하나만 알린다. 목록으로 늘어놓으면 읽지 않는다.
    func test_가장_가까운_하나만_알린다() {
        let conflict = CategoryColorCheck.conflict(
            of: "2A78D6", against: [("가", "3F86DC"), ("나", "2B79D7")])

        XCTAssertEqual(conflict?.name, "나")
    }

    func test_비교할_것이_없으면_알리지_않는다() {
        XCTAssertNil(CategoryColorCheck.conflict(of: "2A78D6", against: []))
    }

    // MARK: - 색각 이상

    // 보통 눈에는 갈리는데 적록색각 이상에서는 붙는 색쌍이 있다.
    // 이 경우를 못 잡으면 경고가 있으나 마나다.
    func test_보통_눈에는_갈려도_적록에서_붙으면_알린다() {
        let red = "C0392B"
        let green = "27772B"

        let plain = CategoryColorCheck.distance(red, green)
        let deutan = CategoryColorCheck.distance(
            CategoryColorCheck.simulate(red, .deuteranopia),
            CategoryColorCheck.simulate(green, .deuteranopia))

        XCTAssertGreaterThan(plain, deutan,
                             "적록색각 이상에서 더 가까워져야 하는 색쌍입니다")

        if let conflict = CategoryColorCheck.conflict(of: red, against: [("초록", green)]) {
            XCTAssertTrue(conflict.onlyForColorVision,
                          "보통 눈에는 갈리는데 색각 이상에서만 붙는 경우로 알려야 합니다")
        }
    }

    func test_흉내_낸_색도_여섯_자리다() {
        for vision in [CategoryColorCheck.Vision.deuteranopia, .protanopia] {
            XCTAssertEqual(CategoryColorCheck.simulate("2A78D6", vision).count, 6)
        }
    }

    // MARK: - 원래 팔레트

    // 붙박이 열 색은 서로 갈리도록 고른 것이었다. 그 성질이 지금 재는 자로도
    // 확인되어야, 이 자가 믿을 만하다는 뜻이 된다.
    func test_원래_팔레트의_이웃끼리는_부딪히지_않는다() {
        let palette = ExpenseInfoCategory.selectable.map {
            (name: $0.description, hex: ReceiptCategoryPalette.storedColor(for: $0.description).light)
        }

        var tooClose: [String] = []
        for (index, entry) in palette.enumerated() {
            let neighbour = palette[(index + 1) % palette.count]
            let gap = CategoryColorCheck.distance(entry.hex, neighbour.hex)
            if gap < CategoryColorCheck.threshold {
                tooClose.append("\(entry.name)↔\(neighbour.name) \(Int(gap))")
            }
        }

        XCTAssertTrue(tooClose.isEmpty, "링에서 붙어 있는 조각이 닮았습니다: \(tooClose)")
    }
}
