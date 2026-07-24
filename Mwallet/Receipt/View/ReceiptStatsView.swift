//
//  ReceiptStatsView.swift
//  Mwallet
//
//  카테고리별 지출 비율과 CSV 내보내기.
//  집계는 목록 화면과 같은 ReceiptSummary 를 쓴다.
//

import Charts
import SwiftUI

struct ReceiptStatsView: View {

    let receipts: [Receipt]
    let missionName: String?

    private var summary: ReceiptSummary { ReceiptSummary(receipts: receipts) }

    // 기본 목록에 없는 카테고리는 '기타' 로 접어 검증한 색 조합을 유지한다.
    private var slices: [CategoryTotal] {
        var buckets: [String: (amount: Double, count: Int)] = [:]
        for entry in summary.byCategory {
            let key = ReceiptCategoryPalette.bucket(for: entry.category)
            let previous = buckets[key] ?? (0, 0)
            buckets[key] = (previous.amount + entry.amountInKRW, previous.count + entry.count)
        }
        // 링 순서는 색 배정 순서를 따른다. 금액순으로 돌리면 인접쌍이 매번 바뀐다.
        return ReceiptCategoryPalette.order.compactMap { category in
            guard let value = buckets[category], value.amount > 0 else { return nil }
            return CategoryTotal(category: category, amountInKRW: value.amount, count: value.count)
        }
    }

    private var hasFoldedCategories: Bool {
        summary.byCategory.contains { !ReceiptCategoryPalette.order.contains($0.category) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                totalBlock
                    .padding(.top, 16)

                if slices.isEmpty {
                    ReceiptEmptyState(
                        message: "집계할 지출이 없어요",
                        detail: "원화로 환산할 수 있는 기록이 있어야 비율을 낼 수 있습니다."
                    )
                } else {
                    Divider()
                        .padding(.top, 20)

                    ReceiptSectionTitle(text: "카테고리별 비율")
                        .padding(.top, 20)

                    chart

                    breakdown
                }

                Divider()
                    .padding(.top, 12)

                exportBlock
                    .padding(.top, 20)

                // 떠 있는 탭바가 버튼을 가리지 않도록 여유를 둔다.
                Spacer(minLength: 100)
            }
            .padding(.horizontal, ReceiptLayout.gutter)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("통계")
                    .font(.subhead3_1_fixed)
                    .foregroundStyle(.black)
            }
        }
    }

    // MARK: - 총액

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(missionName ?? "전체 사역")
                .font(.caption2_fixed)
                .foregroundStyle(.gray300)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ReceiptFormat.krw(summary.totalInKRW))
                    .font(.display4_fixed)
                    .foregroundStyle(.black)
                    .monospacedDigit()
                Text("\(summary.totalCount)건")
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray300)
            }
            .padding(.top, 6)

            if summary.hasUnconvertible {
                ReceiptNotice(text: "환율을 받지 못한 \(summary.unconvertibleCount)건은 비율 계산에서 빠졌습니다")
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - 원형 차트

    private var chart: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("금액", slice.amountInKRW),
                innerRadius: .ratio(0.64),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(ReceiptCategoryPalette.color(for: slice.category))
        }
        .chartLegend(.hidden)   // 아래 목록이 범례 겸 직접 라벨 역할을 한다
        .frame(height: 200)
        .padding(.vertical, 16)
        .overlay {
            VStack(spacing: 2) {
                Text("총 지출")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
                Text(ReceiptFormat.krw(summary.totalInKRW))
                    .font(.subhead3_1_fixed)
                    .foregroundStyle(.black)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 범례 겸 내역

    // 색상만으로 구분하지 않도록 카테고리명·금액·비율을 함께 적는다.
    // 라이트 모드에서 일부 색은 배경 대비가 낮아 이 표기가 필수다.
    private var breakdown: some View {
        VStack(spacing: 0) {
            ForEach(slices) { slice in
                Divider()
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ReceiptCategoryPalette.color(for: slice.category))
                        .frame(width: 10, height: 10)

                    Text(slice.category)
                        .font(.body1_fixed)
                        .foregroundStyle(.black)

                    Spacer(minLength: 8)

                    Text(ReceiptFormat.krw(slice.amountInKRW))
                        .font(.subhead2_1_fixed)
                        .foregroundStyle(.black)
                        .monospacedDigit()

                    Text("\(percentText(slice.amountInKRW))")
                        .font(.caption1_fixed)
                        .foregroundStyle(.gray300)
                        .monospacedDigit()
                        .frame(width: 46, alignment: .trailing)
                }
                .padding(.vertical, 12)
            }

            if hasFoldedCategories {
                Text("기본 목록에 없는 카테고리는 '기타' 에 합산했습니다.")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - 내보내기

    private var exportBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            ShareLink(item: csvFile, preview: SharePreview(csvFile.fileName)) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("CSV 내보내기")
                }
                .font(.subhead2_1_fixed)
                .foregroundStyle(receipts.isEmpty ? Color.gray300 : Color.black)
                .padding(.vertical, 14.5)
                .frame(maxWidth: .infinity)
                .background(receipts.isEmpty ? Color.gray100 : Color.mainGreen)
                .cornerRadius(12)
            }
            .disabled(receipts.isEmpty)

            Text("영수증 \(receipts.count)건을 표로 내보냅니다. 통화가 섞여 있어도 현지 금액과 적용 환율, 원화 환산액이 각각 들어갑니다.")
                .font(.caption1_fixed)
                .foregroundStyle(.gray300)
        }
    }

    // MARK: - 파생 값

    private var csvFile: ReceiptCSVFile {
        ReceiptCSVFile(
            data: ReceiptCSVEncoder.encode(receipts),
            fileName: ReceiptCSVEncoder.fileName(missionName: missionName)
        )
    }

    private func percentText(_ amount: Double) -> String {
        guard summary.totalInKRW > 0 else { return "0%" }
        let ratio = amount / summary.totalInKRW * 100
        return String(format: "%.1f%%", ratio)
    }
}
