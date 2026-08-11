//
//  TravelSettlementSection.swift
//  Mwallet
//
//  여행 상세 맨 아래의 '인원별 정산'.
//
//  여럿이 다니면 한 사람이 몰아서 내는 일이 잦다. 돌아와서 나누려면
//  누가 얼마씩 썼는지를 알아야 하는데, 그 값은 기록할 때 이미 받아 두고
//  있어(함께 쓴 사람) 새로 물을 것이 없다.
//
//  막대는 가장 많이 진 사람을 가득 채운 길이로 그린다. 총액 대비로 그리면
//  사람이 넷만 넘어도 모든 막대가 짧아져 서로 견줄 수 없다.
//

import SwiftUI

struct TravelSettlementSection: View {

    let summary: SettlementSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if summary.isEmpty {
                Text("아직 나눌 지출이 없습니다.\n기록할 때 함께 쓴 사람을 고르면 여기에 나뉩니다.")
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray300)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(summary.shares) { share in
                        row(for: share)
                    }
                }

                notices
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("인원별 정산")
                .font(.subhead1_fixed)
                .foregroundStyle(.gray400)
            Spacer()
            if !summary.isEmpty {
                Text("\(summary.shares.count)명 · \(ReceiptFormat.krw(summary.totalSettled))")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
                    .monospacedDigit()
            }
        }
    }

    private func row(for share: SettlementShare) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(share.name)
                    .font(.subhead2_1_fixed)
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text("\(share.expenseCount)건")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
                    .monospacedDigit()

                Spacer(minLength: 8)

                Text(ReceiptFormat.krw(share.amount))
                    .font(.subhead2_1_fixed)
                    .foregroundStyle(.black)
                    .monospacedDigit()
            }

            bar(for: share)
        }
    }

    private func bar(for share: SettlementShare) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray200)
                Capsule()
                    .fill(Color.mainAccent)
                    .frame(width: geometry.size.width * ratio(for: share))
            }
        }
        .frame(height: 6)
    }

    /// 가장 많이 진 사람을 1로 둔다. 아무도 없으면 0으로 나누지 않도록 막는다.
    private func ratio(for share: SettlementShare) -> Double {
        guard summary.largestShare > 0 else { return 0 }
        return min(max(share.amount / summary.largestShare, 0), 1)
    }

    // 나누지 못한 것들을 숨기지 않는다. 합계가 실제보다 작아 보이는 이유다.
    @ViewBuilder
    private var notices: some View {
        if summary.hasUnassigned {
            Text("함께 쓴 사람이 적히지 않은 \(summary.unassignedCount)건(\(ReceiptFormat.krw(summary.unassigned)))은 나누지 못했습니다")
                .font(.caption1_fixed)
                .foregroundStyle(Color.mainOrange)
        }
        if summary.hasUnconvertible {
            Text("환율을 받지 못한 \(summary.unconvertibleCount)건은 정산에서 빠졌습니다")
                .font(.caption1_fixed)
                .foregroundStyle(Color.mainOrange)
        }
    }
}
