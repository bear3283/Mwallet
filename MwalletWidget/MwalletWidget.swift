//
//  MwalletWidget.swift
//  MwalletWidget
//
//  홈 화면·잠금 화면에서 한 번에 '기록' 탭을 여는 빠른 지출 입력 위젯.
//  탭하면 mwallet://record 딥링크로 앱의 기록 화면이 바로 열린다.
//  데이터를 직접 쓰지 않으므로 App Group·공유 저장소가 필요 없다.
//
//  ⚠️ 이 파일은 아직 어떤 타깃에도 포함돼 있지 않다.
//     같은 폴더의 README-위젯-추가.md 절차대로 Widget Extension 타깃을 만들고
//     이 파일을 그 타깃에 추가하면 동작한다.
//

import SwiftUI
import WidgetKit

// 브랜드 코발트. 앱 에셋 mainAccent 와 같은 값(sRGB #2F5BEA).
// 위젯 타깃은 앱 에셋 카탈로그를 공유하지 않으므로 값을 직접 둔다.
private let brandCobalt = Color(red: 0.184, green: 0.357, blue: 0.918)

// MARK: - 타임라인

struct QuickRecordEntry: TimelineEntry {
    let date: Date
}

struct QuickRecordProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickRecordEntry {
        QuickRecordEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickRecordEntry) -> Void) {
        completion(QuickRecordEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickRecordEntry>) -> Void) {
        // 실행 버튼 역할만 하므로 주기적 갱신이 필요 없다.
        completion(Timeline(entries: [QuickRecordEntry(date: Date())], policy: .never))
    }
}

// MARK: - 화면

struct QuickRecordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuickRecordEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
            }
            .widgetURL(recordURL)

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                VStack(alignment: .leading) {
                    Text("지출 기록").font(.headline)
                    Text("눌러서 바로 기록").font(.caption)
                }
            }
            .widgetURL(recordURL)

        default:
            homeWidget
        }
    }

    private var homeWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Text("지출 기록")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text("눌러서 바로 기록")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .containerBackground(brandCobalt, for: .widget)
        .widgetURL(recordURL)
    }

    private var recordURL: URL? {
        URL(string: "mwallet://record")
    }
}

// MARK: - 위젯 정의

struct QuickRecordWidget: Widget {
    let kind = "MwalletQuickRecord"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickRecordProvider()) { entry in
            QuickRecordWidgetView(entry: entry)
        }
        .configurationDisplayName("빠른 지출 기록")
        .description("홈 화면에서 한 번에 지출을 기록합니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct MwalletWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickRecordWidget()
    }
}
