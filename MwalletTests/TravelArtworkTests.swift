//
//  TravelArtworkTests.swift
//  MwalletTests
//
//  여행 카드에 무엇을 그릴지 고르는 셈.
//  '사진이 없을 때 무엇을 대신 놓는가' 가 이 파일의 요지다.
//

import XCTest
@testable import Mwallet

final class TravelArtworkTests: CoreDataTestCase {

    // MARK: - 첫 글자

    func test_이름_첫_글자를_딴다() {
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "마닐라 의료팀"), "마")
    }

    // '· 방콕' 처럼 꾸밈으로 시작하면 점 하나만 덩그러니 남는다.
    func test_글자가_아닌_것으로_시작하면_건너뛴다() {
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "· 방콕"), "방")
    }

    // 이름 앞에 표를 붙이는 일이 잦다. 그대로 첫 글자를 따면 '예시: 방콕' 과
    // '예시: 부산' 이 둘 다 '예' 가 되어, 구별하라고 넣은 글자가 다 같아진다.
    func test_쌍점_앞의_표는_건너뛴다() {
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "예시: 방콕 단기사역"), "방")
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "예시: 부산 수련회"), "부")
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "출장: 도쿄"), "도")
    }

    // 연도로 시작하는 이름도 마찬가지다.
    func test_앞머리_숫자보다_글자를_먼저_쓴다() {
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "2026 캠프"), "캠")
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "  2026 방콕"), "방")
    }

    // 글자가 하나도 없으면 그때는 숫자를 쓴다.
    func test_글자가_없으면_숫자를_쓴다() {
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "2026"), "2")
    }

    func test_영문은_대문자로_세운다() {
        XCTAssertEqual(TravelArtworkBuilder.monogram(from: "manila trip"), "M")
    }

    func test_적을_글자가_없으면_그래도_한_글자를_준다() {
        XCTAssertFalse(TravelArtworkBuilder.monogram(from: "···").isEmpty)
        XCTAssertFalse(TravelArtworkBuilder.monogram(from: "").isEmpty)
    }

    // MARK: - 바탕 고르기

    func test_나라를_모르면_글자로_간다() {
        let artwork = TravelArtworkBuilder.artwork(countries: [], name: "다낭 건축봉사")

        XCTAssertEqual(artwork.cover, .monogram("다"))
        XCTAssertTrue(artwork.flagNames.isEmpty)
    }

    // CountryList.csv 의 29개 나라가 'DefaultImage' 한 장을 함께 가리킨다.
    // 그대로 깔면 서로 다른 여행이 같은 카드로 보인다.
    func test_사진이_없다고_적힌_나라도_글자로_간다() {
        // -1('알 수 없음')은 나라 표에 언제나 있고 DefaultImage 를 가리킨다.
        let artwork = TravelArtworkBuilder.artwork(countries: [-1], name: "프놈펜 단기사역")

        XCTAssertEqual(artwork.cover, .monogram("프"),
                       "빈자리 표시를 사진으로 착각하면 안 됩니다")
    }

    func test_사진이_있는_나라는_그_사진을_깐다() throws {
        let country = try XCTUnwrap(
            CountryInfoModel.shared.countryResult
                .first { $0.value.defaultImageString != TravelArtwork.noPhoto }?.key,
            "사진이 딸린 나라가 하나도 없습니다. 나라 표를 확인해 주세요.")

        let artwork = TravelArtworkBuilder.artwork(countries: [country], name: "방콕")

        guard case .photo = artwork.cover else {
            return XCTFail("나라 사진이 있는데 글자로 갔습니다")
        }
    }

    // MARK: - 국기

    func test_지출이_적힌_나라를_최근_순으로_모은다() {
        let travel = makeTravel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        spend(travel, country: 1, at: base)
        spend(travel, country: 2, at: base.addingTimeInterval(86_400))

        XCTAssertEqual(TravelArtworkBuilder.countries(in: travel), [2, 1])
    }

    func test_같은_나라는_한_번만_센다() {
        let travel = makeTravel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for offset in 0..<5 {
            spend(travel, country: 3, at: base.addingTimeInterval(Double(offset) * 86_400))
        }

        XCTAssertEqual(TravelArtworkBuilder.countries(in: travel), [3])
    }

    // 넷을 넘게 겹치면 서로 가려서 어느 나라인지 알아볼 수 없다.
    func test_국기는_넷에서_그친다() {
        let travel = makeTravel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for country in 1...7 {
            spend(travel, country: country, at: base.addingTimeInterval(Double(country) * 86_400))
        }

        XCTAssertEqual(TravelArtworkBuilder.countries(in: travel).count, TravelArtwork.flagLimit)
    }

    func test_지출이_없으면_국기도_없다() {
        XCTAssertTrue(TravelArtworkBuilder.countries(in: makeTravel()).isEmpty)
    }

    /// 나라를 적은 지출 하나. makeExpense 는 나라를 받지 않아 여기서 얹는다.
    private func spend(_ travel: Travel, country: Int, at date: Date) {
        let expense = makeExpense(travel: travel, paidAt: date)
        expense.country = Int64(country)
    }

    // MARK: - 색

    // Swift 의 hashValue 는 실행할 때마다 달라진다. 그것으로 색을 뽑으면
    // 앱을 껐다 켤 때마다 카드 색이 바뀐다.
    func test_같은_이름은_언제나_같은_색이다() {
        let once = TravelPalette.color(for: "마닐라 의료팀")
        let again = TravelPalette.color(for: "마닐라 의료팀")

        XCTAssertEqual(once, again)
    }

    func test_이름이_다르면_색도_대체로_갈린다() {
        let names = ["마닐라 의료팀", "다낭 건축봉사", "치앙마이 교사연수",
                     "프놈펜 단기사역", "울란바토르 캠프", "세부 어린이사역"]

        let distinct = Set(names.map { TravelPalette.color(for: $0).description })

        XCTAssertGreaterThanOrEqual(distinct.count, 3,
                                    "여섯 이름이 색 두 가지로 몰리면 카드가 구별되지 않습니다")
    }
}
