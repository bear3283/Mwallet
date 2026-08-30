//
//  ReceiptCSVEncoder.swift
//  Mwallet
//
//  RFC 4180 을 지키는 CSV 인코더.
//  기존 CSVArchive 는 필드 안의 따옴표를 이스케이프하지 않고, 일부 필드는
//  따옴표로 감싸지도 않아 쉼표가 들어가면 열이 밀렸다. 재정 담당자가
//  단체에 제출하는 파일이므로 여기서는 세 가지를 모두 막는다.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

enum ReceiptCSVEncoder {

    private static let columns = [
        String(localized: "여행"), String(localized: "결제 일자"),
        String(localized: "기록 지역"), String(localized: "상호명"),
        String(localized: "카테고리"), String(localized: "통화"),
        String(localized: "현지금액"), String(localized: "적용환율"),
        String(localized: "원화환산"), String(localized: "메모")
    ]

    static func encode(_ expenses: [Expense]) -> Data {
        var rows = [columns]

        for expense in expenses.sorted(by: { $0.paidDate < $1.paidDate }) {
            rows.append([
                expense.missionTitle,
                isoDateString(expense),
                expense.recordedTimeZone.identifier,
                expense.merchantName,
                expense.categoryName,
                expense.currencyCode,
                decimalString(expense.payAmount, digits: 2),
                expense.validExchangeRate.map { decimalString($0, digits: 4) } ?? "",
                expense.amountInKRW.map { decimalString($0, digits: 0) } ?? "",
                expense.memoText
            ])
        }

        // RFC 4180 은 CRLF 를 규정한다. Excel 과 Numbers 모두 이 쪽이 안전하다.
        let body = rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"

        // BOM 이 없으면 Windows Excel 이 한글을 깨뜨린다.
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(body.utf8))
        return data
    }

    // MARK: - 필드 처리

    // 모든 필드를 따옴표로 감싸고 내부 따옴표는 두 번 반복한다.
    // 쉼표·줄바꿈·따옴표가 값에 들어가도 열이 밀리지 않는다.
    private static func escape(_ field: String) -> String {
        let guarded = neutralizingFormula(field)
        return "\"" + guarded.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // =, +, -, @, 탭, 캐리지리턴 으로 시작하는 값은 Excel/Numbers 가 수식으로 실행한다.
    // 상호명과 메모는 사용자 입력이라 그대로 두면 CSV 인젝션 경로가 된다.
    private static func neutralizingFormula(_ field: String) -> String {
        guard let first = field.first else { return field }
        let dangerous: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]
        return dangerous.contains(first) ? "'" + field : field
    }

    private static func decimalString(_ value: Double, digits: Int) -> String {
        // 표시용 천단위 구분자를 넣지 않는다. 스프레드시트가 숫자로 인식해야 한다.
        String(format: "%.\(digits)f", value)
    }

    // 기록 당시 현지 시각으로 적되 오프셋을 함께 남겨 절대 시각을 복원할 수 있게 한다.
    private static func isoDateString(_ expense: Expense) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = expense.recordedTimeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        return formatter.string(from: expense.paidDate)
    }

    // MARK: - 파일 이름

    static func fileName(missionName: String?, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        let stamp = formatter.string(from: now)

        let base = missionName.map { sanitized($0) } ?? String(localized: "전체여행")
        return "Mwallet_\(base)_\(stamp).csv"
    }

    private static func sanitized(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return cleaned.isEmpty ? String(localized: "여행") : cleaned
    }
}

// MARK: - 공유

struct ReceiptCSVFile: Transferable {

    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            file.data
        }
        .suggestedFileName { file in
            file.fileName
        }
    }
}
