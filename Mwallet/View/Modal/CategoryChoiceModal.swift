//
//  CategoryChoiceModal.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/22/23.
//

import Foundation

import SwiftUI

struct CategoryChoiceModal: View {
    @Binding var chosenCategory: ExpenseInfoCategory
    
    var body: some View {
        ZStack {
            Color(.white)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                    .frame(height: 32)
                titleView
                Spacer()
                    .frame(height: 24)
                categoryView
            }
        }
    }
    
    private var titleView: some View {
        HStack {
            Spacer()
                .frame(width: 20)
            Text("카테고리 선택")
                .foregroundStyle(.black)
                .font(.title2)
            Spacer()
        }
    }
    
    // 카테고리 목록을 한 곳(selectable)에서 가져와 4개씩 끊어 배치한다.
    // 항목이 늘어도 이 뷰를 고치지 않아도 된다.
    private var rows: [[ExpenseInfoCategory]] {
        stride(from: 0, to: ExpenseInfoCategory.selectable.count, by: 4).map { start in
            Array(ExpenseInfoCategory.selectable[start ..< min(start + 4, ExpenseInfoCategory.selectable.count)])
        }
    }

    private var categoryView: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: 20)
            VStack(spacing: 10) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack {
                        ForEach(rows[rowIndex], id: \.self) { category in
                            cell(for: category)
                        }
                        // 마지막 줄이 4칸을 못 채우면 빈 칸으로 폭을 맞춘다.
                        ForEach(0 ..< (4 - rows[rowIndex].count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                Spacer()
            }
            Spacer()
                .frame(width: 20)
        }
    }

    private func cell(for category: ExpenseInfoCategory) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(.gray100)
                .opacity(chosenCategory == category ? 1.0 : 0.0000001)
                .layoutPriority(-1)

            VStack(spacing: 8) {
                if let symbol = category.modalSymbolName {
                    Image(systemName: symbol)
                        .font(.system(size: 28))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(category.color)
                } else {
                    Image(category.modalImageString)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
                Text(category.visibleDescription)
                    .foregroundStyle(.black)
                    .font(.subhead2_2)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .onTapGesture {
            chosenCategory = category
        }
    }
}
#Preview {
    CategoryChoiceModal(chosenCategory: .constant(.tour))
}
