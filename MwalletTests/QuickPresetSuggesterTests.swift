//
//  QuickPresetSuggesterTests.swift
//  MwalletTests
//
//  위젯 프리셋을 그 여행에서 적어 온 것에서 뽑는 규칙.
//
//  돈이 걸린 자리다. 프리셋은 한 번 누르면 그대로 장부에 적히므로, 금액을
//  잘못 고르면 사용자가 눈치채기 전에 기록이 된다.
//

import XCTest
@testable import Mwallet

final class QuickPresetSuggesterTests: XCTestCase {

    private let day: TimeInterval = 86_400
    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func candidate(_ label: String, _ amount: Double,
                           category: Int = 3, daysAgo: Double = 0) -> QuickPresetCandidate {
        QuickPresetCandidate(label: label, amount: amount, categoryIndex: category,
                            date: now.addingTimeInterval(-daysAgo * day))
    }

    // MARK: - 자주 적은 것 우선

    func test_여러_번_적은_것을_앞세운다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("커피", 60, daysAgo: 3),
            candidate("커피", 60, daysAgo: 2),
            candidate("커피", 60, daysAgo: 1),
            candidate("기념품", 900, category: 5, daysAgo: 0)
        ])

        XCTAssertEqual(presets.first?.label, "커피",
                       "세 번 적은 커피가 어제 한 번 산 기념품보다 앞에 서야 한다")
        XCTAssertEqual(presets.first?.amount, 60)
    }

    func test_같은_횟수면_최근_것을_앞세운다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("점심", 120, daysAgo: 9),
            candidate("점심", 120, daysAgo: 8),
            candidate("저녁", 200, daysAgo: 2),
            candidate("저녁", 200, daysAgo: 1)
        ])

        XCTAssertEqual(presets.first?.label, "저녁")
    }

    // 반복이 세 칸을 못 채우면 최근 것으로 메운다. 빈칸을 두는 것보다 낫다.
    func test_반복이_모자라면_최근_것으로_채운다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("커피", 60, daysAgo: 5),
            candidate("커피", 60, daysAgo: 4),
            candidate("택시", 80, category: 2, daysAgo: 1),
            candidate("물", 20, daysAgo: 3)
        ])

        XCTAssertEqual(presets.count, 3)
        XCTAssertEqual(presets[0].label, "커피", "반복된 것이 먼저")
        XCTAssertEqual(presets[1].label, "택시", "그다음은 최근 것")
        XCTAssertEqual(presets[2].label, "물")
    }

    func test_세_칸까지만_준다() {
        let presets = QuickPresetSuggester.suggest(from: (0..<10).map {
            candidate("항목\($0)", Double(10 * $0 + 10), daysAgo: Double($0))
        })
        XCTAssertEqual(presets.count, 3)
    }

    // MARK: - 금액 고르기

    // 평균이 아니다. 평균은 한 번도 낸 적 없는 금액이 될 수 있다.
    func test_가장_흔한_금액을_쓴다_평균이_아니다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("커피", 60, daysAgo: 4),
            candidate("커피", 60, daysAgo: 3),
            candidate("커피", 60, daysAgo: 2),
            candidate("커피", 250, daysAgo: 1)   // 호텔 라운지에서 한 번
        ])

        XCTAssertEqual(presets.first?.amount, 60,
                       "평균 107.5 는 한 번도 낸 적 없는 금액이다")
    }

    func test_흔한_금액이_같은_횟수면_최근_것을_쓴다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("점심", 100, daysAgo: 4),
            candidate("점심", 150, daysAgo: 1)
        ])
        XCTAssertEqual(presets.first?.amount, 150)
    }

    // MARK: - 묶는 기준

    // '택시' 를 교통으로도 기타로도 적을 수 있다. 이름만으로 묶으면 프리셋이
    // 엉뚱한 분류로 담긴다.
    func test_이름이_같아도_분류가_다르면_따로_센다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("택시", 80, category: 2, daysAgo: 2),
            candidate("택시", 80, category: 9, daysAgo: 1)
        ])

        XCTAssertEqual(presets.count, 2)
        XCTAssertEqual(Set(presets.map(\.categoryIndex)), [2, 9])
    }

    func test_앞뒤_공백과_대소문자는_같은_것으로_본다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("Coffee", 60, daysAgo: 2),
            candidate(" coffee ", 60, daysAgo: 1)
        ])

        XCTAssertEqual(presets.count, 1, "같은 것을 두 칸 차지하게 두면 안 된다")
        XCTAssertEqual(presets.first?.label, "coffee", "가장 최근에 쓴 대로 적는다")
    }

    // MARK: - 거르기

    func test_이름이_없으면_프리셋이_되지_못한다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("", 60), candidate("   ", 60)
        ])
        XCTAssertTrue(presets.isEmpty, "단추에 적을 글자가 없다")
    }

    func test_금액이_0_이하면_거른다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("무료 시식", 0), candidate("환불", -100)
        ])
        XCTAssertTrue(presets.isEmpty)
    }

    // 아직 한 건도 없는 여행. 위젯은 프리셋 대신 안내를 띄운다.
    func test_적은_것이_없으면_빈_배열이다() {
        XCTAssertTrue(QuickPresetSuggester.suggest(from: []).isEmpty)
    }

    // MARK: - 그림

    func test_분류마다_정해진_그림을_얹는다() {
        let presets = QuickPresetSuggester.suggest(from: [
            candidate("점심", 100, category: 3),
            candidate("버스", 20, category: 2),
            candidate("헌금", 50, category: 8)
        ])
        let byLabel = Dictionary(uniqueKeysWithValues: presets.map { ($0.label, $0.emoji) })
        XCTAssertEqual(byLabel["점심"], "🍽")
        XCTAssertEqual(byLabel["버스"], "🚌")
        XCTAssertEqual(byLabel["헌금"], "🤍")
    }

    func test_모르는_분류는_기타_그림을_쓴다() {
        XCTAssertEqual(QuickPresetEmoji.of(categoryIndex: -1), "📝")
        XCTAssertEqual(QuickPresetEmoji.of(categoryIndex: 999), "📝")
    }
}

// MARK: - 담길 곳의 돈

final class QuickLogDestinationFormatTests: XCTestCase {

    // 단추에 적는 돈과 저장되는 돈이 같아야 한다. 예전에는 버튼이 원화를
    // 적어 두고 그 여행의 통화로 저장해, 방콕에서 ₩4,500 짜리 단추가
    // ฿4,500(17만 원)을 적었다.
    func test_통화마다_그_돈으로_적는다() {
        XCTAssertTrue(MwalletSharedFormat.money(60, currencyCode: "THB").contains("60"))
        XCTAssertFalse(MwalletSharedFormat.money(60, currencyCode: "THB").contains("원"),
                       "바트를 원으로 적으면 안 된다")
    }

    // 원화는 예전 그대로 둔다. 한국어에서 '4,500원' 으로 읽어 온 자리다.
    func test_원화는_예전_표기를_지킨다() {
        XCTAssertEqual(MwalletSharedFormat.money(4_500, currencyCode: "KRW"),
                       MwalletSharedFormat.krw(4_500))
    }

    // 위젯은 자리가 좁다. 딱 떨어지는 금액에 소수점을 달지 않는다.
    func test_딱_떨어지면_소수점을_달지_않는다() {
        XCTAssertFalse(MwalletSharedFormat.money(20, currencyCode: "USD").contains(".00"))
    }
}
