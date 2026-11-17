//
//  ExpenseFormView.swift
//  Mwallet
//
//  지출 한 건을 적고 고치는 폼. 앱에 하나뿐이다.
//
//  예전에는 기록 탭과 영수증 탭이 같은 지출을 서로 다른 폼으로 받았다.
//  한쪽에는 결제 수단·함께 쓴 사람이, 다른 쪽에는 사진·메모가 있었고 고치는
//  길은 뒤쪽뿐이라, 한번 저장한 함께 쓴 사람은 바로잡을 수 없었다.
//  직접 적기 · 말로 적은 것 고치기 · 내역에서 고치기가 모두 여기로 온다.
//

import PhotosUI
import SwiftUI

struct ExpenseFormView: View {

    // 추가와 수정이 같은 폼을 쓴다.
    // 화면을 따로 만들면 필드가 늘 때마다 두 곳을 고쳐야 하고 한쪽을 빠뜨리게 된다.
    enum Mode {
        /// 새로 적는다. 초안은 부르는 쪽이 미리 채워 준다(여행·말로 들은 값).
        case create(ReceiptDraft)
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
    /// 저장한 뒤에 부를 일. 저장된 지출을 건넨다.
    private let onSaved: (Expense) -> Void

    /// 위치를 보고 통화를 맞춰도 되는지.
    ///
    /// 물려받은 통화가 없는 새 지출에서만 참이다. 사용자가 통화를 직접
    /// 고르면 내린다 — 주소 찾기는 몇 초 뒤에 답하는데, 그 사이에 고른 것을
    /// 덮어쓰면 안 된다.
    @State private var mayFollowLocationCurrency: Bool

    init(mode: Mode, onSaved: @escaping (Expense) -> Void = { _ in }) {
        self.mode = mode
        self.onSaved = onSaved
        let store = ReceiptStore()
        self.travels = store.availableTravels()

        switch mode {
        case .create(let draft):
            _draft = State(initialValue: draft)
            _mayFollowLocationCurrency = State(initialValue: draft.country == ExpenseCode.unknownCountry)
            self.categories = store.availableCategories()
        case .edit(let expense):
            _draft = State(initialValue: ReceiptDraft(from: expense))
            _mayFollowLocationCurrency = State(initialValue: false)
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
                    Text(isEditing ? String(localized: "지출 수정") : String(localized: "지출 추가"))
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
            .task { await fillPlaceIfNeeded() }
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

                Picker("통화", selection: currencyBinding) {
                    ForEach(currencyChoices, id: \.self) { code in
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
                                    choose(travel)
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

            // 혼자 간 여행에서는 나눌 사람이 없어 줄을 내지 않는다.
            if participantChoices.count > 1 {
                ReceiptFieldRow(label: String(localized: "결제 인원")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(participantChoices, id: \.self) { name in
                                ReceiptChip(title: Travel.participantDisplayName(name),
                                            isSelected: draft.participants.contains(name)) {
                                    toggleParticipant(name)
                                }
                            }
                        }
                    }
                }
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

            ReceiptFieldRow(label: String(localized: "결제 수단")) {
                HStack(spacing: 4) {
                    // 다시 누르면 풀린다. 모르는 채로 두는 것도 답이다.
                    ForEach([PaymentMethod.card, .cash], id: \.rawValue) { method in
                        ReceiptChip(title: method.title, isSelected: draft.paymentMethod == method) {
                            draft.paymentMethod = draft.paymentMethod == method ? .unknown : method
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

    /// 고를 수 있는 통화. 지금 있는 나라의 통화를 앞에, 자주 쓰는 것을 뒤에.
    ///
    /// 지금 고른 통화는 언제나 넣는다. 목록에 없으면 Picker 가 선택을 잃어
    /// 빈칸으로 그려진다.
    private var currencyChoices: [String] {
        let local = CountryInfoModel.shared.countryResult[Int(draft.country)]?.relatedCurrencyArray ?? []
        var choices: [String] = []
        for code in [draft.currency] + local + ExpenseCode.currencyPresets {
            let known = ExpenseCode.currencyCode(for: ExpenseCode.currencyIndex(for: code))
            guard known.uppercased() == code.uppercased(), !choices.contains(known) else { continue }
            choices.append(known)
        }
        return choices
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { draft.currency },
            set: { code in
                draft.currency = code
                mayFollowLocationCurrency = false
            }
        )
    }

    /// 고른 여행에서 함께 쓸 수 있는 사람. '나' 가 언제나 맨 앞이다.
    ///
    /// 이미 적혀 있는 이름도 넣는다 — 여행에서 빠진 사람이 예전 지출에 남아
    /// 있을 수 있는데, 목록에 없으면 끌 수도 없다.
    private var participantChoices: [String] {
        var names = [Travel.selfParticipantName] + (draft.travel?.participants ?? [])
        for name in draft.participants where !names.contains(name) { names.append(name) }
        return names
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

    /// 여행을 바꾸면 함께 쓴 사람도 그 여행 사람들로 다시 채운다.
    private func choose(_ travel: Travel?) {
        guard draft.travel?.objectID != travel?.objectID else { return }
        draft.travel = travel
        draft.participants = [Travel.selfParticipantName] + (travel?.participants ?? [])
    }

    private func toggleParticipant(_ name: String) {
        if let index = draft.participants.firstIndex(of: name) {
            draft.participants.remove(at: index)
        } else {
            draft.participants.append(name)
        }
    }

    /// 좌표는 있는데 장소 이름이 없으면 찾아서 채운다. 새로 적을 때만 한다.
    private func fillPlaceIfNeeded() async {
        // 지출에는 결제 위치가 함께 남는다. 새로 적기 시작한 이 시점이
        // 위치 권한을 청할 맥락이다. (이미 준비됐으면 무시된다)
        if !isEditing { DateGapHandler.shared.requestAuthorization() }
        guard !isEditing, let coordinate = draft.coordinate, draft.placeName == nil,
              let place = await ExpensePlace.resolve(coordinate) else { return }
        // 기다리는 동안 사용자가 지도에서 다른 곳을 골랐으면 그것이 답이다.
        guard draft.placeName == nil else { return }
        draft.placeName = place.name

        guard draft.country == ExpenseCode.unknownCountry, let country = place.country else { return }
        draft.country = country
        if mayFollowLocationCurrency, let code = ExpensePlace.primaryCurrency(of: country) {
            draft.currency = code
        }
    }

    private func save() {
        do {
            switch mode {
            case .create:
                onSaved(try store.create(from: draft))
            case .edit(let expense):
                try store.update(expense, with: draft)
                onSaved(expense)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ExpenseFormView(mode: .create(ReceiptDraft()))
}
