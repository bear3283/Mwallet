//
//  KoreanNumberReaderTests.swift
//  MwalletTests
//
//  글자 배열 → 수. 화면도 코어 데이터도 끼지 않는 순수 계산이라
//  문장을 거치지 않고 경계값을 바로 찌를 수 있다.
//

import XCTest
@testable import Mwallet

final class KoreanNumberReaderTests: XCTestCase {

    private func read(_ text: String) -> Double {
        KoreanNumberReader.read(text.unicodeScalars.map(String.init))
    }

    // MARK: - 자리 쌓기

    func test_수사와_자릿수를_곱해_쌓는다() {
        XCTAssertEqual(read("사천오백"), 4_500)
        XCTAssertEqual(read("이십사"), 24)
        XCTAssertEqual(read("삼만"), 30_000)
    }

    // "천원" 은 1000원이다. 앞에 수사가 없으면 자릿수 그 자체로 읽는다.
    func test_자릿수만_말하면_그_자릿수로_읽는다() {
        XCTAssertEqual(read("십"), 10)
        XCTAssertEqual(read("백"), 100)
        XCTAssertEqual(read("천"), 1_000)
        XCTAssertEqual(read("만"), 10_000)
    }

    func test_만_앞의_수사만큼_만_배가_된다() {
        XCTAssertEqual(read("이만"), 20_000)
        XCTAssertEqual(read("십만"), 100_000)
        XCTAssertEqual(read("십오만"), 150_000)
    }

    func test_만_뒤에_남은_수를_더한다() {
        XCTAssertEqual(read("만오천"), 15_000)
        XCTAssertEqual(read("삼만오천"), 35_000)
    }

    func test_아라비아_숫자를_이어_붙인다() {
        XCTAssertEqual(read("15000"), 15_000)
        XCTAssertEqual(read("3만"), 30_000)
    }

    // MARK: - 소수

    func test_소수점_뒤를_읽는다() {
        XCTAssertEqual(read("12.5"), 12.5, accuracy: 0.001)
        XCTAssertEqual(read("삼점일사"), 3.14, accuracy: 0.001)
    }

    func test_소수는_둘째_자리에서_끊는다() {
        XCTAssertEqual(read("12.3456"), 12.34, accuracy: 0.001)
    }

    func test_소수점으로_끝나면_소수부가_없다() {
        XCTAssertEqual(read("12."), 12)
    }

    // MARK: - 여러 번 말한 표시

    // 자릿수 표시는 가장 앞의 하나만 센다.
    func test_소수점을_두_번_말하면_앞의_것만_쓴다() {
        XCTAssertEqual(read("1.2.3"), 1.23, accuracy: 0.001)
    }

    // MARK: - 어긋난 순서

    // "12.5만" 처럼 '만' 이 소수점 뒤로 가면 자릿수로 읽지 않는다.
    // 결과가 사람의 뜻(125000)과 다르지만, 적어도 앱이 죽지는 않는다.
    // 옮겨 오기 전에는 자리 번호가 정수부 길이를 넘어 범위 밖을 짚었다.
    func test_만이_소수점_뒤에_오면_자릿수로_읽지_않는다() {
        XCTAssertEqual(read("12.5만"), 120_000.5, accuracy: 0.001)
    }

    // 아직 읽지 못하는 자리다. "백이십삼만" 처럼 수사로 말하면 제대로 읽힌다.
    func test_만_앞에_다섯_자리를_넘는_수는_아직_읽지_못한다() {
        XCTAssertEqual(read("123456만"), 10_000)
        XCTAssertEqual(read("백이십삼만"), 1_230_000)
    }

    // MARK: - 빈 입력

    func test_읽을_글자가_없으면_영이다() {
        XCTAssertEqual(KoreanNumberReader.read([]), 0)
        XCTAssertEqual(read("원"), 0)
    }
}
