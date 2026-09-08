//
//  TravelExchangeRate.swift
//  Mwallet · MwalletWidgetExtension
//
//  한 여행 안에서는 환율을 하나로 묶는다.
//
//  ─────────────────────────────────────────────────────────────
//  왜 묶는가
//
//  예전에는 지출마다 그때그때의 환율을 박아 두었다. 정확하기는 한데, 한
//  여행 안에서 환율이 여러 개가 된다. 그러면 사용자가 손으로 검산할 수 없다 —
//  "바트로 3,000 썼는데 왜 원화 합계가 이 숫자지?" 를 풀려면 지출마다 다른
//  환율을 하나씩 들춰 봐야 한다.
//
//  단기사역은 길어야 몇 주다. 그동안의 환율 움직임보다, 돌아와서 정산할 때
//  숫자가 맞아떨어지는 편이 쓸모 있다. 실제로 사람들은 "얼마에 환전했더라"
//  하나로 기억한다.
//
//  그래서 그 여행에서 **처음 적은 환율**을 여행이 끝날 때까지 쓴다.
//  ─────────────────────────────────────────────────────────────
//
//  통화별로 묶는 것이 중요하다. 한 여행이 국경을 넘는 일이 있다 — 베트남에서
//  동으로 적다가 태국으로 넘어가 바트로 적는 여행. 여행 하나에 환율 하나로
//  묶어 버리면 동에 바트 환율이 붙어 스무 배가 넘게 어긋난다.
//
//  이미 적힌 지출은 건드리지 않는다. 저장된 환율을 나중에 고쳐 쓰면 어제 본
//  합계와 오늘 본 합계가 달라진다. 규칙은 새로 적는 것부터 적용된다.
//

import CoreData
import Foundation

enum TravelExchangeRate {

    /// 이 여행이 이 통화로 처음 쓴 환율. 아직 없으면 nil.
    ///
    /// 환율을 받지 못한 지출(unknownExchangeRate)은 건너뛴다. 그것을 기준으로
    /// 삼으면 그 뒤의 모든 지출이 합계에서 빠진다.
    ///
    /// '처음' 은 지출한 날짜 기준이다. 나중에 여행 첫날 영수증을 뒤늦게 적으면
    /// 그것이 새 기준이 되는데, 이미 적힌 것을 고치지는 않으므로 그 뒤로
    /// 적는 것부터 새 기준을 따른다.
    static func anchoredRate(for travel: Travel?, currency: Int64) -> Double? {
        guard let travel else { return nil }
        let expenses = ((travel.expenseArray?.allObjects as? [Expense]) ?? [])
            .filter { $0.currency == currency && $0.exchangeRate > 0 }
            .sorted { ($0.payDate ?? .distantFuture) < ($1.payDate ?? .distantFuture) }
        return expenses.first?.exchangeRate
    }

    // 통화 코드("THB")로 묻는 자리는 앱 타깃에 있다(Expense+Extension).
    // 코드를 번호로 푸는 표(ExpenseCode)가 앱에만 있어서다.
}
