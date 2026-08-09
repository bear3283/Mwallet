//
//  TravelExpenseStopTests.swift
//  MwalletTests
//
//  지도 핀과 목록에 붙는 순서 번호.
//  BudgetStore 는 지출을 최신순으로 주는데 번호는 이른 순서라, 뒤집는 지점이 있다.
//

import CoreLocation
import SwiftUI
import UIKit
import XCTest
@testable import Mwallet

final class TravelExpenseStopTests: CoreDataTestCase {

    private let seoul = CLLocationCoordinate2D(latitude: 37.56, longitude: 127.00)
    private let jeju = CLLocationCoordinate2D(latitude: 33.45, longitude: 126.56)

    func test_좌표가_없는_지출은_지도에_올리지_않는다() {
        let expenses = [
            makeExpense(merchant: "좌표 있음", coordinate: seoul),
            makeExpense(merchant: "좌표 없음", coordinate: nil)
        ]

        let stops = TravelExpenseStop.stops(from: expenses)

        XCTAssertEqual(stops.map(\.merchantName), ["좌표 있음"])
    }

    // 번호는 '들른 순서' 다. 목록이 최신순으로 들어와도 이른 순서로 매겨야 한다.
    func test_최신순_입력을_받아도_이른_순서로_번호를_매긴다() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let expenses = [
            makeExpense(merchant: "세 번째", paidAt: base.addingTimeInterval(7_200), coordinate: seoul),
            makeExpense(merchant: "첫 번째", paidAt: base, coordinate: jeju),
            makeExpense(merchant: "두 번째", paidAt: base.addingTimeInterval(3_600), coordinate: seoul)
        ]

        let stops = TravelExpenseStop.stops(from: expenses)

