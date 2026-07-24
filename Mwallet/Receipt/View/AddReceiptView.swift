//
//  AddReceiptView.swift
//  Mwallet
//
//  영수증 입력 폼. 레이아웃과 타이포그래피는 기록 탭과 같은 규칙을 따른다.
//

import PhotosUI
import SwiftUI

struct AddReceiptView: View {

    // 추가와 수정이 같은 폼을 쓴다.
    // 화면을 따로 만들면 필드가 늘 때마다 두 곳을 고쳐야 하고 한쪽을 빠뜨리게 된다.
    enum Mode {
        case create
        case edit(Expense)
    }

    @Environment(\.dismiss) private var dismiss

    private let store = ReceiptStore()
    private let mode: Mode

    @State private var draft: ReceiptDraft
    @State private var pickedItem: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    private enum Field { case mission, amount, merchant, memo }

    private let travels: [Travel]
    private let categories: [String]

    init(mode: Mode = .create) {
        self.mode = mode
        let store = ReceiptStore()
        self.travels = store.availableTravels()

        switch mode {
        case .create:
            _draft = State(initialValue: ReceiptDraft())
            self.categories = store.availableCategories()
        case .edit(let expense):
            _draft = State(initialValue: ReceiptDraft(from: expense))
            // 수정 중인 영수증의 카테고리가 목록에 없으면 선택이 풀린다.
            var available = store.availableCategories()
            if !available.contains(expense.categoryName) {
                available.append(expense.categoryName)
            }
            self.categories = available
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        amountBlock
                            .padding(.top, 12)

                        Divider()
                            .padding(.top, 20)

                        ReceiptSectionTitle(text: "여행")
                            .padding(.top, 20)
                        missionBlock

                        Divider()

                        ReceiptSectionTitle(text: "상세")
                            .padding(.top, 20)
                        detailBlock

                        Divider()

                        ReceiptSectionTitle(text: "증빙")
                            .padding(.top, 20)
                        photoBlock

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, ReceiptLayout.gutter)
                }

                ReceiptPrimaryButton(
                    title: isEditing ? "수정 완료" : "저장",
                    isEnabled: draft.isValid && !isProcessingImage
                ) {
                    save()
                }
                .padding(.horizontal, ReceiptLayout.gutter)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "영수증 수정" : "영수증 추가")
                        .font(.subhead3_1_fixed)
                        .foregroundStyle(.black)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .font(.subhead2_2_fixed)
                        .foregroundStyle(.gray400)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focusedField = nil }
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

    // MARK: - 금액

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField("0", text: $draft.amountText)
                    .font(.display4_fixed)
                    .foregroundStyle(.black)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .tint(.mainGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Picker("통화", selection: $draft.currency) {
                    ForEach(ExpenseCode.currencyPresets, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .tint(.gray400)
                .background(Color.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if draft.currency != ExpenseCode.baseCurrency {
                if currentRate == nil {
                    ReceiptNotice(text: "환율 정보를 아직 받지 못했어요. 금액은 그대로 저장되고 나중에 상세 화면에서 환산할 수 있습니다")
                } else {
                    Text("원화 환산 \(convertedPreview)")
                        .font(.caption2_fixed)
                        .foregroundStyle(.gray300)
                }
            }
        }
    }

    // MARK: - 사역

    private var missionBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReceiptFieldRow(label: "여행") {
                if travels.isEmpty {
                    Text("여행 탭에서 일정을 먼저 만들어 주세요")
                        .font(.caption2_fixed)
                        .foregroundStyle(.gray300)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ReceiptChip(title: "미분류", isSelected: draft.travel == nil) {
                                draft.travel = nil
                            }
                            ForEach(travels, id: \.objectID) { travel in
                                ReceiptChip(
                                    title: travel.name ?? "이름 없음",
                                    isSelected: draft.travel?.objectID == travel.objectID
                                ) {
                                    draft.travel = travel
                                }
                            }
                        }
                    }
                }
            }

            ReceiptFieldRow(label: "결제 일자") {
                DatePicker("", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(.mainGreen)
            }
        }
    }

    // MARK: - 상세

    private var detailBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReceiptFieldRow(label: "상호명") {
                TextField("어디에서 썼나요", text: $draft.merchant)
                    .focused($focusedField, equals: .merchant)
                    .receiptField()
            }

            ReceiptFieldRow(label: "카테고리") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        // 카테고리는 Core Data 에 Int64 코드로 저장되므로 자유 입력을 받지 않는다.
                        // 기록 탭과 같은 목록이라 두 화면의 분류가 어긋나지 않는다.
                        ForEach(categories, id: \.self) { name in
                            ReceiptChip(title: name, isSelected: draft.category == name) {
                                draft.category = name
                            }
                        }
                    }
                }
            }

            ReceiptFieldRow(label: "메모") {
                TextField("남길 말이 있다면", text: $draft.memo, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .memo)
                    .receiptField()
            }
        }
    }

    // MARK: - 증빙

    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data = draft.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Text(ReceiptImageProcessor.formattedSize(of: data))
                        .font(.caption1_fixed)
                        .foregroundStyle(.gray300)
                    Spacer()
                    Button {
                        draft.imageData = nil
                        pickedItem = nil
                    } label: {
                        Text("사진 삭제")
                            .font(.caption2_fixed)
                            .foregroundStyle(.mainGreen)
                    }
                }
            } else {
                PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text(isProcessingImage ? "불러오는 중…" : "영수증 사진 첨부")
                    }
                    .font(.body1_fixed)
                    .foregroundStyle(.gray400)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isProcessingImage)

                Text("사진은 장변 \(Int(ReceiptImageProcessor.maxDimension))px 로 줄여 저장합니다.")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - 파생 값

    private var currentRate: Double? {
        guard draft.currency != ExpenseCode.baseCurrency else { return 1 }
        return ExchangeRateHandler.shared.getExchangeRateFromKRW(currencyCode: draft.currency)
    }

    private var convertedPreview: String {
        guard let amount = draft.amount, let rate = currentRate else { return "-" }
        return ReceiptFormat.krw(amount * rate)
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
            switch mode {
            case .create:
                try store.create(from: draft)
            case .edit(let expense):
                try store.update(expense, with: draft)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddReceiptView()
}
