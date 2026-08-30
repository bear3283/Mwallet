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
//  데이터 표시는 App Group 스냅샷(MwalletShared)을 읽는다. 기록 위젯의
//  프리셋은 QuickExpenseStore 로 장부에 곧장 적는다 — 장부가 App Group 안에
//  있어 위젯도 같은 파일을 본다. 적지 못하는 경우(담을 여행이 없거나 통화를
//  물려받을 지출이 없을 때)에만 예전처럼 큐에 남고, 앱이 열릴 때 옮겨진다.
//
//  공유 계약(MwalletShared 등)은 Shared/MwalletShared.swift 한 곳에 있고
//  앱과 위젯이 그 파일을 함께 컴파일한다. 사본을 두지 않는 이유는 이 파일
//  하단에 적어 두었다. 타깃에 붙이는 절차는 README-위젯-추가.md.
//

import AppIntents
import Foundation
import SwiftUI
import OSLog
import WidgetKit

// 브랜드 코발트 — 앱 mainAccent 와 같은 값(sRGB #2F5BEA).
private let brandCobalt = Color(red: 0.184, green: 0.357, blue: 0.918)
private let overOrange = Color(red: 1.0, green: 0.42, blue: 0.30)

// MARK: - 스냅샷 타임라인 (예산·결산·영수증 위젯 공용)

// MARK: - 진단 기록
//
// 위젯은 앱과 다른 프로세스에서 돌아 print 가 Xcode 콘솔에 남지 않는다.
// OSLog 로 남기면 기기에서도 뽑을 수 있다:
//
//   log stream --predicate 'subsystem == "com.bear3745.Mwallet.widget"'
//
// 넷 중 어느 위젯이 실제로 조회되는지 보려고 provider 에 이름을 붙였다.
// 갤러리는 목록을 그릴 때 위젯마다 placeholder 를 한 번씩 묻는다 —
// 어떤 위젯의 이름이 아예 안 찍히면 그 위젯은 조회조차 되지 않는 것이다.
enum WidgetLog {
    static let shared = Logger(subsystem: "com.bear3745.Mwallet.widget", category: "lifecycle")
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: BudgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    /// 어느 위젯이 묻는 것인지 구분하려고 받는다. 셋이 같은 provider 를 쓴다.
    let label: String

