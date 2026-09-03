//
//  SelfParticipantNameTests.swift
//  MwalletTests
//
//  '나' 는 화면 글자처럼 보이지만 지출에 저장되는 값이다.
//
//  함께 쓴 사람을 고르면 이름 문자열이 Expense.participantArray 에 들어가고,
//  정산은 그 문자열로 사람을 묶는다. iCloud 로 다른 기기에도 그대로 건너간다.
//  그래서 저장하는 이름과 화면에 적는 이름을 갈라 두었고, 이 시험은 그 둘이
//  섞이지 않는지를 지킨다.
//

import XCTest
@testable import Mwallet

final class SelfParticipantNameTests: CoreDataTestCase {

    // 저장하는 이름은 기기 언어를 타지 않는다. 여기가 흔들리면 언어를 바꾼
    // 순간 예전 기록의 '나' 와 새 기록의 'Me' 가 서로 다른 사람이 된다.
    func test_저장하는_이름은_번역하지_않는다() {
        XCTAssertEqual(Travel.selfParticipantName, "나",
                       "저장에 쓰는 이름이라 어느 언어에서도 같아야 한다")
    }

    func test_화면에_적을_이름만_기기_언어를_따른다() {
        // 한국어 기기에서는 둘이 같은 글자다. 그래도 쓰임이 달라 따로 둔다.
        XCTAssertEqual(Travel.participantDisplayName(Travel.selfParticipantName),
                       Travel.selfParticipantDisplayName)
    }

    // 사용자가 손수 적은 이름은 건드리지 않는다.
    func test_다른_사람_이름은_그대로_둔다() {
        for name in ["지훈", "예린", "Anna", "간사님"] {
            XCTAssertEqual(Travel.participantDisplayName(name), name)
        }
    }

    // 정산은 저장된 이름으로 묶는다. 화면 이름으로 묶으면 언어를 바꿨을 때
    // 같은 사람이 둘로 갈린다.
    func test_정산은_저장된_이름으로_묶는다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 20_000, currency: "KRW",
                        participants: [Travel.selfParticipantName, "지훈"]),
            makeExpense(amount: 10_000, currency: "KRW",
                        participants: [Travel.selfParticipantName])
        ])

        let byName = Dictionary(uniqueKeysWithValues: summary.shares.map { ($0.name, $0.amount) })
        XCTAssertEqual(byName[Travel.selfParticipantName] ?? 0, 20_000, accuracy: 0.01,
                       "'나' 한 사람으로 묶여야 한다")
        XCTAssertEqual(summary.shares.count, 2)
    }

    // 묶는 열쇠는 저장된 이름이고, 보여 주는 것만 옮긴 이름이다.
    func test_한_몫은_저장된_이름과_보일_이름을_함께_든다() throws {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 10_000, currency: "KRW",
                        participants: [Travel.selfParticipantName])
        ])
        let share = try XCTUnwrap(summary.shares.first)

        XCTAssertEqual(share.name, Travel.selfParticipantName, "묶는 열쇠")
        XCTAssertEqual(share.displayName, Travel.selfParticipantDisplayName, "보여 줄 이름")
        XCTAssertEqual(share.id, Travel.selfParticipantName,
                       "목록의 신원도 저장된 이름이어야 언어를 바꿔도 자리가 흔들리지 않는다")
    }

    // 언어가 바뀌어도 저장된 값은 그대로라, 옛 기록과 새 기록이 한 사람으로
    // 묶인다. 이 시험은 그 상황을 흉내 낸다 — 저장된 '나' 로 적힌 옛 지출과
    // 새 지출이 하나로 모이는지.
    func test_언어가_바뀌어도_같은_사람으로_묶인다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 10_000, currency: "KRW",
                        participants: [Travel.selfParticipantName]),
            makeExpense(amount: 6_000, currency: "KRW",
                        participants: [Travel.selfParticipantName])
        ])

        XCTAssertEqual(summary.shares.count, 1, "'나' 가 둘로 갈리면 안 된다")
        XCTAssertEqual(summary.shares.first?.amount ?? 0, 16_000, accuracy: 0.01)
    }
}

// FirstLaunchSeeder 는 싱글턴이라 시험용 저장소로 몰아넣을 수 없다. 예시
// 데이터가 저장용 '나' 를 담는지는 여기서 확인하지 못하고 코드로만 지킨다 —
// FirstLaunchSeeder.addSampleTrip 의 sharedBy 를 볼 것.
