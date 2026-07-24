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

    @State private var amounts: [ExpenseInfoCategory: String] = [:]
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

                        ReceiptSectionTitle(text: "카테고리별 예산")
                            .padding(.top, 20)

                        ForEach(ExpenseInfoCategory.selectable, id: \.rawValue) { category in
                            categoryField(category)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, ReceiptLayout.gutter)
                }

                ReceiptPrimaryButton(title: "저장") { save() }
                    .padding(.horizontal, ReceiptLayout.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(travel.name ?? "예산 편집")
                        .font(.subhead3_1_fixed)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .font(.subhead2_2_fixed)
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
        }
    }

    // MARK: - 총액

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("총 예산")
                .font(.caption2_fixed)
                .foregroundStyle(.gray300)
            Text(ReceiptFormat.krw(total))
                .font(.display4_fixed)
                .foregroundStyle(.black)
                .monospacedDigit()
            Text("비워 두면 예산을 잡지 않은 항목으로 둡니다.")
                .font(.caption1_fixed)
                .foregroundStyle(.gray300)
        }
    }

    // MARK: - 카테고리 입력

    private func categoryField(_ category: ExpenseInfoCategory) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(ReceiptCategoryPalette.color(for: category.description))
                    .frame(width: 10, height: 10)

                Text(category.description)
                    .font(.body1_fixed)
                    .foregroundStyle(.black)

                Spacer(minLength: 8)

                TextField("0", text: binding(for: category))
                    .font(.subhead2_1_fixed)
                    .foregroundStyle(.black)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused, equals: category.rawValue)
                    .tint(.mainGreen)
                    .frame(maxWidth: 140)

                Text("원")
                    .font(.caption2_fixed)
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

    private func binding(for category: ExpenseInfoCategory) -> Binding<String> {
        Binding(
            get: { amounts[category] ?? "" },
            set: { amounts[category] = $0 }
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
        var loaded: [ExpenseInfoCategory: String] = [:]
        for budget in store.budgets(for: travel) where budget.amount > 0 {
            guard let category = ExpenseInfoCategory(rawValue: Int(budget.category)) else { continue }
            loaded[category] = String(Int(budget.amount))
        }
        amounts = loaded
    }

    private func save() {
        var parsed: [ExpenseInfoCategory: Double] = [:]
        for (category, text) in amounts {
            if let value = parse(text) { parsed[category] = value }
        }
        do {
            try store.save(parsed, for: travel)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