    func placeholder(in context: Context) -> SnapshotEntry {
        WidgetLog.shared.notice("\(label, privacy: .public) placeholder (\(String(describing: context.family), privacy: .public))")
        return SnapshotEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = MwalletShared.readSnapshot()
        WidgetLog.shared.notice("\(label, privacy: .public) getSnapshot — 스냅샷 \(snapshot == nil ? "없음" : "있음", privacy: .public)")
        completion(SnapshotEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        WidgetLog.shared.notice("\(label, privacy: .public) getTimeline")
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
        // 장부에 곧장 적는다. 적지 못하면 QuickExpenseStore 가 큐에 남기므로
        // 어느 쪽이든 기록은 사라지지 않는다.
        QuickExpenseStore.log(
            PendingExpense(amount: amount, categoryIndex: categoryIndex,
                           paymentMethodIndex: 0, info: label)
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 방금 담은 것을 도로 뺀다.
///
/// 홈 화면의 위젯은 한 번 누르면 그대로 담기는 자리라 잘못 누르기 쉽다.
/// 앱을 열어 지우게 하면 '빠른 기록' 이라는 말이 무색해진다.
struct UndoLastLogIntent: AppIntent {
    static let title: LocalizedStringResource = "방금 담은 것 되돌리기"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        // 장부에 적힌 것이면 그 지출을 지우고, 큐에 남은 것이면 큐에서 뺀다.
        QuickExpenseStore.undoLast()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - 빠른 기록 타임라인

/// 위젯이 화면에 적을 것 — 담길 곳과, 아직 큐에 남아 있는 마지막 기록.
struct QuickLogEntry: TimelineEntry {
    let date: Date
    /// 이 위젯으로 담으면 들어갈 여행의 이름. 앱이 정해서 넘겨 준다.
    let destination: String?
    /// 방금 담은 것. 장부에 적혔든 큐에 남았든 여기로 온다.
    let lastLogged: LoggedRecord?
}

struct QuickLogProvider: TimelineProvider {
    private func read() -> QuickLogEntry {
        QuickLogEntry(date: Date(),
                      destination: MwalletShared.destinationName,
                      lastLogged: MwalletShared.lastLogged)
    }

    func placeholder(in context: Context) -> QuickLogEntry {
        WidgetLog.shared.notice("지출기록 placeholder (\(String(describing: context.family), privacy: .public))")
        return QuickLogEntry(date: Date(), destination: nil, lastLogged: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        WidgetLog.shared.notice("지출기록 getSnapshot")
        completion(read())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        WidgetLog.shared.notice("지출기록 getTimeline")
        // 버튼을 누르면 인텐트가 reloadAllTimelines() 로 곧장 갱신한다.
        // 그와 별개로 한 시간에 한 번 다시 읽는다(앱이 큐를 가져갔을 수 있다).
        completion(Timeline(entries: [read()], policy: .after(Date().addingTimeInterval(3600))))
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
    QuickPreset(emoji: "☕️", label: String(localized: "커피"), amount: 4500, categoryIndex: 3),
    QuickPreset(emoji: "🍽", label: String(localized: "식사"), amount: 10000, categoryIndex: 3),
    QuickPreset(emoji: "🚌", label: String(localized: "교통"), amount: 3000, categoryIndex: 2)
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
            snapshotPlaceholder(String(localized: "예결산 탭을 한 번 열면\n예산이 표시됩니다"))
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
        StaticConfiguration(kind: "MwalletBudget", provider: SnapshotProvider(label: "예산")) { entry in
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
            snapshotPlaceholder(String(localized: "예결산 탭을 한 번 열면\n결산이 표시됩니다"))
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
        StaticConfiguration(kind: "MwalletSettlement", provider: SnapshotProvider(label: "결산")) { entry in
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
    let entry: QuickLogEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
            }
            // iOS 17 부터는 어느 분기든 이걸 선언해야 한다. 없으면 그 분기가
            // 그려지지 않고, 미리보기를 못 그린 위젯은 갤러리에 아예 안 뜬다.
            .containerBackground(.clear, for: .widget)
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
        VStack(alignment: .leading, spacing: 7) {
            header
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
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    /// 첫 줄 — 무엇을 하는 자리인지와, 담기면 어디로 가는지.
    ///
    /// 담길 곳을 적지 않으면 누른 사람은 지금 다니는 여행에 붙는 줄 안다.
    /// 앱을 열고 나서야 딴 곳에 쌓인 것을 알게 된다.
    private var header: some View {
        HStack(spacing: 4) {
            Text("빠른 기록").font(.subheadline).fontWeight(.bold)
            if let destination = entry.destination {
                Text("→ \(destination)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Link(destination: URL(string: "mwallet://record")!) {
                HStack(spacing: 3) {
                    Image(systemName: "mic.fill").font(.caption2)
                    Text("직접").font(.caption2)
                }
                .foregroundStyle(brandCobalt)
            }
        }
    }

    /// 끝 줄 — 방금 담은 것과 되돌리기.
    ///
    /// 누르면 화면이 그대로라 담겼는지 알 수 없었다. 앱이 큐를 가져간 뒤에는
    /// 되돌릴 것이 없으므로 그때는 안내만 남는다.
    @ViewBuilder
    private var footer: some View {
        if let last = entry.lastLogged {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2).foregroundStyle(brandCobalt)
                Text("\(last.info) \(MwalletSharedFormat.krw(last.amount))")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 4)
                Button(intent: UndoLastLogIntent()) {
                    Text("되돌리기").font(.caption2).foregroundStyle(brandCobalt)
                }
                .buttonStyle(.plain)
            }
        } else {
            Text("눌러서 바로 담기 · 앱을 열면 기록에 들어갑니다")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct RecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MwalletRecord", provider: QuickLogProvider()) { entry in
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
            .containerBackground(.clear, for: .widget)
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
        StaticConfiguration(kind: "MwalletReceipt", provider: SnapshotProvider(label: "영수증")) { entry in
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

    init() {
        // 이 줄이 안 찍히면 확장 자체가 뜨지 않은 것이다.
        WidgetLog.shared.notice("위젯 묶음 시작 — 예산·결산·지출기록·영수증 넷")
    }

    // 차례가 두 곳에서 쓰인다. 갤러리에 늘어서는 순서이면서, 앱 아이콘을
    // 길게 눌러 크기만 고를 때 얹히는 것이 여기 첫 번째다.
    //
    // 그 자리를 지출 기록에 준다. 예산·결산·영수증은 보는 위젯이라 갤러리에서
    // 한 번 골라 얹으면 그만이지만, 지출 기록은 눌러서 담는 위젯이라
    // 지름길로서 값이 가장 크다.
    var body: some Widget {
        RecordWidget()
        BudgetWidget()
        SettlementWidget()
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
