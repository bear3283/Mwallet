//
//  AddExpenseView.swift
//  Mwallet
//
//  사역 재정 영수증 추가 폼.
//  Mission 기능 전용이며 기존 여행 가계부의 지출 기록과는 별개다.
//

import PhotosUI
import SwiftUI

struct AddExpenseView: View {

    @Environment(\.dismiss) private var dismiss

    private let store = ReceiptStore()

    @State private var draft = ReceiptDraft()
    @State private var pickedItem: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var isEnteringNewCategory = false
    @State private var newCategory = ""
    @State private var errorMessage: String?

    @FocusState private var isAmountFocused: Bool

    private let missionNameSuggestions: [String]
    private let categories: [String]

    init() {
        let store = ReceiptStore()
        self.missionNameSuggestions = store.existingMissionNames()
        self.categories = store.availableCategories()
    }

    var body: some View {
        NavigationStack {
            Form {
                missionSection
                amountSection
                detailSection
                photoSection
            }
            .navigationTitle("지출 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!draft.isValid || isProcessingImage)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { isAmountFocused = false }
                }
            }
            .onChange(of: pickedItem) { _, newItem in
                loadImage(from: newItem)
            }
            .alert("저장하지 못했습니다", isPresented: errorBinding) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 사역 / 일자

    private var missionSection: some View {
        Section {
            TextField("사역 이름", text: $draft.missionName)
                .textInputAutocapitalization(.never)

            if !missionNameSuggestions.isEmpty {
                Menu("이전 사역에서 선택") {
                    ForEach(missionNameSuggestions, id: \.self) { name in
                        Button(name) { draft.missionName = name }
                    }
                }
                .font(.footnote)
            }

            DatePicker("결제 일자", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
        } header: {
            Text("사역")
        } footer: {
            Text("사역 이름으로 영수증을 묶어 나중에 따로 정산할 수 있습니다.")
        }
    }

    // MARK: - 금액 / 통화

    private var amountSection: some View {
        Section {
            HStack {
                TextField("0", text: $draft.amountText)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .multilineTextAlignment(.trailing)

                Picker("통화", selection: $draft.currency) {
                    ForEach(ReceiptCurrency.presets, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
            }

            if draft.currency != ReceiptCurrency.base {
                LabeledContent("원화 환산") {
                    Text(convertedPreview)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("금액")
        } footer: {
            if draft.currency != ReceiptCurrency.base && currentRate == nil {
                Text("환율 정보를 아직 받지 못했습니다. 금액은 그대로 저장되며, 환율을 받은 뒤 상세 화면에서 다시 계산할 수 있습니다.")
            }
        }
    }

    // MARK: - 상세

    private var detailSection: some View {
        Section("상세") {
            TextField("상호명", text: $draft.merchant)

            Picker("카테고리", selection: $draft.category) {
                ForEach(categories, id: \.self) { name in
                    Text(name).tag(name)
                }
            }

            Button("카테고리 직접 입력") {
                newCategory = ""
                isEnteringNewCategory = true
            }
            .font(.footnote)

            TextField("메모", text: $draft.memo, axis: .vertical)
                .lineLimit(2...4)
        }
        .alert("새 카테고리", isPresented: $isEnteringNewCategory) {
            TextField("카테고리 이름", text: $newCategory)
            Button("추가") {
                let normalized = ReceiptCategory.normalized(newCategory)
                draft.category = normalized
            }
            Button("취소", role: .cancel) { }
        }
    }

    // MARK: - 영수증 사진

    private var photoSection: some View {
        Section {
            if let data = draft.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowInsets(EdgeInsets())

                LabeledContent("파일 크기") {
                    Text(ReceiptImageProcessor.formattedSize(of: data))
                        .foregroundStyle(.secondary)
                }

                Button("사진 삭제", role: .destructive) {
                    draft.imageData = nil
                    pickedItem = nil
                }
            } else {
                PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                    Label(isProcessingImage ? "불러오는 중…" : "영수증 사진 첨부", systemImage: "camera")
                }
                .disabled(isProcessingImage)
            }
        } header: {
            Text("증빙")
        } footer: {
            Text("사진은 장변 \(Int(ReceiptImageProcessor.maxDimension))px 로 줄여 저장합니다.")
        }
    }

    // MARK: - 파생 값

    private var currentRate: Double? {
        guard draft.currency != ReceiptCurrency.base else { return 1 }
        return ExchangeRateHandler.shared.getExchangeRateFromKRW(currencyCode: draft.currency)
    }

    private var convertedPreview: String {
        guard let amount = draft.amount, let rate = currentRate else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let value = amount * rate
        return (formatter.string(from: NSNumber(value: value)) ?? "0") + "원"
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

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        isProcessingImage = true
        Task {
            defer { isProcessingImage = false }
            do {
                guard let original = try await item.loadTransferable(type: Data.self) else {
                    errorMessage = "사진을 불러오지 못했습니다."
                    return
                }
                guard let processed = ReceiptImageProcessor.process(original) else {
                    errorMessage = "지원하지 않는 이미지 형식입니다."
                    return
                }
                draft.imageData = processed
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func save() {
        do {
            try store.create(from: draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddExpenseView()
}
