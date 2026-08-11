//
//  SettlementSummaryTests.swift
//  MwalletTests
//
//  누가 얼마씩 썼는지 나누는 셈.
//  돈을 다루는 자리라 나머지가 어디로 가는지까지 지킨다.
//

import XCTest
@testable import Mwallet

final class SettlementSummaryTests: CoreDataTestCase {

    // MARK: - 나누기

    func test_함께_쓴_사람_수로_똑같이_나눈다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 30_000, currency: "KRW", participants: ["나", "지훈", "예린"])
        ])

        XCTAssertEqual(summary.shares.count, 3)
        for share in summary.shares {
            XCTAssertEqual(share.amount, 10_000, accuracy: 0.01, share.name)
        }
    }

    func test_여러_지출을_사람별로_모은다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 20_000, currency: "KRW", participants: ["나", "지훈"]),
            makeExpense(amount: 9_000, currency: "KRW", participants: ["나", "지훈", "예린"])
        ])

        let byName = Dictionary(uniqueKeysWithValues: summary.shares.map { ($0.name, $0.amount) })
        XCTAssertEqual(byName["나"] ?? 0, 13_000, accuracy: 0.01)
        XCTAssertEqual(byName["지훈"] ?? 0, 13_000, accuracy: 0.01)
        XCTAssertEqual(byName["예린"] ?? 0, 3_000, accuracy: 0.01)
    }

    func test_낀_건수를_센다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 10_000, currency: "KRW", participants: ["나", "지훈"]),
            makeExpense(amount: 10_000, currency: "KRW", participants: ["나"])
        ])

        let byName = Dictionary(uniqueKeysWithValues: summary.shares.map { ($0.name, $0.expenseCount) })
        XCTAssertEqual(byName["나"], 2)
        XCTAssertEqual(byName["지훈"], 1)
    }

    // 나눈 몫을 다 더하면 나눈 지출의 합과 같아야 한다.
    // 사람 수로 안 떨어지는 금액에서 돈이 새지 않는지 보는 자리다.
    func test_나눈_몫의_합이_원래_금액과_같다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 10_000, currency: "KRW", participants: ["나", "지훈", "예린"])
        ])

        let sum = summary.shares.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(sum, 10_000, accuracy: 0.01, "나누고 더했더니 금액이 달라졌습니다")
        XCTAssertEqual(summary.totalSettled, 10_000, accuracy: 0.01)
    }

    // MARK: - 차례

    func test_많이_진_사람이_먼저_온다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 30_000, currency: "KRW", participants: ["지훈"]),
            makeExpense(amount: 10_000, currency: "KRW", participants: ["나"])
        ])

        XCTAssertEqual(summary.shares.map(\.name), ["지훈", "나"])
    }

    // 같은 금액이면 이름 순서로 둔다. 볼 때마다 자리가 바뀌면 읽기 어렵다.
    func test_금액이_같으면_이름_순서로_둔다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 20_000, currency: "KRW", participants: ["나", "지훈"])
        ])

        XCTAssertEqual(summary.shares.map(\.name), ["나", "지훈"])
    }

    // MARK: - 나누지 못하는 것들

    func test_함께_쓴_사람이_없으면_따로_모은다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 15_000, currency: "KRW", participants: []),
            makeExpense(amount: 5_000, currency: "KRW", participants: ["나"])
        ])

        XCTAssertEqual(summary.unassigned, 15_000, accuracy: 0.01)
        XCTAssertEqual(summary.unassignedCount, 1)
        XCTAssertTrue(summary.hasUnassigned)
        XCTAssertEqual(summary.totalSettled, 5_000, accuracy: 0.01,
                       "나누지 못한 것이 나눈 합에 섞이면 안 됩니다")
    }

    func test_빈_이름은_사람으로_세지_않는다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 10_000, currency: "KRW", participants: ["나", ""])
        ])

        XCTAssertEqual(summary.shares.map(\.name), ["나"])
        XCTAssertEqual(summary.shares.first?.amount ?? 0, 10_000, accuracy: 0.01)
    }

    // 환율을 못 받으면 원화로 옮길 수 없다. 억지로 0으로 두면 합계가 조용히 작아진다.
    func test_환산하지_못한_건은_세어_두고_넘긴다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 10, currency: "USD",
                        rate: Expense.unknownExchangeRate, participants: ["나"]),
            makeExpense(amount: 10_000, currency: "KRW", participants: ["나"])
        ])

        XCTAssertEqual(summary.unconvertibleCount, 1)
        XCTAssertTrue(summary.hasUnconvertible)
        XCTAssertEqual(summary.totalSettled, 10_000, accuracy: 0.01)
    }

    func test_외화는_환산해서_나눈다() {
        let summary = SettlementSummary(expenses: [
            makeExpense(amount: 10, currency: "USD", rate: 1_300, participants: ["나", "지훈"])
        ])

        XCTAssertEqual(summary.shares.first?.amount ?? 0, 6_500, accuracy: 0.01)
    }

    // MARK: - 빈 경우

    func test_지출이_없으면_비어_있다() {
        let summary = SettlementSummary(expenses: [])

        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.totalSettled, 0)
        XCTAssertEqual(summary.largestShare, 0, "막대 길이를 재다 0으로 나누면 안 됩니다")
    }
}
