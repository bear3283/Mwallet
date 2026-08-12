//
//  ReceiptHomeView.swift
//  Mwallet
//
//  영수증 탭. 레이아웃과 타이포그래피는 가계부 탭과 같은 규칙을 따른다.
//  집계는 ReceiptSummary 에 위임해 통계·CSV 화면과 같은 값을 쓴다.
//

import PhotosUI
import SwiftUI

struct ReceiptHomeView: View {

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.payDate, ascending: false)],
        animation: .default
    )
    private var allReceipts: FetchedResults<Expense>

    private let store = ReceiptStore()

    @State private var filter = ReceiptFilter()
    // 상단 여행 선택. nil 이면 모든 여행을 함께 본다.
    @State private var selectedTravel: Travel?
    @State private var travels: [Travel] = []
    @State private var isAddingExpense = false
    @State private var deletionTarget: Expense?
    @State private var errorMessage: String?

    // 사진 첨부 흐름: 썸네일 탭 → 소스 선택 → 보관함/카메라 → 저장
    @State private var attachTarget: Expense?
    @State private var isChoosingPhotoSource = false
    @State private var isPickingFromLibrary = false
    @State private var isTakingPhoto = false
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 12)

                // 첫 줄은 '무엇을 볼지' 다. 예결산과 같은 자리·같은 방식으로
                // 여행을 고른다. 검색은 고른 여행 안에서 좁히는 일이라 그 아래에 둔다.
                TabHeaderRow {
                    TravelPicker(travels: travels,
                                 selection: $selectedTravel,
                                 onChange: { filter.missionName = selectedTravel?.name },
                                 emptyTitle: "전체 여행",
                                 emptyDescription: "모든 여행의 영수증을 함께 봅니다",
                                 allowsAll: true)
                } actions: {
                    NavigationLink {
                        ReceiptStatsView(expenses: filtered, missionName: filter.missionName)
                    } label: {
                        TabActionIcon(systemName: "chart.pie", label: "지출 통계", isEnabled: !allReceipts.isEmpty)
                    }
                    .disabled(allReceipts.isEmpty)

                    Button {
                        isAddingExpense = true
                    } label: {
                        TabActionIcon(systemName: "plus", label: "영수증 추가")
                    }
                }

                if allReceipts.isEmpty {
                    ReceiptEmptyState(
                        message: "아직 영수증이 없어요",
                        detail: "지출이 생기면 바로 남겨두세요.\n오프라인에서도 저장됩니다."
                    )
                } else {
                    searchField
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 12)

                    Spacer()
                        .frame(height: 12)

                    missionChips

                    Spacer()
                        .frame(height: 20)

                    ReceiptSummaryBlock(summaryValue: summaryValue,
                                        missionName: filter.missionName)
                        .padding(.horizontal, ReceiptLayout.gutter)

                    Spacer()
                        .frame(height: 20)

                    Divider()

                    ReceiptDayList(daySections: daySections,
                                   isEmpty: filtered.isEmpty,
                                   showsMission: filter.missionName == nil,
                                   onAttachPhoto: { attachTarget = $0 },
                                   onDelete: { deletionTarget = $0 })
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            // 다른 탭에서 여행을 만들거나 지우고 돌아올 수 있어 열 때마다 다시 읽는다.
            // 고른 여행이 사라졌으면 전체로 되돌린다 — 지워진 이름으로 거르면
            // 아무것도 안 나오는데 화면에는 그 이름이 그대로 남는다.
            .onAppear {
                travels = store.availableTravels()
                if let selectedTravel, !travels.contains(selectedTravel) {
                    self.selectedTravel = nil
                    filter.missionName = nil
                }
            }
            .sheet(isPresented: $isAddingExpense) {
                AddReceiptView()
            }
            .confirmationDialog(
                "이 영수증을 삭제할까요?",
                isPresented: deletionBinding,
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) { confirmDeletion() }
                Button("취소", role: .cancel) { deletionTarget = nil }
            } message: {
                Text("첨부한 사진도 함께 삭제되며 되돌릴 수 없습니다.")
            }
            .confirmationDialog(
                "영수증 사진",
                isPresented: $isChoosingPhotoSource,
                titleVisibility: .visible
            ) {
                Button("사진 보관함에서 선택") { isPickingFromLibrary = true }
                if CameraPicker.isAvailable {
                    Button("사진 촬영") { isTakingPhoto = true }
                }
                Button("취소", role: .cancel) { attachTarget = nil }
            }
            .photosPicker(isPresented: $isPickingFromLibrary, selection: $pickedItem, matching: .images)
            .fullScreenCover(isPresented: $isTakingPhoto) {
                CameraPicker { data in
                    isTakingPhoto = false
                    attach(data)
                } onCancel: {
                    isTakingPhoto = false
                    attachTarget = nil
                }
                .ignoresSafeArea()
            }
            .onChange(of: attachTarget) { _, target in
                isChoosingPhotoSource = target != nil
            }
            .onChange(of: pickedItem) { _, item in
                loadFromLibrary(item)
            }
            .alert("삭제하지 못했습니다", isPresented: errorBinding) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 검색

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.gray300)
            TextField("상호명, 메모, 카테고리", text: $filter.searchText)
                .font(.body1_fixed)
                .foregroundStyle(.black)
                .tint(.mainAccent)
                .autocorrectionDisabled()
            if !filter.searchText.isEmpty {
                Button {
                    filter.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.gray300)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 거르기 칩

    // 여행 이름 칩은 뺐다. 위의 선택기와 같은 일을 두 곳에서 하게 되어,
    // 한쪽으로 고르고 다른 쪽을 보면 무엇이 걸려 있는지 알 수 없었다.
    //
    // 여기 남는 둘은 결이 다르다 — 기간은 '언제 쓴 것', 영수증 없음은
    // '무엇이 빠진 것' 이라 여행 선택과 함께 걸 수 있다.
    private var missionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ReceiptPeriod.allCases) { period in
                    ReceiptChip(title: period.title, isSelected: filter.period == period) {
                        filter.period = period
                    }
                }

                if missingPhotoCount > 0 {
                    // 기간과 다른 축이라 사이를 띄워 묶음을 나눈다.
                    Rectangle()
                        .fill(Color.gray200)
                        .frame(width: 0.5, height: 18)
                        .padding(.horizontal, 4)

                    ReceiptChip(title: "영수증 없음 \(missingPhotoCount)", isSelected: filter.onlyMissingPhoto) {
                        filter.onlyMissingPhoto.toggle()
                    }
                }
            }
            .padding(.horizontal, ReceiptLayout.gutter)
        }
    }

    // MARK: - 합계

    // MARK: - 목록

    // MARK: - 파생 값

    private var filtered: [Expense] {
        allReceipts.filter { filter.matches($0) }
    }

    private var daySections: [ReceiptDaySection] {
        ReceiptGrouping.byDay(filtered)
    }

    private var summaryValue: ReceiptSummary {
        ReceiptSummary(expenses: filtered)
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { deletionTarget != nil },
            set: { isPresented in
                if !isPresented { deletionTarget = nil }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    // MARK: - 동작

    private var missingPhotoCount: Int {
        allReceipts.filter { $0.needsPhoto }.count
    }

    private func loadFromLibrary(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            defer { pickedItem = nil }
            guard let original = try? await item.loadTransferable(type: Data.self),
                  let processed = ReceiptImageProcessor.process(original) else {
                errorMessage = "사진을 불러오지 못했습니다."
                attachTarget = nil
                return
            }
            attach(processed)
        }
    }

    private func attach(_ data: Data) {
        guard let target = attachTarget else { return }
        do {
            try store.attachPhoto(data, to: target)
        } catch {
            errorMessage = error.localizedDescription
        }
        attachTarget = nil
    }

    private func confirmDeletion() {
        guard let target = deletionTarget else { return }
        do {
            try store.delete(target)
        } catch {
            errorMessage = error.localizedDescription
        }
        deletionTarget = nil
    }
}

#Preview {
    ReceiptHomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
