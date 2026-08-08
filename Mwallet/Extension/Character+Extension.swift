//
//  Character+Extension.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/12/23.
//

extension Character {
    static let arabicNumericArray: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    static let arabicCommaArray: [Character] = [","]
    static let arabicDotArray: [Character] = ["."]
    static let koreanNumericArray: [Character] = ["영", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구"]
    static let koreanFourPowerArray: [Character] = ["만"]
    static let korean123PowerArray: [Character] = ["십", "백", "천"]
    static let koreanDotArray: [Character] = ["점"]
    
    func getCharacterForm() -> CharacterForm {
        if Character.arabicNumericArray.contains(self) {
            return .arabicNumeric
        } else if Character.arabicCommaArray.contains(self) {
            return .arabicComma
        } else if Character.arabicDotArray.contains(self) {
            return .arabicDot
        } else if Character.koreanNumericArray.contains(self) {
            return .koreanNumeric
        } else if Character.koreanFourPowerArray.contains(self) {
            return .koreanFourPower
        } else if Character.korean123PowerArray.contains(self) {
            return .korean123Power
        } else if Character.koreanDotArray.contains(self) {
            return .koreanDot
        } else {
            return .notNumeric
        }
    }
    
    /// 한글 수사를 아라비아 숫자로 바꾼다. 수사가 아니면 빈 문자열이다.
    ///
    /// 위 koreanNumericArray 가 이미 영·일·이··· 순서로 늘어서 있으므로
    /// 자리 번호가 곧 숫자다. 목록을 한 벌만 두어 둘이 어긋날 일을 없앤다.
    func getCorrespondingArabicString() -> String {
        guard let digit = Character.koreanNumericArray.firstIndex(of: self) else { return "" }
        return String(digit)
    }
}
