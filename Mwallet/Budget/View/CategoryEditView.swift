//
//  CategoryEditView.swift
//  Mwallet
//
//  분류를 만들고, 이름과 색을 고치고, 지우는 자리.
//
//  색은 자유롭게 고르게 한다. 자기 장부의 색은 자기가 정하는 것이다.
//  다만 예결산의 도넛은 조각끼리 색으로만 갈리므로, 다른 분류와 너무 닮은
//  색을 고르면 알린다 — 막지는 않고, 모르고 지나치지만 않게 한다.
//
//  지우기는 두 갈래다. 붙박이와 이미 쓰이고 있는 분류는 지우지 않고 감춘다.
//  그 판단은 CategoryCatalog 가 하고 여기서는 결과만 말로 옮긴다.
//

import CoreData
import SwiftUI

struct CategoryEditView: View {

    @Environment(\.dismiss) private var dismiss
    let context: NSManagedObjectContext

    @State private var categories: [ExpenseCategory] = []
    @State private var editing: ExpenseCategory?
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories, id: \.objectID) { category in
                        row(category)
                    }
                } header: {
                    Text("분류")
                } footer: {
                    Text("색은 예결산 그래프에서 이 분류를 가리킵니다. 붙박이 분류와 이미 쓰인 분류는 지우는 대신 목록에서 감춥니다.")
                }

                if !hidden.isEmpty {
                    Section("감춘 분류") {
                        ForEach(hidden, id: \.objectID) { category in
                            hiddenRow(category)
                        }
                    }
                }
            }
            .navigationTitle("분류 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("분류 추가")
                }
            }
            .sheet(isPresented: $isAdding) {
                CategoryDetailSheet(context: context, existing: nil, others: colorPeers(excluding: nil)) {
                    reload()
                }
            }
            .sheet(item: $editing) { category in
                CategoryDetailSheet(context: context,
                                    existing: category,
                                    others: colorPeers(excluding: category)) {
                    reload()
                }
            }
            .alert("저장하지 못했습니다", isPresented: errorBinding) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: reload)
        }
    }

    // MARK: - 줄

    private func row(_ category: ExpenseCategory) -> some View {
        Button {
            editing = category
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(category.color.swiftUIColor)
                    .frame(width: 18, height: 18)

                Text(category.displayName)
                    .foregroundStyle(.black)

                if category.isBuiltIn {
                    Text("기본")
                        .font(.caption1)
                        .foregroundStyle(.gray400)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption1)
                    .foregroundStyle(.gray300)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                remove(category)
            } label: {
                Label(category.isBuiltIn ? "감추기" : "지우기",
                      systemImage: category.isBuiltIn ? "eye.slash" : "trash")
            }
        }
    }

    private func hiddenRow(_ category: ExpenseCategory) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(category.color.swiftUIColor.opacity(0.4))
                .frame(width: 18, height: 18)
            Text(category.displayName)
                .foregroundStyle(.gray400)
            Spacer(minLength: 8)
            Button("다시 쓰기") {
                category.isHidden = false
                save()
            }
            .font(.caption1)
            .foregroundStyle(Color.mainAccent)
        }
    }

    // MARK: - 값

    private var hidden: [ExpenseCategory] {
        CategoryCatalog.all(in: context).filter(\.isHidden)
    }

    /// 색을 견줄 상대. 자기 자신은 뺀다.
    private func colorPeers(excluding category: ExpenseCategory?) -> [(name: String, hex: String)] {
        CategoryCatalog.all(in: context)
            .filter { $0.objectID != category?.objectID && !$0.isHidden }
            .map { (name: $0.displayName, hex: $0.color.light) }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - 동작

    private func reload() {
        categories = CategoryCatalog.visible(in: context)
    }

    private func remove(_ category: ExpenseCategory) {
        CategoryCatalog.remove(category, in: context)
        save()
    }

    private func save() {
        do {
            try context.save()
            reload()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
