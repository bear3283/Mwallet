//
//  CountryChoiceModal.swift
//  Mwallet
//
//  Created by Wonil Lee on 10/31/23.
//

import SwiftUI

struct CountryChoiceModal: View {
    @Binding var chosenCountry: Int
    @Binding var countryIsModified: Bool
    let countryArray: [Int]
    let currentCountry: Int

    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(.white)
            
            VStack(spacing: 0) {
                titleView
                countryArrayView
                Spacer()
            }
        }
        .ignoresSafeArea()
    }
    
    private var titleView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 32)
            HStack {
                Spacer()
                    .frame(width: 20)
                Text("지출 위치")
                    .foregroundStyle(.black)
                    .font(.title2)
                Spacer()
            }
            Spacer()
                .frame(height: 12)
        }
    }
    
    private var countryArrayView: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: 20)
            ScrollView {
                VStack {
                    Spacer()
                        .frame(height: 12)
                    ForEach(countryArray, id: \.self) { country in
                        row(country,
                            isHighlighted: chosenCountry == country
                                && !(country == currentCountry && !countryIsModified))
                    }
                    
                    if !countryArray.contains(currentCountry) {
                        row(currentCountry,
                            isHighlighted: chosenCountry == currentCountry && countryIsModified)
                    }
                }
            }
            Spacer()
                .frame(width: 20)
        }
    }

    // 고르면 바로 닫는다. 하나만 고르는 자리라 고른 뒤에 더 할 일이 없다.
    private func row(_ country: Int, isHighlighted: Bool) -> some View {
        Button {
            chosenCountry = country
            countryIsModified = true
            dismiss()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(.gray100)
                    .layoutPriority(-1)
                    .opacity(isHighlighted ? 1.0 : 0.0000001)

                HStack {
                    Image(CountryInfoModel.shared.countryResult[country]?.flagString ?? "DefaultFlag")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(.vertical, 13)

                    Text(CountryInfoModel.shared.countryResult[country]?.displayName
                         ?? String(localized: "알 수 없음"))
                        .foregroundStyle(.black)
                        .font(.subhead3_2)
                        .padding(.vertical, 16)

                    Spacer()
                }
                .padding(.horizontal, 13)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
}

#Preview {
    CountryChoiceModal(chosenCountry: .constant(3), countryIsModified: .constant(true), countryArray: [1, 3, 2, 5], currentCountry: 0)
}
