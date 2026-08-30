//
//  BudgetEditView.swift
//  Mwallet
//
//  카테고리별 예산 입력.
//  비워 두면 '배정하지 않음' 이고, 저장할 때 해당 예산 레코드를 지운다.
//

import SwiftUI

struct BudgetEditView: View {

    @Environment(\.dismiss) private var dismiss

    let travel: Travel

    private let store = BudgetStore()

    @State private var amounts: [Int64: String] = [:]
    @State private var categories: [ExpenseCategory] = []
    @State private var isEditingCategories = false
    @State private var errorMessage: String?
    @FocusState private var focused: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        totalBlock
                            .padding(.top, 12)

                        Divider()
                            .padding(.top, 20)

                        ReceiptSectionTitle(text: String(localized: "카테고리별 예산"))
                            .padding(.top, 20)

                        ForEach(categories, id: \.objectID) { category in
                            categoryField(category)
                        }

                        categoryEditLink

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, ReceiptLayout.gutter)
                }

                ReceiptPrimaryButton(title: String(localized: "저장")) { save() }
                    .padding(.horizontal, ReceiptLayout.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(travel.name ?? String(localized: "예산 편집"))
                        .font(.title1)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .font(.subhead2_2)
                        .foregroundStyle(.gray400)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focused = nil }
                }
            }
            .alert("저장하지 못했습니다", isPresented: errorBinding) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: load)
            .sheet(isPresented: $isEditingCategories, onDismiss: load) {
                CategoryEditView(context: store.context)
            }
        }
    }

    // MARK: - 총액

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("총 예산")
                .font(.caption2)
                .foregroundStyle(.gray300)
            Text(ReceiptFormat.krw(total))
                .font(.display4)
                .foregroundStyle(.black)
                .monospacedDigit()
            Text("비워 두면 예산을 잡지 않은 항목으로 둡니다.")
                .font(.caption1)
                .foregroundStyle(.gray300)
        }
    }

    // MARK: - 카테고리 입력

    /// 분류를 만들고 지우고 색을 고르는 자리로 간다.
    ///
    /// 금액과 분류 정의는 성격이 다르다. 한 화면에 섞으면 예산을 적으러 왔다가
    /// 분류를 지우는 일이 생긴다.
    private var categoryEditLink: some View {
        Button {
            isEditingCategories = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3").font(.caption1)
                Text("분류 만들기 · 색 바꾸기").font(.body1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption1)
            }
            .foregroundStyle(Color.mainAccent)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func categoryField(_ category: ExpenseCategory) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(category.color.swiftUIColor)
                    .frame(width: 10, height: 10)

                Text(category.displayName)
                    .font(.body1)
                    .foregroundStyle(.black)

                Spacer(minLength: 8)

                TextField("0", text: binding(for: category.code))
                    .font(.subhead2_1)
                    .foregroundStyle(.black)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused, equals: Int(category.code))
                    .tint(.mainAccent)
                    .frame(maxWidth: 140)

                Text("원")
                    .font(.caption2)
                    .foregroundStyle(.gray400)
            }
            .padding(.vertical, 14)

            Divider()
        }
    }

    // MARK: - 파생 값

    private var total: Double {
        amounts.values.reduce(0) { $0 + (parse($1) ?? 0) }
    }

    private func binding(for code: Int64) -> Binding<String> {
        Binding(
            get: { amounts[code] ?? "" },
            set: { amounts[code] = $0 }
        )
    }

    private func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
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

    private func load() {
        categories = CategoryCatalog.visible(in: store.context)
        var loaded: [Int64: String] = [:]
        for budget in store.budgets(for: travel) where budget.amount > 0 {
            loaded[budget.category] = String(Int(budget.amount))
        }
        amounts = loaded
    }

    private func save() {
        var parsed: [Int64: Double] = [:]
        for (code, text) in amounts {
            if let value = parse(text) { parsed[code] = value }
        }
        do {
            try store.save(parsed, for: travel)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
