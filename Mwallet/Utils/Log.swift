//
//  Log.swift
//  Mwallet
//
//  진단 로그의 단일 창구.
//
//  print 는 릴리스 빌드에도 그대로 남고, 콘솔에서 앱 로그만 걸러 보기 어렵고,
//  사용자 데이터가 섞여도 그대로 찍힌다. Logger 는 카테고리로 걸러 볼 수 있고
//  릴리스에서 보간값을 기본으로 가린다.
//
//  ⚠️ 보간값은 기본이 private 이라 릴리스에서 <private> 로 나온다.
//     오류 메시지처럼 진단에 꼭 필요하고 사용자 데이터가 아닌 값만
//     privacy: .public 을 붙인다. 금액·상호명·여행 이름에는 붙이지 않는다.
//

import OSLog

extension Logger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.Mwallet.app"

    /// Core Data 저장소와 읽기·쓰기
    static let data = Logger(subsystem: subsystem, category: "data")

    /// 환율 조회와 캐시
    static let exchangeRate = Logger(subsystem: subsystem, category: "exchangeRate")

    /// 음성 인식·녹음·재생
    static let record = Logger(subsystem: subsystem, category: "record")

    /// 번들에 든 국가·통화 표 로딩
    static let resources = Logger(subsystem: subsystem, category: "resources")

    /// 위젯과 주고받는 App Group 큐
    static let widget = Logger(subsystem: subsystem, category: "widget")
}
