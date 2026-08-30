//
//  ReceiptCSVEncoderTests.swift
//  MwalletTests
//
//  내보낸 CSV 는 재정 담당자가 단체에 제출하는 파일이다.
//  열이 밀리거나 수식이 실행되면 그대로 회계 오류가 된다.
//

import CoreData
import XCTest
@testable import Mwallet

final class ReceiptCSVEncoderTests: XCTestCase {

    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = PersistenceController(inMemory: true).container
        context = container.viewContext
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    @discardableResult
    private func makeExpense(merchant: String, memo: String = "", amount: Double = 1000) -> Expense {
        let expense = Expense(context: context)
        expense.info = merchant
        expense.memo = memo
        expense.payAmount = amount
        expense.currency = ExpenseCode.currencyIndex(for: "KRW")
        expense.exchangeRate = 1
        expense.payDate = Date(timeIntervalSince1970: 1_700_000_000)
        expense.timeZoneIdentifier = "Asia/Seoul"
        return expense
    }

    private func encodedText(_ expenses: [Expense]) throws -> String {
        let data = ReceiptCSVEncoder.encode(expenses)
        // 앞 3바이트는 BOM.
        return try XCTUnwrap(String(data: data.dropFirst(3), encoding: .utf8))
    }

    func test_윈도우_엑셀을_위해_BOM_을_붙인다() {
        let data = ReceiptCSVEncoder.encode([])

        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
    }

    // 머리글은 기기 언어를 따른다. 이 테스트는 한국어 기기에서 도는 것을 전제로
    // 적혀 있고, '결제 일자' 는 화면의 항목 이름과 같은 문자열을 나눠 쓴다 —
    // 뜻이 같은 말을 두 벌 번역하지 않으려고 하나로 합쳤다.
    func test_헤더만_있어도_유효한_CSV_다() throws {
        let text = try encodedText([])

        XCTAssertTrue(text.hasPrefix("\"\(String(localized: "여행"))\",\"\(String(localized: "결제 일자"))\""),
                      "머리글이 첫 두 칸에 여행·결제 일자로 서야 한다: \(text.prefix(40))")
        XCTAssertTrue(text.hasSuffix("\r\n"))
    }

    // 상호명에 쉼표가 들어가면 따옴표로 감싸야 열이 밀리지 않는다.
    func test_쉼표가_든_값이_열을_밀지_않는다() throws {
        makeExpense(merchant: "카페, 제주점")
        let text = try encodedText(try context.fetch(Expense.fetchRequest()))

        XCTAssertTrue(text.contains("\"카페, 제주점\""))
        // 헤더 1행 + 데이터 1행.
        XCTAssertEqual(text.components(separatedBy: "\r\n").filter { !$0.isEmpty }.count, 2)
    }

    func test_값_안의_따옴표를_두_번_반복해_이스케이프한다() throws {
        makeExpense(merchant: "\"큰따옴표\" 식당")
        let text = try encodedText(try context.fetch(Expense.fetchRequest()))

        XCTAssertTrue(text.contains("\"\"\"큰따옴표\"\" 식당\""))
    }

    // = 로 시작하는 사용자 입력은 스프레드시트가 수식으로 실행한다(CSV 인젝션).
    func test_수식으로_해석될_값_앞에_따옴표를_붙인다() throws {
        makeExpense(merchant: "=1+1", memo: "@SUM(A1:A9)")
        let text = try encodedText(try context.fetch(Expense.fetchRequest()))

        XCTAssertTrue(text.contains("\"'=1+1\""))
        XCTAssertTrue(text.contains("\"'@SUM(A1:A9)\""))
    }

    func test_금액에_천단위_구분자를_넣지_않는다() throws {
        makeExpense(merchant: "식당", amount: 1_234_567)
        let text = try encodedText(try context.fetch(Expense.fetchRequest()))

        // 스프레드시트가 숫자로 인식해야 한다.
        XCTAssertTrue(text.contains("\"1234567.00\""))
        XCTAssertFalse(text.contains("1,234,567"))
    }

    func test_결제일자를_기록_당시_시간대로_적는다() throws {
        makeExpense(merchant: "식당")
        let text = try encodedText(try context.fetch(Expense.fetchRequest()))

        // Asia/Seoul 은 +0900.
        XCTAssertTrue(text.contains("+0900"), "결제일자에 시간대 오프셋이 없습니다: \(text)")
    }

    // MARK: - 파일 이름

    func test_파일_이름에서_경로_문자를_걷어낸다() {
        let name = ReceiptCSVEncoder.fileName(missionName: "제주/워크숍:2024",
                                              now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertTrue(name.hasSuffix(".csv"))
    }

    func test_여행_이름이_없으면_기본_이름을_쓴다() {
        let name = ReceiptCSVEncoder.fileName(missionName: nil,
                                              now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertTrue(name.contains("전체여행"))
    }
}
