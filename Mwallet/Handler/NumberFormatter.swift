//
//  NumberFormatterHandler.swift
//  Mwallet
//
//  Created by Wonil Lee on 11/15/23.
//

import Foundation

// 포매터는 init 에서 한 번 설정한 뒤로는 읽기만 한다.
// NumberFormatter 는 그렇게 쓰는 한 스레드 안전하다고 문서화돼 있고,
// 매번 새로 만들면 비싸서 하나를 공유한다. 설정을 바꾸는 코드를 추가하면
// 이 가정이 깨지므로 아래 프로퍼티는 계속 읽기 전용으로 둔다.
final class NumberFormatterHandler: @unchecked Sendable {
    static let shared = NumberFormatterHandler()
    
    let fraction0 = NumberFormatter()
    let fraction0To2 = NumberFormatter()
    
    private init() {
        fraction0.maximumFractionDigits = 0
        fraction0.numberStyle = .decimal
        
        fraction0To2.minimumFractionDigits = 0
        fraction0To2.maximumFractionDigits = 2
        fraction0To2.numberStyle = .decimal

    }
    
    func getStringFraction0(_ value: Double) -> String? {
        if let formatted = self.fraction0.string(from: NSNumber(value: value)) {
            return formatted
        } else {
            return nil
        }
    }
    func getStringFraction0To2(_ value: Double) -> String? {
        if let formatted = self.fraction0To2.string(from: NSNumber(value: value)) {
            return formatted
        } else {
            return nil
        }
    }
}
