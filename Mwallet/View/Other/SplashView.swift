//
//  SplashView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/11/10.
//

import SwiftUI

struct SplashView: View {

    @State private var isActive = false
    @State private var markProgress: CGFloat = 0
    @State private var wordmarkOpacity: Double = 0

    var body: some View {
        if isActive {
            MainView()
        } else {
            ZStack {
                // 형광 초록에서 딥 그린으로 떨어지는 세로 그라데이션.
                // 마크가 흰색이라 어느 구간에서도 또렷하게 읽힌다.
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .mainAccent, location: 0.00),
                        Gradient.Stop(color: Color(0x04A050), location: 1.00)
                    ],
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1)
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    // 획이 그어지며 M 이 완성된다. 기록을 남기는 동작을 그대로 옮긴 움직임이다.
                    MissionMarkView(progress: markProgress)
                        .frame(width: 132, height: 132)

                    Text("Mwallet")
                        .font(.custom(FontsManager.Pretendard.semiBold, fixedSize: 18))
                        .foregroundStyle(.white)
                        .opacity(wordmarkOpacity)
                }
                .padding(.bottom, 40)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85)) {
                    markProgress = 1
                }
                withAnimation(.easeIn(duration: 0.4).delay(0.7)) {
                    wordmarkOpacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
