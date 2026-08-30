//
//  CategoryDetailSheet.swift
//  Mwallet
//
//  분류 하나를 만들거나 고치는 시트.
//
//  색을 고르는 동안 다른 분류와 너무 닮았는지 그때그때 알린다. 저장할 때
//  한꺼번에 말하면 이미 마음을 정한 뒤라 늦다.
//
//  경고가 떠도 저장은 된다. 우리가 아는 것은 '읽기 어려울 수 있다' 까지이고,
//  그 화면을 실제로 쓰는 사람은 사용자다.
//

import CoreData
import SwiftUI

struct CategoryDetailSheet: View {

    @Environment(\.dismiss) private var dismiss

    let context: NSManagedObjectContext
    /// nil 이면 새로 만드는 것이다.
    let existing: ExpenseCategory?
    /// 색을 견줄 다른 분류들.
    let others: [(name: String, hex: String)]
    var onSave: () -> Void

    @State private var name = ""
    @State private var pickedColor: Color = .blue
    @State private var errorMessage: String?

    private var isNew: Bool { existing == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("예: 현지 교통", text: $name)
                        .tint(.mainAccent)
                }

                Section {
                    ColorPicker("색", selection: $pickedColor, supportsOpacity: false)
                    conflictNotice
                } header: {
                    Text("색")
                } footer: {
                    // 두 토막을 + 로 잇지 않는다. 이으면 String 이 되어 Text 가
                    // 번역할 열쇠로 보지 않고 적힌 그대로 내보낸다.
                    Text("예결산 그래프에서 이 분류를 가리키는 색입니다. 어두운 화면용 색은 자동으로 맞춥니다.")
                }

                if let existing, existing.isBuiltIn {
                    Section {
                        Text("기본 분류입니다. 이름과 색은 바꿀 수 있지만 지울 수는 없습니다 — 이미 이 분류로 적힌 기록이 있을 수 있습니다.")
                            .font(.caption1)
                            .foregroundStyle(.gray400)
                    }
                }
            }
            .navigationTitle(isNew ? "분류 추가" : "분류 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("저장하지 못했습니다", isPresented: errorBinding) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - 경고

    /// 고른 색이 다른 분류와 닮았을 때의 알림.
    ///
    /// 무엇과 닮았는지 이름을 대고, 그 색을 나란히 보여 준다. '비슷합니다' 만
    /// 적으면 무엇을 어떻게 고쳐야 할지 알 수 없다.
    @ViewBuilder
    private var conflictNotice: some View {
        if let conflict = CategoryColorCheck.conflict(of: hex(of: pickedColor), against: others) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption1)
                    .foregroundStyle(Color.mainOrange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(conflict.onlyForColorVision
                         ? "'\(conflict.name)' 과 적록색각 이상에서 구별하기 어렵습니다"
                         : "'\(conflict.name)' 과 색이 비슷합니다")
                        .font(.caption1)
                        .foregroundStyle(Color.mainOrange)

                    Text("그래프에서 두 조각이 붙어 있으면 한 덩어리로 보일 수 있습니다. 그대로 저장해도 됩니다.")
                        .font(.caption1)
                        .foregroundStyle(.gray400)
                }
            }
        }
    }

    // MARK: - 값

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })
    }

    /// SwiftUI 색을 여섯 자리 문자열로. 화면 밖(저장·비교)에서는 문자열로 다룬다.
    private func hex(of color: Color) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X",
                      Int((red * 255).rounded()),
                      Int((green * 255).rounded()),
                      Int((blue * 255).rounded()))
    }

    // MARK: - 동작

    private func load() {
        guard let existing else { return }
        name = existing.displayName
        pickedColor = Color(uiColor: UIColor(
            red: CategoryColor.components(existing.color.light).red,
            green: CategoryColor.components(existing.color.light).green,
            blue: CategoryColor.components(existing.color.light).blue,
            alpha: 1))
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let color = CategoryColor(light: hex(of: pickedColor))

        if let existing {
            existing.name = trimmed
            existing.colorHex = color.light
            existing.darkColorHex = color.dark
        } else {
            CategoryCatalog.add(name: trimmed, color: color, in: context)
        }

        do {
            try context.save()
            onSave()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
