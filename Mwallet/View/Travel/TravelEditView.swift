//
//  TravelEditView.swift
//  Mwallet
//
//  여행을 만들고 고친다. 이름·기간·인원·대표 사진을 한 화면에서 정한다.
//
//  만드는 길은 예전에 세 화면(날짜 → 인원 → 완료)이었다. 고치는 화면이
//  같은 값을 한 장에서 받고 있었으므로 그쪽으로 합쳤다.
//

import PhotosUI
import SwiftUI

struct TravelEditView: View {

    @Environment(\.dismiss) private var dismiss

    private let store = TravelStore()
    /// 고치는 여행. nil 이면 새로 만든다.
    private let travel: Travel?

    @State private var draft: TravelDraft
    @State private var hasEndDate: Bool
    @State private var errorMessage: String?
    @State private var pickedCover: PhotosPickerItem?
    @State private var isLoadingCover = false

    /// 새 여행을 만든다.
    init() {
        self.travel = nil
        let draft = TravelDraft()
        _draft = State(initialValue: draft)
        _hasEndDate = State(initialValue: true)
    }

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
            coverSection
        }
        .navigationTitle(travel == nil ? String(localized: "여행 추가") : String(localized: "여행 편집"))
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: pickedCover) { _, item in loadCover(item) }
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
                    .disabled(!draft.isValid || isLoadingCover)
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

    // MARK: - 대표 사진

    private var coverSection: some View {
        Section {
            HStack(spacing: 12) {
                if let data = draft.coverImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                }

                PhotosPicker(selection: $pickedCover, matching: .images) {
                    Label(draft.coverImageData == nil ? String(localized: "사진 선택") : String(localized: "사진 변경"),
                          systemImage: "photo")
                        .font(.body1)
                        .foregroundStyle(Color.mainAccent)
                }
                .disabled(isLoadingCover)

                Spacer()

                if isLoadingCover {
                    ProgressView()
                } else if draft.coverImageData != nil {
                    Button {
                        draft.coverImageData = nil
                        pickedCover = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray300)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("삭제")
                }
            }
        } header: {
            Text("대표 사진")
                .font(.caption2)
                .foregroundStyle(.gray400)
        }
    }

    // 원본을 그대로 넣으면 건당 몇 MB 라 저장소가 급격히 커지고
    // CloudKit 레코드 제한에도 걸린다. 영수증 사진과 같은 규격으로 줄인다.
    private func loadCover(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingCover = true
        Task {
            let raw = try? await item.loadTransferable(type: Data.self)
            if let raw { draft.coverImageData = ReceiptImageProcessor.process(raw) }
            isLoadingCover = false
        }
    }

    // MARK: - 동작

    private func save() {
        do {
            if let travel {
                try store.update(travel, with: draft)
            } else {
                // 방금 만든 여행을 바로 본다. 만들자마자 예산을 세우거나
                // 지출을 적으러 가는데, 거기서 다시 고르게 하지 않는다.
                MainViewModel.shared.selectedTravel = try store.create(from: draft)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
