//
//  CategoryCatalogTests.swift
//  MwalletTests
//
//  분류 표.
//
//  여기서 가장 중요한 것은 '저장된 숫자가 그대로인가' 다. 지출과 예산에는
//  분류가 숫자로 박혀 있어서, 표를 들이면서 그 숫자가 한 칸이라도 밀리면
//  이미 쌓인 기록의 분류가 통째로 바뀐다. 눈으로는 알아채기 어렵다.
//

import CoreData
import XCTest
@testable import Mwallet

final class CategoryCatalogTests: CoreDataTestCase {

    // MARK: - 옮겨 심기

    func test_붙박이_분류를_그대로_옮긴다() {
        CategorySeeder.seedIfNeeded(in: context)

        let rows = CategoryCatalog.all(in: context)
        XCTAssertEqual(rows.count, ExpenseInfoCategory.selectable.count)
        XCTAssertTrue(rows.allSatisfy(\.isBuiltIn))
    }

    // 이 자리가 깨지면 이미 저장된 지출의 분류가 전부 어긋난다.
    func test_옮긴_뒤에도_숫자가_그대로다() {
        CategorySeeder.seedIfNeeded(in: context)

        for category in ExpenseInfoCategory.selectable {
            let code = Int64(category.rawValue)
            XCTAssertEqual(CategoryCatalog.name(code: code, in: context),
                           category.description,
                           "\(category.description) 의 번호 \(code) 가 다른 이름으로 풀립니다")
        }
    }

    func test_색도_팔레트에_있던_그대로다() {
        CategorySeeder.seedIfNeeded(in: context)

        for category in ExpenseInfoCategory.selectable {
            let row = CategoryCatalog.category(code: Int64(category.rawValue), in: context)
            let expected = ReceiptCategoryPalette.storedColor(for: category.description)
            XCTAssertEqual(row?.colorHex, expected.light, category.description)
        }
    }

    // 붙박이가 늘어날 수 있어 매번 확인하지만, 있는 것은 손대지 않는다.
    func test_두_번_심어도_늘지_않는다() {
        CategorySeeder.seedIfNeeded(in: context)
        let first = CategoryCatalog.all(in: context).count

        CategorySeeder.seedIfNeeded(in: context)

        XCTAssertEqual(CategoryCatalog.all(in: context).count, first)
    }

    func test_사용자가_고친_이름을_다시_심지_않는다() throws {
        CategorySeeder.seedIfNeeded(in: context)
        let food = try XCTUnwrap(CategoryCatalog.category(code: 3, in: context))
        food.name = "먹은 것"
        try context.save()

        CategorySeeder.seedIfNeeded(in: context)

        XCTAssertEqual(CategoryCatalog.category(code: 3, in: context)?.name, "먹은 것")
    }

    // MARK: - 새로 만들기

    func test_사용자_분류는_100번대를_받는다() {
        CategorySeeder.seedIfNeeded(in: context)

        let added = CategoryCatalog.add(name: "현지 교통", color: CategoryColor(light: "2A78D6"),
                                        in: context)

        XCTAssertGreaterThanOrEqual(added.code, CategoryCatalog.firstUserCode)
        XCTAssertFalse(added.isBuiltIn)
    }

    // 번호가 겹치면 두 분류가 같은 지출을 서로 제 것이라고 한다.
    func test_새로_만들_때마다_번호가_겹치지_않는다() {
        CategorySeeder.seedIfNeeded(in: context)

        let codes = (1...5).map {
            CategoryCatalog.add(name: "분류 \($0)", color: CategoryColor(light: "112233"),
                                in: context).code
        }

        XCTAssertEqual(Set(codes).count, codes.count)
        XCTAssertEqual(Set(CategoryCatalog.all(in: context).map(\.code)).count,
                       CategoryCatalog.all(in: context).count)
    }

    // MARK: - 지우기

    func test_쓰이지_않는_사용자_분류는_지운다() {
        let added = CategoryCatalog.add(name: "임시", color: CategoryColor(light: "112233"),
                                        in: context)

        CategoryCatalog.remove(added, in: context)

        XCTAssertTrue(CategoryCatalog.all(in: context).isEmpty)
    }

    // 이미 그 숫자로 저장된 지출이 있으면 지우지 않고 감춘다.
    // 표에서 지우면 그 지출의 분류 이름을 풀 수 없다.
    func test_쓰이고_있으면_지우지_않고_감춘다() throws {
        let added = CategoryCatalog.add(name: "현지 교통", color: CategoryColor(light: "112233"),
                                        in: context)
        try context.save()
        makeExpense().category = added.code
        try context.save()

        CategoryCatalog.remove(added, in: context)

        XCTAssertEqual(CategoryCatalog.all(in: context).count, 1, "지워지면 안 됩니다")
        XCTAssertTrue(added.isHidden)
        XCTAssertTrue(CategoryCatalog.visible(in: context).isEmpty)
    }

    func test_붙박이는_쓰이지_않아도_감추기만_한다() throws {
        CategorySeeder.seedIfNeeded(in: context)
        let tour = try XCTUnwrap(CategoryCatalog.category(code: 4, in: context))

        CategoryCatalog.remove(tour, in: context)

        XCTAssertTrue(tour.isHidden)
        XCTAssertEqual(CategoryCatalog.name(code: 4, in: context), "관광",
                       "감춘 뒤에도 옛 기록의 이름은 풀려야 합니다")
    }

    // MARK: - 표에 없는 숫자

    func test_표에_없는_숫자도_이름을_돌려준다() {
        XCTAssertEqual(CategoryCatalog.name(code: 3, in: context), "식비")
        XCTAssertEqual(CategoryCatalog.name(code: 9_999, in: context), "기타")
    }
}
