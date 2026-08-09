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
    @State private var globeOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0

    var body: some View {
        if isActive {
            MainView()
        } else {
            ZStack {
                // 브랜드 코발트에서 같은 계열의 딥 코발트로 떨어지는 세로 그라데이션.
                //
                // 예전에는 아래쪽이 딥 그린(0x04A050)이었다. 브랜드 색을 형광 초록에서
                // 코발트로 바꾸면서 위쪽만 갈아 끼운 탓에, 앱을 여는 첫 화면이
                // 파랑에서 초록으로 번지며 브랜드와 어긋나 있었다.
                //
                // 한 색상 계열 안에서만 명도를 떨어뜨려 깊이를 주고,
                // 흰 마크가 어느 구간에서도 또렷하게 읽히도록 아래를 충분히 어둡게 둔다.
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .mainAccent, location: 0.00),
                        Gradient.Stop(color: Color(0x17307F), location: 1.00)
                    ],
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1)
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    // 구가 먼저 떠오르고 그 위에 W 가 그어진다.
                    // '세상이 있고, 거기에 기록을 남긴다' 는 순서다.
                    // 앱 아이콘과 같은 마크라 아이콘을 누른 손이 그대로 이어진다.
                    BrandMarkView(progress: markProgress, globeOpacity: globeOpacity)
                        .frame(width: 148, height: 148)

                    Text("Mwallet")
                        .font(.custom(FontsManager.WantedSans.semiBold, fixedSize: 18))
                        .foregroundStyle(.white)
                        .opacity(wordmarkOpacity)
                }
                .padding(.bottom, 40)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    globeOpacity = 1
                }
                withAnimation(.easeInOut(duration: 0.7).delay(0.3)) {
                    markProgress = 1
                }
                withAnimation(.easeIn(duration: 0.4).delay(0.95)) {
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
