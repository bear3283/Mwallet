//
//  MwalletWidget.swift
//  MwalletWidget  (위젯 익스텐션 타깃)
//
//  위젯 묶음. 각 위젯은 지원 크기를 제한해 둔다.
//   - 예산 위젯:   systemSmall, systemMedium
//   - 결산 위젯:   systemMedium
//   - 기록 위젯:   systemSmall, systemMedium, accessoryCircular
//   - 영수증 위젯: systemSmall, accessoryCircular
//
//  데이터 표시는 App Group 스냅샷(MwalletShared)을 읽고, 기록 위젯의 프리셋은
//  App Group 큐에 담는다(앱이 다음에 열릴 때 Core Data 로 반영).
//
//  공유 계약(MwalletShared 등)은 이 파일 하단에 함께 넣어 위젯 타깃이
//  추가 파일 없이 스스로 컴파일되게 했다. 같은 계약의 앱 쪽 사본은
//  Shared/MwalletShared.swift 에 있다(앱 타깃 전용). 절차는 README-위젯-추가.md.
//

import AppIntents
import Foundation
import SwiftUI
import WidgetKit

// 브랜드 코발트 — 앱 mainAccent 와 같은 값(sRGB #2F5BEA).
private let brandCobalt = Color(red: 0.184, green: 0.357, blue: 0.918)
private let overOrange = Color(red: 1.0, green: 0.42, blue: 0.30)

// MARK: - 스냅샷 타임라인 (예산·결산·영수증 위젯 공용)

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: BudgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: MwalletShared.readSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // 앱이 값을 바꾸면 WidgetCenter.reloadAllTimelines() 로 갱신한다.
        // 그와 별개로 30분마다 한 번 가볍게 재요청한다(폴백).
        let entry = SnapshotEntry(date: Date(), snapshot: MwalletShared.readSnapshot())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))))
    }
}

// MARK: - 정적 타임라인 (기록 위젯의 실행 버튼용)

struct StaticEntry: TimelineEntry {
    let date: Date
}

struct StaticProvider: TimelineProvider {
    func placeholder(in context: Context) -> StaticEntry { StaticEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (StaticEntry) -> Void) {
        completion(StaticEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StaticEntry>) -> Void) {
        completion(Timeline(entries: [StaticEntry(date: Date())], policy: .never))
    }
}

// MARK: - 빠른 기록 인텐트 (위젯 → App Group 큐)

