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
        List {
            totalSection

            if slices.isEmpty {
                Section {
                    ContentUnavailableView(
                        "집계할 지출이 없습니다",
                        systemImage: "chart.pie",
                        description: Text("원화로 환산할 수 있는 기록이 있어야 비율을 낼 수 있습니다.")
                    )
                }
            } else {
                chartSection
                breakdownSection
            }

            exportSection
        }
        .navigationTitle("통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 총액

    private var totalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(missionName ?? "전체 사역")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ReceiptFormat.krw(summary.totalInKRW))
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                Text("\(summary.totalCount)건")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if summary.hasUnconvertible {
                    Label(
                        "환율을 받지 못한 \(summary.unconvertibleCount)건은 비율 계산에서 빠졌습니다",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 원형 차트

    private var chartSection: some View {
        Section("카테고리별 비율") {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("금액", slice.amountInKRW),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(ReceiptCategoryPalette.color(for: slice.category))
            }
            .chartLegend(.hidden)   // 아래 목록이 범례 겸 직접 라벨 역할을 한다
            .frame(height: 220)
            .padding(.vertical, 8)
            .overlay {
                VStack(spacing: 2) {
                    Text("총 지출")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ReceiptFormat.krw(summary.totalInKRW))
                        .font(.headline)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - 범례 겸 내역

    // 색상만으로 구분하지 않도록 카테고리명·금액·비율을 함께 적는다.
    // 라이트 모드에서 일부 색은 배경 대비가 낮아 이 표기가 필수다.
    private var breakdownSection: some View {
        Section {
            ForEach(slices) { slice in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ReceiptCategoryPalette.color(for: slice.category))
                        .frame(width: 12, height: 12)

                    Text(slice.category)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(ReceiptFormat.krw(slice.amountInKRW))
                            .monospacedDigit()
                        Text("\(percentText(slice.amountInKRW)) · \(slice.count)건")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        } footer: {
            if hasFoldedCategories {
                Text("기본 목록에 없는 카테고리는 '기타' 에 합산했습니다.")
            }
        }
    }

    // MARK: - 내보내기

    private var exportSection: some View {
        Section {
            ShareLink(
                item: csvFile,
                preview: SharePreview(csvFile.fileName)
            ) {
                Label("CSV 내보내기", systemImage: "square.and.arrow.up")
            }
            .disabled(receipts.isEmpty)
        } footer: {
            Text("영수증 \(receipts.count)건을 표 형식으로 내보냅니다. 통화가 섞여 있어도 현지 금액과 적용 환율, 원화 환산액이 각각 들어갑니다.")
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
