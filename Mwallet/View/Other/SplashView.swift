//
//  SplashView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/11/10.
//

import SwiftUI

struct SplashView: View {
    
    @State private var isActive = false
    
    var body: some View {
        if isActive {
            MainView()
        } else {
            ZStack {
                
                Rectangle()
                    // 형광 초록에서 딥 그린으로 떨어지는 세로 그라데이션.
                    // 로고가 흰색이라 어느 구간에서도 또렷하게 읽힌다.
                    .overlay(LinearGradient(
                        stops: [
                            Gradient.Stop(color: .mainGreen, location: 0.00),
                            Gradient.Stop(color: Color(0x04A050), location: 1.00)
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    ))
                    .ignoresSafeArea()
                
                LottieView(name: "Splash", animationSpeed: 1.2)
                    .frame(width: 260, height: 260)
                    .padding(.bottom, 60)
                    .ignoresSafeArea()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
