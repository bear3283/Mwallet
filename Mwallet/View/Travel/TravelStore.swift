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
        self.participants = travel.participantArray ?? []
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
        var seen = Set<String>()
        return participants
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "나" }
            .filter { seen.insert($0).inserted }
    }
}

enum TravelStoreError: LocalizedError, Equatable {
    case emptyName
    case endBeforeStart

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "여행 이름을 입력해 주세요."
        case .endBeforeStart:
            return "종료일이 시작일보다 빠릅니다."
        }
    }
}

final class TravelStore {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func update(_ travel: Travel, with draft: TravelDraft) throws {
        guard !draft.trimmedName.isEmpty else { throw TravelStoreError.emptyName }
        guard draft.hasValidPeriod else { throw TravelStoreError.endBeforeStart }

        travel.name = draft.trimmedName
        travel.startDate = draft.startDate
        travel.endDate = draft.endDate
        travel.participantArray = draft.cleanedParticipants
        travel.lastUpdate = Date()

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
