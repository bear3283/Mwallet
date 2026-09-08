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
                    // 획이 그어지며 M 이 완성된다. 기록을 남기는 동작을 그대로 옮긴 움직임이다.
                    // 앱 아이콘과 같은 글자라 아이콘을 누른 손이 그대로 이어진다.
                    BrandMarkView(progress: markProgress)
                        .frame(width: 150, height: 150)

                    // 마크의 M 과 이름의 Mission 이 같은 글자를 가리킨다.
                    //
                    // 단기사역을 가는 사람에게 Mission 은 그대로 '선교' 다.
                    // 그렇지 않은 사람에게는 퀘스트에 가깝다 — 이 앱이 건네는
                    // 미션(오늘 쓴 것을 남겨라)을 해내는 지갑이다. 한 낱말이
                    // 두 사람에게 각각 맞는 뜻으로 읽힌다.
                    //
                    // 아이콘에서는 지갑 그림이 '무엇을 담는 것인가' 를 말하고
                    // M 이 그 위에 이름을 얹는다. 여기서는 그릴 자리가 넉넉해
                    // 글자만 크게 세우고, 지갑이라는 뜻은 이름이 진다.
                    Text("Mission Wallet")
                        .font(.custom(FontsManager.WantedSans.semiBold, fixedSize: 18))
                        .foregroundStyle(.white)
                        // 낱말이 둘로 늘면서 글자가 붙어 보인다. 살짝 벌려
                        // 마크 아래의 이름표답게 둔다.
                        .tracking(0.6)
                        .opacity(wordmarkOpacity)
                }
                .padding(.bottom, 40)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85)) {
                    markProgress = 1
                }
                withAnimation(.easeIn(duration: 0.4).delay(0.75)) {
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
