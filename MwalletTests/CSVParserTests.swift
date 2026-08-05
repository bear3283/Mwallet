//
//  CSVParserTests.swift
//  MwalletTests
//
//  CSVParser 가 RFC 4180 을 지키는지 확인한다.
//  국가·통화 표를 읽는 유일한 경로라 여기가 틀리면 통화 선택 전체가 어긋난다.
//

import XCTest
@testable import Mwallet

final class CSVParserTests: XCTestCase {

    func test_기본_행과_열을_나눈다() {
        let rows = CSVParser.rows(from: "a,b,c\n1,2,3\n")

        XCTAssertEqual(rows, [["a", "b", "c"], ["1", "2", "3"]])
    }

    // 이 프로젝트가 실제로 겪었던 버그. "[HKD,USD]" 가 두 열로 쪼개지면서
    // 통화가 하나 사라지고 뒤 열이 한 칸씩 밀렸다.
    func test_따옴표로_감싼_필드_안의_쉼표는_구분자가_아니다() {
        let rows = CSVParser.rows(from: "12,Hongkong,\"[HKD,USD]\",HongkongBlurredDefaultImage\n")

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], ["12", "Hongkong", "[HKD,USD]", "HongkongBlurredDefaultImage"])
    }

    func test_이스케이프된_따옴표는_한_개로_되돌린다() {
        let rows = CSVParser.rows(from: "\"그는 \"\"안녕\"\" 이라 했다\",second\n")

        XCTAssertEqual(rows[0][0], "그는 \"안녕\" 이라 했다")
        XCTAssertEqual(rows[0][1], "second")
    }

    func test_따옴표_안의_줄바꿈은_행을_끊지_않는다() {
        let rows = CSVParser.rows(from: "\"첫 줄\n둘째 줄\",b\n")

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0][0], "첫 줄\n둘째 줄")
    }

    // CountryList.csv 는 CRLF, CurrencyList.csv 는 LF 다. 둘 다 받아야 한다.
    func test_CRLF_와_LF_를_모두_받는다() {
        let crlf = CSVParser.rows(from: "a,b\r\nc,d\r\n")
        let lf = CSVParser.rows(from: "a,b\nc,d\n")

        XCTAssertEqual(crlf, lf)
        XCTAssertEqual(crlf, [["a", "b"], ["c", "d"]])
    }

    func test_마지막_줄에_줄바꿈이_없어도_흘리지_않는다() {
        let rows = CSVParser.rows(from: "a,b\nc,d")

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["c", "d"])
    }

    func test_빈_필드를_보존한다() {
        let rows = CSVParser.rows(from: ",b,\n")

        XCTAssertEqual(rows[0], ["", "b", ""])
    }
}
