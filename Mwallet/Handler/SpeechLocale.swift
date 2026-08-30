//
//  SpeechLocale.swift
//  Mwallet
//
//  말하기를 어느 언어로 들을지 정한다.
//
//  예전에는 ko_KR 로 박혀 있었다. 스토어에는 열한 언어로 "버튼을 누른 채
//  한 문장 말하세요" 라고 적어 두고, 정작 한국어로만 들었다. 독일어 설명을
//  읽고 받은 사람이 독일어로 말하면 아무것도 받아 적히지 않는다.
//
//  이제 기기 언어를 따른다. 다만 두 가지를 확인해야 한다.
//   - 애플이 그 언어의 받아쓰기를 지원하는가 (supportedLocales)
//   - 우리가 그 언어의 문장을 갈라 읽을 수 있는가 (SentenceParsing)
//  둘 중 하나라도 아니면 한국어로 물러난다. 물러난 것을 화면이 알아야
//  '이 언어로는 말하기가 안 된다' 고 말해 줄 수 있으므로 함께 돌려준다.
//

import Foundation
import Speech

enum SpeechLocale {

    /// 문장을 갈라 읽는 규칙이 있는 언어인지 SentenceRules 에게 묻는다.
    ///
    /// 예전에는 이 파일에 ["ko", "en"] 이라고 적어 두었다. 규칙은 저쪽에
    /// 있는데 목록은 이쪽에 있어서, 언어를 늘릴 때 한쪽만 고치면 조용히
    /// 어긋난다. 표 하나만 남기고 여기서는 묻기만 한다.
    static func canParse(_ locale: Locale) -> Bool {
        SentenceRules.canParse(locale)
    }

    /// 기기 언어로 들을 수 있는지.
    static var isAvailableForCurrentLanguage: Bool {
        resolved().language.languageCode?.identifier == preferredLanguageCode
    }

    /// 기기가 앞세운 언어의 두 글자 코드.
    static var preferredLanguageCode: String {
        Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
            ?? "ko"
    }

    /// 실제로 들을 로케일. 지원하지 않으면 한국어로 물러난다.
    static func resolved() -> Locale {
        let candidate = Locale.current
        guard canParse(candidate) else { return Locale(identifier: "ko_KR") }

        // 애플이 그 언어의 받아쓰기를 지원하는지 본다. 지원 목록은 기기와
        // OS 판마다 다르므로 코드에 적어 두지 않고 그때그때 묻는다.
        let code = preferredLanguageCode
        let supportedByApple = SFSpeechRecognizer.supportedLocales()
            .contains { $0.language.languageCode?.identifier == code }
        return supportedByApple ? candidate : Locale(identifier: "ko_KR")
    }

    /// 실제로 듣는 언어의 이름을, 기기 언어로 적어 말해 준다.
    ///
    /// 오류 문장에 넣는다. 한국어로 물러난 채 독일어 기기에 '독일어 인식을
    /// 쓸 수 없습니다' 라고 적으면 거짓말이 된다.
    static var resolvedLanguageName: String {
        let locale = resolved()
        guard let code = locale.language.languageCode?.identifier else { return locale.identifier }
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    static func makeRecognizer() -> SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: resolved()) ?? SFSpeechRecognizer(locale: Locale(identifier: "ko_KR"))
    }
}
