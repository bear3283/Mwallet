//
//  String+Extension.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/12/23.
//

extension String {
    func getCharacterFormArray() -> [CharacterForm] {
        var forms = Array(self).map { $0.getCharacterForm() }

        // '점' 은 소수점 표시이면서 '점심'·'지점'·'거점' 같은 낱말에도 흔히 쓰인다.
        // 글자 하나만 보면 둘을 가를 수 없어, 앞 글자가 숫자일 때만 소수점으로 읽는다.
        //
        //   이십사점오  → '사' 다음이라 소수점  (24.5)
        //   점심        → 앞이 없으므로 낱말의 일부
        //
        // 이 구분이 없을 때는 '점심 먹었다' 의 '점' 이 소수점으로 잡혀 내역이
        // 통째로 사라지고 금액이 0원이 됐다. 0은 미확보(-1)가 아니라서
        // 0원짜리 빈 기록이 저장될 수 있었다.
        for index in forms.indices where forms[index] == .koreanDot {
            let previous = index > 0 ? forms[index - 1] : nil
            let followsNumeral = previous == .koreanNumeric || previous == .arabicNumeric
            if !followsNumeral {
                forms[index] = .notNumeric
            }
        }

        return forms
    }
}
