//
//  ReceiptPhotoViewer.swift
//  Mwallet
//
//  영수증 사진을 화면 가득 본다.
//
//  영수증은 글씨가 작아 상세의 작은 자리로는 금액을 확인하기 어렵다.
//  검은 바탕에 사진만 남기고, 여러 장이면 옆으로 넘긴다.
//
//  상세와 같은 자리를 가리키도록 차례를 밖에서 받는다. 안에서 따로 들면
//  상세에서 두 번째 사진을 보다 눌렀는데 첫 장이 열린다.
//

import SwiftUI

struct ReceiptPhotoViewer: View {

    let photos: [Data]
    @Binding var index: Int
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.offset) { offset, data in
                    if let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .tag(offset)
                    }
                }
            }
            // 여기서는 점을 띄운다. 검은 바탕이라 흰 점이 잘 보이고,
            // 전체 화면에는 몇 번째인지 알려 줄 글이 따로 없다.
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .accessibilityLabel("닫기")
                }
                Spacer()
            }
        }
    }
}
