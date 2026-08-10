//
//  AddMemberSections.swift
//  Mwallet
//
//  '이 여행은 누구와 함께하나요' 화면의 두 덩어리.
//
//    고르기   혼자 갈지 함께 갈지
//    함께     함께 간다면 누구누구인지
//
//  AddMemberView 에서 떼어 냈다. 고른 값은 화면이 계속 들고 있어야
//  '완료' 를 누를 때 쓸 수 있으므로, 상태는 그대로 두고 바인딩만 건넨다.
//

import SwiftUI

// MARK: - 혼자 갈까, 함께 갈까

struct AddMemberSelectBox: View {

    @Binding var isSelectedAlone: Bool
    @Binding var isSelectedTogether: Bool

    var body: some View {
        VStack {
            Button {
                self.isSelectedAlone = true
                self.isSelectedTogether = false
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 1)
                        .stroke(isSelectedAlone ? Color.mainAccent : Color.gray200, lineWidth: 1)
                        .frame(width: 350, height: 53)
                    
                    HStack(spacing: 0) {
                        Image(isSelectedTogether ? "selectUnactive" : "selectActive")
                            .frame(width: 21)
                            .padding(.trailing, 12)
                        
                        Text("정산이 필요 없어요")
                            .foregroundStyle(isSelectedAlone ? Color.black : Color.gray300)
                            .font(.subhead2_1)
                        
                        Spacer()
                    }
                    .padding(.leading, 10)
                    .frame(width: 350, height: 53)
                }
            }
            
            Button {
                self.isSelectedTogether = true
                self.isSelectedAlone = false
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 1)
                        .stroke(isSelectedTogether ? Color.mainAccent : Color.gray200, lineWidth: 1)
                        .frame(width: 350, height: 53)
                    
                    HStack(spacing: 0) {
                        Image(isSelectedAlone ? "selectUnactive" : "selectActive")
                            .frame(width: 21)
                            .padding(.trailing, 12)
                        
                        Text("여러 명이서 정산이 필요한 여행이에요")
                            .foregroundStyle(isSelectedTogether ? Color.black : Color.gray300)
                            .font(.subhead2_1)
                        
                        Spacer()
                    }
                    .padding(.leading, 10)
                    .frame(width: 350, height: 53)
                }
            }
        }
    }
}

// MARK: - 함께하는 사람

struct AddMemberTogetherSection: View {

    @Binding var isSelectedTogether: Bool
    @Binding var participantArr: [String]

    var body: some View {
        
        VStack {
            if self.isSelectedTogether == true {
                
                HStack {
                    Button {
                        participantArr.append("")
                    } label: {
                        ZStack {
                            Rectangle()
                                .foregroundStyle(Color.black)
                                .frame(width: 32, height: 28)
                                .cornerRadius(8)
                            
                            Image("plus_white")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 13, height: 13)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ZStack {
                                Rectangle()
                                    .foregroundColor(.clear)
                                    .frame(width: 57, height: 28)
                                    .background(Color.gray100)
                                    .cornerRadius(6)
                                
                                Text("me")
                                    .font(.subhead2_1)
                                    .foregroundStyle(Color.gray300)
                                +
                                Text(" 나")
                                    .font(.subhead2_2)
                                    .foregroundStyle(Color.black)
                            }
                            
                            participantList
                            
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }

    private var participantList: some View {
        HStack {
            HStack {
                ForEach(0..<participantArr.count, id: \.self) { index in
                    ZStack {
                        Text(participantArr[index] == "" ? "이름 입력아아아" : participantArr[index] + "아아아")
                            .font(.custom(FontsManager.WantedSans.medium, size: 16))
                            .hidden()
                        
                        TextField("이름 입력", text: $participantArr[index])
                            .modifier(ClearTextFieldButton(text: $participantArr[index], participantArr: $participantArr, index: index))
                            .font(.custom(FontsManager.WantedSans.medium, size: 16))
                            .foregroundStyle(Color.black)
                            .textFieldStyle(CustomTextFieldStyle())
                            .onChange(of: participantArr[index]) { _, newValue in
                                let maxLengthInKorean = 5
                                let maxLengthInEnglish = 8
                                
                                let characterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
                                let isEnglish = newValue.rangeOfCharacter(from: characterSet.inverted) == nil
                                
                                let maxLength = isEnglish ? maxLengthInEnglish : maxLengthInKorean
                                
                                if newValue.count > maxLength {
                                    participantArr[index] = String(newValue.prefix(maxLength))
                                }
                            }
                            .layoutPriority(-1)
                    }
                }
            }
        }
    }

    struct ClearTextFieldButton: ViewModifier {
        
        @Binding var text: String
        @Binding var participantArr: [String]
        let index: Int
        
        public func body(content: Content) -> some View {
            ZStack(alignment: .trailing) {
                content
                
                if !text.isEmpty || text.isEmpty {
                    Button {
                        participantArr.remove(at: index)
                    } label: {
                        Image("xmark 1")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .padding(.trailing, 8)
                    }
                }
            }
        }
    }

    struct CustomTextFieldStyle: TextFieldStyle {
        func _body(configuration: TextField<Self._Label>) -> some View {
            configuration
                .padding(10)
                .foregroundColor(.black)
                .frame(height: 30)
                .background(Color.gray100)
                .cornerRadius(8)
        }
    }
}