struct LogExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "빠른 지출 기록"
    static let isDiscoverable = false

    @Parameter(title: "금액") var amount: Double
    @Parameter(title: "카테고리") var categoryIndex: Int
    @Parameter(title: "내용") var label: String

    init() {}
    init(amount: Double, categoryIndex: Int, label: String) {
        self.amount = amount
        self.categoryIndex = categoryIndex
        self.label = label
    }

    func perform() async throws -> some IntentResult {
        MwalletShared.enqueue(
            PendingExpense(amount: amount, categoryIndex: categoryIndex,
                           paymentMethodIndex: 0, info: label)
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// 기록 위젯 중형의 프리셋. 자주 쓰는 지출을 한 번에 담는다. (자유롭게 수정 가능)
private struct QuickPreset: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let amount: Double
    let categoryIndex: Int   // ExpenseInfoCategory.rawValue (식비 3, 교통 2)
}

private let quickPresets: [QuickPreset] = [
    QuickPreset(emoji: "☕️", label: "커피", amount: 4500, categoryIndex: 3),
    QuickPreset(emoji: "🍽", label: "식사", amount: 10000, categoryIndex: 3),
    QuickPreset(emoji: "🚌", label: "교통", amount: 3000, categoryIndex: 2)
]

// MARK: - 공통 조각

private struct MiniProgressBar: View {
    let ratio: Double
    let isOver: Bool
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.gray.opacity(0.2))
                Capsule()
                    .fill(isOver ? overOrange : brandCobalt)
                    .frame(width: geo.size.width * min(max(ratio, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

private func snapshotPlaceholder(_ message: String) -> some View {
    VStack(spacing: 6) {
        Image(systemName: "chart.pie")
            .foregroundStyle(.secondary)
        Text(message)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .containerBackground(.background, for: .widget)
}

// MARK: - 예산 위젯

struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot, snapshot.hasBudget {
            content(snapshot)
        } else {
            snapshotPlaceholder("예결산 탭을 한 번 열면\n예산이 표시됩니다")
        }
    }

    private func content(_ snapshot: BudgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.travelName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(MwalletSharedFormat.krw(snapshot.totalSpent))
                .font(.system(size: family == .systemMedium ? 26 : 22, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("집행 · 예산 \(MwalletSharedFormat.krw(snapshot.totalPlanned))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            MiniProgressBar(ratio: snapshot.ratio, isOver: snapshot.isOverspent)

            HStack {
                Text(snapshot.isOverspent
                     ? "\(MwalletSharedFormat.krw(abs(snapshot.remaining))) 초과"
                     : "\(MwalletSharedFormat.krw(snapshot.remaining)) 남음")
                    .foregroundStyle(snapshot.isOverspent ? overOrange : .secondary)
                Spacer()
                Text(MwalletSharedFormat.percent(snapshot.ratio))
                    .foregroundStyle(.primary)
            }
            .font(.caption2)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "mwallet://budget"))
    }
}

struct BudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MwalletBudget", provider: SnapshotProvider()) { entry in
            BudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("예산")
        .description("이번 여행 예산과 집행률을 봅니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 결산 위젯 (중형 전용)

struct SettlementWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        if let snapshot = entry.snapshot, snapshot.hasBudget {
            content(snapshot)
        } else {
            snapshotPlaceholder("예결산 탭을 한 번 열면\n결산이 표시됩니다")
        }
    }

    private func content(_ snapshot: BudgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.travelName)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 4)
                Text(MwalletSharedFormat.krw(snapshot.totalSpent))
                    .font(.system(size: 24, weight: .bold))
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text("/ \(MwalletSharedFormat.krw(snapshot.totalPlanned))")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 8)
                MiniProgressBar(ratio: snapshot.ratio, isOver: snapshot.isOverspent)
                Text(snapshot.isOverspent
                     ? "\(MwalletSharedFormat.krw(abs(snapshot.remaining))) 초과"
                     : "\(MwalletSharedFormat.krw(snapshot.remaining)) 남음")
                    .font(.caption2)
                    .foregroundStyle(snapshot.isOverspent ? overOrange : .secondary)
                    .padding(.top, 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text("카테고리")
                    .font(.caption2).foregroundStyle(.secondary)
                if snapshot.categories.isEmpty {
                    Text("집행 없음").font(.caption2).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(snapshot.categories.prefix(4)), id: \.name) { slice in
                        HStack(spacing: 6) {
                            Text(slice.name).font(.caption2)
                            Spacer(minLength: 4)
                            Text(MwalletSharedFormat.krw(slice.spent))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "mwallet://budget"))
    }
}

struct SettlementWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MwalletSettlement", provider: SnapshotProvider()) { entry in
            SettlementWidgetView(entry: entry)
        }
        .configurationDisplayName("결산")
        .description("예산 대비 집행과 카테고리 내역을 봅니다.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 기록 위젯

struct RecordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StaticEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
            }
            .widgetURL(URL(string: "mwallet://record"))

        case .systemMedium:
            presetGrid

        default:
            smallButton
        }
    }

    private var smallButton: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Text("지출 기록").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Text("눌러서 바로 기록")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(brandCobalt, for: .widget)
        .widgetURL(URL(string: "mwallet://record"))
    }

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("빠른 기록").font(.subheadline).fontWeight(.bold)
                Spacer()
                Link(destination: URL(string: "mwallet://record")!) {
                    HStack(spacing: 3) {
                        Image(systemName: "mic.fill").font(.caption2)
                        Text("직접").font(.caption2)
                    }
                    .foregroundStyle(brandCobalt)
                }
            }
            HStack(spacing: 8) {
                ForEach(quickPresets) { preset in
                    Button(intent: LogExpenseIntent(amount: preset.amount,
                                                    categoryIndex: preset.categoryIndex,
                                                    label: preset.label)) {
                        VStack(spacing: 2) {
                            Text(preset.emoji).font(.title3)
                            Text(preset.label).font(.caption2).foregroundStyle(.primary)
                            Text(MwalletSharedFormat.krw(preset.amount))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }
}

struct RecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MwalletRecord", provider: StaticProvider()) { entry in
            RecordWidgetView(entry: entry)
        }
        .configurationDisplayName("지출 기록")
        .description("눌러서 바로 기록하거나, 프리셋으로 빠르게 담습니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

// MARK: - 영수증 위젯

struct ReceiptWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var count: Int { entry.snapshot?.pendingReceiptCount ?? 0 }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "doc.text").font(.caption)
                    Text("\(count)").font(.caption2).fontWeight(.bold)
                }
            }
            .widgetURL(URL(string: "mwallet://receipt"))

        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(brandCobalt)
            Spacer(minLength: 0)
            if count > 0 {
                Text("\(count)건")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                Text("영수증 미등록")
                    .font(.caption2).foregroundStyle(.secondary)
                Text("눌러서 등록하기")
                    .font(.caption2).foregroundStyle(brandCobalt).padding(.top, 2)
            } else {
                Text("모두 등록됨")
                    .font(.system(size: 17, weight: .bold))
                Text("미등록 영수증 없음")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "mwallet://receipt"))
    }
}

struct ReceiptWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MwalletReceipt", provider: SnapshotProvider()) { entry in
            ReceiptWidgetView(entry: entry)
        }
        .configurationDisplayName("영수증 등록")
        .description("영수증이 아직 없는 지출 수를 보고 바로 등록합니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - 묶음

@main
struct MwalletWidgetBundle: WidgetBundle {
    var body: some Widget {
        BudgetWidget()
        SettlementWidget()
        RecordWidget()
        ReceiptWidget()
    }
}

// MARK: - App Group 공유 계약
//
// MwalletShared·BudgetSnapshot·PendingExpense·MwalletSharedFormat 는
// Shared/MwalletShared.swift 한 곳에만 있고, 앱과 위젯 두 타깃이 그 파일을
// 함께 컴파일한다.
//
// 예전에는 위젯이 스스로 컴파일되도록 같은 정의를 여기에 복사해 두었는데,
// 컴파일러가 두 사본의 불일치를 잡아 주지 못해 키 이름 하나만 어긋나도
// 데이터가 조용히 오가지 않을 수 있었다.