        XCTAssertEqual(stops.map(\.merchantName), ["첫 번째", "두 번째", "세 번째"])
        XCTAssertEqual(stops.map(\.order), [1, 2, 3])
    }

    func test_번호는_1부터_빈_틈_없이_이어진다() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let expenses = (0..<5).map { index in
            makeExpense(merchant: "\(index)",
                        paidAt: base.addingTimeInterval(Double(index) * 600),
                        coordinate: seoul)
        }

        let stops = TravelExpenseStop.stops(from: expenses)

        XCTAssertEqual(stops.map(\.order), [1, 2, 3, 4, 5])
    }

    // 좌표 없는 건이 섞여도 번호는 지도에 올라간 것들끼리만 이어져야 한다.
    func test_좌표_없는_건은_번호를_건너뛰지_않는다() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let expenses = [
            makeExpense(merchant: "A", paidAt: base, coordinate: seoul),
            makeExpense(merchant: "좌표 없음", paidAt: base.addingTimeInterval(600), coordinate: nil),
            makeExpense(merchant: "B", paidAt: base.addingTimeInterval(1_200), coordinate: jeju)
        ]

        let stops = TravelExpenseStop.stops(from: expenses)

        XCTAssertEqual(stops.map(\.merchantName), ["A", "B"])
        XCTAssertEqual(stops.map(\.order), [1, 2], "번호에 구멍이 생기면 지도와 목록이 어긋납니다")
    }

    func test_원화_지출은_금액을_그대로_적는다() {
        let stops = TravelExpenseStop.stops(from: [
            makeExpense(amount: 48_000, currency: "KRW", coordinate: seoul)
        ])

        XCTAssertEqual(stops.first?.amountText, "48,000원")
    }

    func test_외화_지출은_환산액으로_적는다() {
        let stops = TravelExpenseStop.stops(from: [
            makeExpense(amount: 10, currency: "USD", rate: 1_300, coordinate: seoul)
        ])

        XCTAssertEqual(stops.first?.amountText, "13,000원")
    }

    func test_환산할_수_없으면_원래_통화로_적는다() {
        let stops = TravelExpenseStop.stops(from: [
            makeExpense(amount: 10, currency: "USD",
                        rate: Expense.unknownExchangeRate, coordinate: seoul)
        ])

        XCTAssertEqual(stops.first?.amountText, "USD 10")
    }

    func test_카테고리를_그대로_들고_간다() {
        let stops = TravelExpenseStop.stops(from: [
            makeExpense(category: .room, coordinate: seoul)
        ])

        XCTAssertEqual(stops.first?.category, .room)
    }

    // MARK: - 색
    //
    // 카테고리 색을 그대로 쓰면 식비만 다섯 번인 여행에서 다섯 점이 모두
    // 같은 색이 되어, 지도에서 몇 번 핀인지 색으로는 가릴 수 없었다.
    // 같은 카테고리가 거듭될 때마다 그 계열 안에서 다른 색을 준다.

    // 에셋에서 온 색은 화면 설정에 따라 값이 정해지는 동적 색이라, 같은 색을
    // 두 번 집어도 == 로는 같지 않다. 성분을 꺼내 견준다.
    private func components(_ color: Color) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness)
    }

    private func assertSameColor(_ lhs: Color, _ rhs: Color,
                                 _ message: String = "", line: UInt = #line) {
        let left = components(lhs), right = components(rhs)
        XCTAssertEqual(left.hue, right.hue, accuracy: 0.001, message, line: line)
        XCTAssertEqual(left.saturation, right.saturation, accuracy: 0.001, message, line: line)
        XCTAssertEqual(left.brightness, right.brightness, accuracy: 0.001, message, line: line)
    }

    private func sameCategoryStops(_ count: Int) -> [TravelExpenseStop] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return TravelExpenseStop.stops(from: (0..<count).map { index in
            makeExpense(category: .food,
                        merchant: "식당 \(index)",
                        paidAt: base.addingTimeInterval(Double(index) * 600),
                        coordinate: seoul)
        })
    }

    func test_첫_번째는_카테고리_색_그대로다() {
        let stops = sameCategoryStops(1)

        assertSameColor(stops[0].tint, ExpenseInfoCategory.food.color)
    }

    func test_같은_카테고리가_거듭되면_서로_다른_색을_준다() {
        // 성분을 반올림해 묶는다. 색 자체는 동적 색이 섞여 == 로 셀 수 없다.
        let keys = sameCategoryStops(5).map { stop -> String in
            let value = components(stop.tint)
            return String(format: "%.3f/%.3f/%.3f", value.hue, value.saturation, value.brightness)
        }

        XCTAssertEqual(Set(keys).count, 5, "같은 색이 겹치면 지도에서 핀을 가릴 수 없습니다")
    }

    // 색상(hue)까지 돌리면 식비가 교통 색이 되어 카테고리 색이라는 약속이 깨진다.
    func test_색을_바꿔도_같은_계열에_남는다() {
        let base = components(ExpenseInfoCategory.food.color)

        for stop in sameCategoryStops(6) {
            XCTAssertEqual(components(stop.tint).hue, base.hue, accuracy: 0.001,
                           "\(stop.merchantName) 의 색상이 계열을 벗어났습니다")
        }
    }

    // 너무 밝으면 위에 얹은 흰 번호가, 너무 어두우면 지도 바탕이 색을 먹는다.
    func test_번호가_읽히는_밝기_안에_머문다() {
        for stop in sameCategoryStops(6) {
            let value = components(stop.tint)
            // 경계값을 그대로 받도록 아주 작은 여유를 둔다. 0.92 로 묶은 값이
            // 부동소수를 거치며 0.9200000167 로 돌아온다.
            XCTAssertGreaterThan(value.brightness, 0.42 - 0.001, "\(stop.merchantName) 이 너무 어둡습니다")
            XCTAssertLessThan(value.brightness, 0.92 + 0.001, "\(stop.merchantName) 이 너무 밝습니다")
            XCTAssertGreaterThan(value.saturation, 0.30 - 0.001, "\(stop.merchantName) 이 너무 흐립니다")
        }
    }

    // 카테고리가 다르면 차례와 상관없이 각자의 색에서 시작한다.
    func test_카테고리마다_따로_센다() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let stops = TravelExpenseStop.stops(from: [
            makeExpense(category: .food, merchant: "밥", paidAt: base, coordinate: seoul),
            makeExpense(category: .room, merchant: "숙소",
                        paidAt: base.addingTimeInterval(600), coordinate: seoul)
        ])

        assertSameColor(stops[0].tint, ExpenseInfoCategory.food.color)
        assertSameColor(stops[1].tint, ExpenseInfoCategory.room.color)
    }

    // MARK: - 카메라

    func test_지점이_없으면_카메라를_자동에_맡긴다() {
        // .automatic 은 값 비교가 안 되므로, 지점이 있을 때와 다른지로 확인한다.
        let empty = TravelMapCamera.fitted(to: [])
        XCTAssertNil(empty.region, "지점이 없으면 특정 영역을 잡으면 안 됩니다")
    }

    func test_모든_지점이_들어오도록_영역을_잡는다() throws {
        let stops = TravelExpenseStop.stops(from: [
            makeExpense(merchant: "서울", paidAt: Date(timeIntervalSince1970: 1), coordinate: seoul),
            makeExpense(merchant: "제주", paidAt: Date(timeIntervalSince1970: 2), coordinate: jeju)
        ])

        let region = try XCTUnwrap(TravelMapCamera.fitted(to: stops).region)

        // 중심은 두 지점의 가운데.
        XCTAssertEqual(region.center.latitude, (37.56 + 33.45) / 2, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, (127.00 + 126.56) / 2, accuracy: 0.0001)
        // 두 지점이 모두 화면에 들어와야 한다.
        XCTAssertGreaterThan(region.span.latitudeDelta, 37.56 - 33.45)
    }

    func test_지점이_하나면_기본_배율로_본다() throws {
        let stops = TravelExpenseStop.stops(from: [makeExpense(coordinate: seoul)])

        let region = try XCTUnwrap(TravelMapCamera.fitted(to: stops).region)

        XCTAssertEqual(region.span.latitudeDelta, 0.02, accuracy: 0.0001)
    }

    func test_한_지점에_초점을_맞추면_가깝게_본다() throws {
        let stops = TravelExpenseStop.stops(from: [makeExpense(coordinate: jeju)])
        let stop = try XCTUnwrap(stops.first)

        let region = try XCTUnwrap(TravelMapCamera.focused(on: stop).region)

        XCTAssertEqual(region.center.latitude, 33.45, accuracy: 0.0001)
        XCTAssertEqual(region.span.latitudeDelta, 0.01, accuracy: 0.0001)
    }
}
