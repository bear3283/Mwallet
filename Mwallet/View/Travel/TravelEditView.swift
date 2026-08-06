//
//  TravelEditView.swift
//  Mwallet
//
//  여행의 이름·기간·인원을 고친다.
//  생성은 여러 단계로 나뉜 흐름이지만, 편집은 이미 정해진 값을 손보는 일이라
//  한 화면에서 끝낸다.
//

import SwiftUI

struct TravelEditView: View {

    @Environment(\.dismiss) private var dismiss

    private let store = TravelStore()
    private let travel: Travel

    @State private var draft: TravelDraft
    @State private var hasEndDate: Bool
    @State private var errorMessage: String?

    init(travel: Travel) {
        self.travel = travel
        let draft = TravelDraft(from: travel)
        _draft = State(initialValue: draft)
        _hasEndDate = State(initialValue: draft.endDate != nil)
    }

    var body: some View {
        Form {
            nameSection
            periodSection
            participantSection
        }
        .navigationTitle("여행 편집")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
                    .foregroundStyle(.gray400)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장", action: save)
                    .fontWeight(.semibold)
                    .disabled(!draft.isValid)
            }
        }
        .alert("저장하지 못했습니다",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 이름

    private var nameSection: some View {
        Section {
            TextField("여행 이름", text: $draft.name)
                .font(.body1)
        } header: {
            Text("이름")
                .font(.caption2)
                .foregroundStyle(.gray400)
        }
    }

    // MARK: - 기간

    private var periodSection: some View {
        Section {
            DatePicker("시작일", selection: $draft.startDate, displayedComponents: .date)
                .font(.body1)

            Toggle("종료일 정하기", isOn: $hasEndDate)
                .font(.body1)
                // 시스템 기본 초록은 브랜드 색과 어긋난다.
                .tint(Color.mainAccent)
                .onChange(of: hasEndDate) { _, isOn in
                    // 켤 때는 시작일과 같은 날로 시작한다. 시작일보다 이른 날이 잡히지 않는다.
                    draft.endDate = isOn ? max(draft.endDate ?? draft.startDate, draft.startDate) : nil
                }

            if hasEndDate {
                DatePicker("종료일",
                           selection: Binding(get: { draft.endDate ?? draft.startDate },
                                              set: { draft.endDate = $0 }),
                           in: draft.startDate...,
                           displayedComponents: .date)
                    .font(.body1)
            }
        } header: {
            Text("기간")
                .font(.caption2)
                .foregroundStyle(.gray400)
        } footer: {
            if !draft.hasValidPeriod {
                Text("종료일이 시작일보다 빠릅니다.")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - 인원

    private var participantSection: some View {
        Section {
            // '나' 는 항상 포함이라 목록에서 지울 수 없게 둔다.
            HStack(spacing: 8) {
                Text("나")
                    .font(.body1)
                Spacer()
                Text("항상 포함")
                    .font(.caption2)
                    .foregroundStyle(.gray300)
            }

            ForEach(draft.participants.indices, id: \.self) { index in
                TextField("이름", text: $draft.participants[index])
                    .font(.body1)
            }
            .onDelete { draft.participants.remove(atOffsets: $0) }

            Button {
                draft.participants.append("")
            } label: {
                Label("인원 추가", systemImage: "plus.circle")
                    .font(.body1)
                    .foregroundStyle(Color.mainAccent)
            }
        } header: {
            Text("함께하는 사람")
                .font(.caption2)
                .foregroundStyle(.gray400)
        } footer: {
            Text("빈 칸과 중복된 이름은 저장할 때 정리됩니다.")
                .font(.caption2)
                .foregroundStyle(.gray400)
        }
    }

    // MARK: - 동작

    private func save() {
        do {
            try store.update(travel, with: draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
