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

                        ReceiptSectionTitle(text: String(localized: "여행"))
                            .padding(.top, 20)
                        missionBlock

                        Divider()

                        ReceiptSectionTitle(text: String(localized: "상세"))
                            .padding(.top, 20)
                        detailBlock

                        Divider()

                        ReceiptSectionTitle(text: String(localized: "증빙"))
                            .padding(.top, 20)
                        ReceiptPhotoField(draft: $draft,
                                          errorMessage: $errorMessage,
                                          isProcessingImage: $isProcessingImage)

                        Divider()

                        ReceiptSectionTitle(text: String(localized: "위치"))
                            .padding(.top, 20)
                        ReceiptLocationField(draft: $draft)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, ReceiptLayout.gutter)
                }

                ReceiptPrimaryButton(
                    title: isEditing ? String(localized: "수정 완료") : String(localized: "저장"),
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
                    Text(isEditing ? String(localized: "영수증 수정") : String(localized: "영수증 추가"))
                        .font(.title1)
                        .foregroundStyle(.black)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .font(.subhead2_2)
                        .foregroundStyle(.gray400)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focusedField = nil }
                }
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
                    .font(.display4)
                    .foregroundStyle(.black)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .tint(.mainAccent)
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
                    ReceiptNotice(text: String(localized: "환율 정보를 아직 받지 못했어요. 금액은 그대로 저장되고 나중에 상세 화면에서 환산할 수 있습니다"))
                } else {
                    Text("원화 환산 \(convertedPreview)")
                        .font(.caption2)
                        .foregroundStyle(.gray300)
                }
            }
        }
    }

    // MARK: - 사역

    private var missionBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReceiptFieldRow(label: String(localized: "여행")) {
                if travels.isEmpty {
                    Text("여행 탭에서 일정을 먼저 만들어 주세요")
                        .font(.caption2)
                        .foregroundStyle(.gray300)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ReceiptChip(title: String(localized: "미분류"), isSelected: draft.travel == nil) {
                                draft.travel = nil
                            }
                            ForEach(travels, id: \.objectID) { travel in
                                ReceiptChip(
                                    title: travel.name ?? String(localized: "이름 없음"),
                                    isSelected: draft.travel?.objectID == travel.objectID
                                ) {
                                    draft.travel = travel
                                }
                            }
                        }
                    }
                }
            }

            ReceiptFieldRow(label: String(localized: "결제 일자")) {
                DatePicker("", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(.mainAccent)
            }
        }
    }

    // MARK: - 상세

    private var detailBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReceiptFieldRow(label: String(localized: "상호명")) {
                TextField("어디에서 썼나요", text: $draft.merchant)
                    .focused($focusedField, equals: .merchant)
                    .receiptField()
            }

            ReceiptFieldRow(label: String(localized: "카테고리")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        // 카테고리는 Core Data 에 Int64 코드로 저장되므로 자유 입력을 받지 않는다.
                        // 기록 탭과 같은 목록이라 두 화면의 분류가 어긋나지 않는다.
                        ForEach(categories, id: \.self) { name in
                            ReceiptChip(title: ExpenseInfoCategory.displayName(forStored: name), isSelected: draft.category == name) {
                                draft.category = name
                            }
                        }
                    }
                }
            }

            ReceiptFieldRow(label: String(localized: "메모")) {
                TextField("남길 말이 있다면", text: $draft.memo, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .memo)
                    .receiptField()
            }
        }
    }

    // MARK: - 증빙

    // MARK: - 위치

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
