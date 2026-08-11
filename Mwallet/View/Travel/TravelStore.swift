//
//  TravelStore.swift
//  Mwallet
//
//  여행의 수정 경로.
//  여행은 생성(AddTravelView 흐름)과 삭제만 있고 고칠 방법이 없어,
//  이름에 오타가 나면 여행을 지우고 다시 만드는 수밖에 없었다.
//  지출이 딸린 여행은 삭제가 Cascade 라 기록까지 함께 사라진다.
//

import CoreData
import Foundation
import OSLog

// 화면이 편집 중에 들고 있는 값.
// NSManagedObject 를 직접 고치면 취소했을 때 되돌리기가 번거롭다.
struct TravelDraft {

    var name: String
    var startDate: Date
    // 종료일 미정을 허용한다. 편도로 떠나는 일정이 있다.
    var endDate: Date?
    var participants: [String]

    init(from travel: Travel) {
        self.name = travel.name ?? ""
        self.startDate = travel.startDate ?? Date()
        self.endDate = travel.endDate
        self.participants = travel.participants
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 종료일이 시작일보다 빠르면 기간 계산과 '여행 중' 판정이 어긋난다.
    var hasValidPeriod: Bool {
        guard let endDate else { return true }
        return endDate >= startDate
    }

    var isValid: Bool {
        !trimmedName.isEmpty && hasValidPeriod
    }

    // 저장 직전에 다듬는다. 빈 칸·중복·'나' 를 걷어낸다.
    // '나' 는 화면이 항상 앞에 붙여 보여 주므로 저장 목록에 두면 두 번 나온다.
    var cleanedParticipants: [String] {
        TravelParticipants.cleaned(participants)
    }
}

/// 참가자 이름을 다듬는 규칙.
///
/// '나' 는 목록에 넣지 않는다. 화면은 언제나 ["나"] 를 앞에 붙여 세므로,
/// 목록에도 들어 있으면 두 번 세어진다 — 둘이 간 여행이 3명으로 보인다.
///
/// 예전에는 이 규칙이 여행을 고칠 때만 걸렸다. 만들 때와 예시 데이터는
/// 그냥 통과해서, 첫 실행의 예시 여행이 실제로 3명으로 보이고 있었다.
enum TravelParticipants {

    static func cleaned(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "나" }
            .filter { seen.insert($0).inserted }
    }
}

enum TravelStoreError: LocalizedError, Equatable {
    case emptyName
    case endBeforeStart
    case cannotEditDefault

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "여행 이름을 입력해 주세요."
        case .endBeforeStart:
            return "종료일이 시작일보다 빠릅니다."
        case .cannotEditDefault:
            return "'임시 기록'은 고칠 수 없습니다."
        }
    }
}

final class TravelStore {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func update(_ travel: Travel, with draft: TravelDraft) throws {
        // 기본함은 사용자가 만든 일정이 아니라 여행을 고르지 않은 지출이 담기는
        // 자리다. 화면에서는 목록에 올리지 않아 닿을 수 없지만, 이름이 편집
        // 가능해진 이상 여기서도 막아 둔다.
        guard travel.isUserCreated else { throw TravelStoreError.cannotEditDefault }
        guard !draft.trimmedName.isEmpty else { throw TravelStoreError.emptyName }
        guard draft.hasValidPeriod else { throw TravelStoreError.endBeforeStart }

        travel.name = draft.trimmedName
        travel.startDate = draft.startDate
        travel.endDate = draft.endDate
        travel.participants = draft.cleanedParticipants
        travel.lastUpdate = Date()

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: - 조회

    /// 화면에 올릴 여행 목록.
    ///
    /// '임시 기록' 기본함은 뺀다. 여행을 고르지 않은 지출이 담기는 자리라
    /// 사용자가 만든 일정이 아니고, 목록에 올리면 고를 수 있게 되어 버린다.
    ///
    /// 차례는 시작일 내림차순이 아니라 '여행 중 → 지난 → 다가오는' 이다.
    /// 화면을 열었을 때 지금 진행 중인 여행이 먼저 보여야 한다.
    ///
    /// 예전에는 이 열두 줄이 세 곳에 있었다 — 영수증 스토어, 예결산 스토어,
    /// 그리고 여행 선택 모달 안. 로그 문구만 다르고 나머지가 같았다.
    func availableTravels() -> [Travel] {
        do {
            return try context.fetch(Travel.fetchRequest())
                .filter { $0.isUserCreated }
                .sorted(by: travelModalSortRule)
        } catch {
            Logger.data.error("여행 목록 조회 실패: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// 여행을 고르지 않은 지출이 담기는 기본함.
    func defaultTravel() -> Travel? {
        Travel.fetchDefault(in: context)
    }

    // MARK: - 삭제

    /// 여행을 지운다. 딸린 지출도 함께 사라진다.
    ///
    /// 예전에는 이 일을 PersistenceController 가 했는데, 이미 손에 쥔 여행을
    /// 찾으려고 전체 목록을 다시 훑고 id 로 견줬다. 같은 컨텍스트의 객체라
    /// 그대로 지우면 된다. 실패를 try? 로 삼키던 것도 밖으로 넘긴다.
    func delete(_ travel: Travel) throws {
        context.delete(travel)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
