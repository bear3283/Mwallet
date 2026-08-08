//
//  VoiceParsingPrimitivesTests.swift
//  MwalletTests
//
//  음성 문장을 숫자로 읽어내는 밑바탕 조각들.
//  이 판정이 틀어지면 금액이 통째로 잘못 잡히므로 경계를 하나씩 고정한다.
//

import XCTest
@testable import Mwallet

final class VoiceParsingPrimitivesTests: XCTestCase {

    // MARK: - 글자 하나의 성격

    func test_아라비아_숫자와_구두점을_가른다() {
        XCTAssertEqual(Character("0").getCharacterForm(), .arabicNumeric)
        XCTAssertEqual(Character("9").getCharacterForm(), .arabicNumeric)
        XCTAssertEqual(Character(",").getCharacterForm(), .arabicComma)
        XCTAssertEqual(Character(".").getCharacterForm(), .arabicDot)
    }

    func test_한글_수사를_가른다() {
        for (index, korean) in ["영", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구"].enumerated() {
            let character = Character(korean)
            XCTAssertEqual(character.getCharacterForm(), .koreanNumeric, "\(korean)")
            XCTAssertEqual(character.getCorrespondingArabicString(), "\(index)", "\(korean)")
        }
    }

    func test_자릿수_글자를_가른다() {
        XCTAssertEqual(Character("만").getCharacterForm(), .koreanFourPower)
        for unit in ["십", "백", "천"] {
            XCTAssertEqual(Character(unit).getCharacterForm(), .korean123Power)
        }
    }

    // 글자 하나만 놓고 보면 '점' 은 소수점 표시다.
    // 낱말 안에서의 판정은 아래 getCharacterFormArray 가 문맥을 보고 정한다.
    func test_점은_글자_하나로는_소수점이다() {
        XCTAssertEqual(Character("점").getCharacterForm(), .koreanDot)
    }

    func test_그_밖의_글자는_숫자가_아니다() {
        for character in ["원", "커", "피", "가", " ", "A"] {
            XCTAssertEqual(Character(character).getCharacterForm(), .notNumeric, "\(character)")
        }
    }

    func test_수사가_아닌_글자는_대응하는_숫자가_없다() {
        XCTAssertEqual(Character("만").getCorrespondingArabicString(), "")
        XCTAssertEqual(Character("원").getCorrespondingArabicString(), "")
    }

    // MARK: - 조각의 성격 판정

    private func variety(_ text: String) -> (SplitVariety, Int) {
        text.getCharacterFormArray().getSplitVarietyAndNumericPrefixCount()
    }

    func test_전부_숫자로_읽히는_조각() {
        XCTAssertEqual(variety("15000").0, .allNumeric)
        XCTAssertEqual(variety("15000").1, 5)

        XCTAssertEqual(variety("사천오백").0, .allNumeric)
        XCTAssertEqual(variety("삼만").0, .allNumeric)
        XCTAssertEqual(variety("12.5").0, .allNumeric)
    }

    // '15000원' 처럼 숫자로 시작해 단위가 붙는 형태.
    // 앞부분 길이를 세어 두었다가 뒤를 잘라낸다.
    func test_숫자로_시작하는_조각은_앞부분_길이를_센다() {
        XCTAssertEqual(variety("15000원").0, .startsWithNumeric)
        XCTAssertEqual(variety("15000원").1, 5)

        XCTAssertEqual(variety("사천오백원").0, .startsWithNumeric)
        XCTAssertEqual(variety("사천오백원").1, 4)
    }

    func test_숫자로_읽을_수_없는_조각() {
        XCTAssertEqual(variety("커피").0, .noNumericInterpretation)
        XCTAssertEqual(variety("커피").1, 0)
        XCTAssertEqual(variety("먹었다").0, .noNumericInterpretation)
    }

    func test_빈_조각은_전부_숫자로_본다() {
        // 글자가 없으면 '숫자가 아닌 글자' 도 없으므로 allNumeric 으로 남는다.
        XCTAssertEqual(variety("").0, .allNumeric)
        XCTAssertEqual(variety("").1, 0)
    }

    // MARK: - 글자별 성격 배열

    func test_문자열을_글자별_성격으로_펼친다() {
        XCTAssertEqual("1만".getCharacterFormArray(), [.arabicNumeric, .koreanFourPower])
        XCTAssertEqual("커피".getCharacterFormArray(), [.notNumeric, .notNumeric])
        XCTAssertEqual("".getCharacterFormArray(), [])
    }

    // MARK: - '점' 은 문맥을 본다

    func test_숫자_뒤의_점만_소수점으로_읽는다() {
        // 사 다음의 점 → 소수점
        XCTAssertEqual("사점오".getCharacterFormArray(),
                       [.koreanNumeric, .koreanDot, .koreanNumeric])
        // 1 다음의 점 → 소수점
        XCTAssertEqual("1점5".getCharacterFormArray(),
                       [.arabicNumeric, .koreanDot, .arabicNumeric])
    }

    func test_낱말_안의_점은_숫자가_아니다() {
        XCTAssertEqual("점심".getCharacterFormArray(), [.notNumeric, .notNumeric])
        XCTAssertEqual("지점".getCharacterFormArray(), [.notNumeric, .notNumeric])
    }

    func test_낱말_안의_점이_들어간_조각은_숫자로_읽히지_않는다() {
        XCTAssertEqual(variety("점심").0, .noNumericInterpretation)
        XCTAssertEqual(variety("사점오").0, .allNumeric)
    }

    // MARK: - 조각 합치기

    func test_조각을_공백으로_잇는다() {
        XCTAssertEqual(["점심", "식사"].getUnifiedStringWithSpaceBetweenEachSplit(), "점심 식사")
        XCTAssertEqual(["하나"].getUnifiedStringWithSpaceBetweenEachSplit(), "하나")
        XCTAssertEqual([].getUnifiedStringWithSpaceBetweenEachSplit(), "")
    }
}
