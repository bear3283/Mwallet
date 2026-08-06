//
//  CSVParser.swift
//  Mwallet
//
//  RFC 4180 을 지키는 CSV 리더.
//
//  기존에는 CountryInfoModel·CurrencyInfoModel 이 각자 `components(separatedBy: ",")`
//  로 행을 쪼갰다. 필드 안의 쉼표를 구분자로 오인해서, 통화가 둘인 국가
//  (홍콩 "[HKD,USD]", 마카오 "[MOP,HKD]") 에서 두 번째 통화가 사라지고
//  그 뒤 열이 한 칸씩 밀려 블러 이미지 이름이 "USD]" 가 되는 문제가 있었다.
//
//  쓰기 쪽(ReceiptCSVEncoder)은 이미 RFC 4180 을 따르므로 읽기 쪽도 맞춘다.
//  스프레드시트가 내보낸 파일을 그대로 넣어도 열이 밀리지 않는다.
//

import Foundation

enum CSVParser {

    /// 파일을 읽어 행 × 열로 나눈다. 인코딩은 UTF-8 로 읽는다.
    static func rows(contentsOf url: URL) throws -> [[String]] {
        rows(from: try String(contentsOf: url, encoding: .utf8))
    }

    /// RFC 4180 규칙으로 텍스트를 파싱한다.
    /// - 따옴표로 감싼 필드 안의 쉼표·줄바꿈은 데이터로 취급한다.
    /// - 필드 안의 `""` 는 따옴표 한 개로 되돌린다.
    /// - 줄바꿈은 CRLF·LF 를 모두 받는다.
    static func rows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        func endField() {
            row.append(field)
            field = ""
        }

        func endRow() {
            endField()
            rows.append(row)
            row = []
        }

        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if inQuotes {
                if character == "\"" {
                    // 연속된 따옴표는 이스케이프된 따옴표 한 개.
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                    index += 1
                    continue
                }
                // 따옴표 안에서는 쉼표도 줄바꿈도 데이터다.
                field.append(character)
                index += 1
                continue
            }

            switch character {
            case "\"":
                inQuotes = true
            case ",":
                endField()
            case "\r\n", "\n", "\r":
                // ⚠️ Swift 는 "\r\n" 을 한 Character(확장 자소 클러스터)로 다룬다.
                //    \r 과 \n 만 비교하면 CRLF 파일에서 줄바꿈을 하나도 못 잡아
                //    파일 전체가 한 행으로 읽힌다. 셋을 모두 줄바꿈으로 받는다.
                endRow()
            default:
                field.append(character)
            }
            index += 1
        }

        // 마지막 줄에 줄바꿈이 없으면 남은 필드를 흘리지 않고 닫는다.
        if !field.isEmpty || !row.isEmpty {
            endRow()
        }

        // 파일 끝의 빈 줄은 행으로 세지 않는다.
        return rows.filter { $0.count > 1 || $0.first?.isEmpty == false }
    }
}
