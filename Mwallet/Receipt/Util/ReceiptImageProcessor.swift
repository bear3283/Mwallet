//
//  ReceiptImageProcessor.swift
//  Mwallet
//
//  영수증 사진을 저장 가능한 크기로 줄인다.
//  원본을 그대로 넣으면 건당 3~5MB 가 되어 로컬 저장소가 급격히 커지고,
//  CloudKit 동기화를 켰을 때 레코드 하나가 1MB 제한에 걸릴 수 있다.
//

import UIKit

enum ReceiptImageProcessor {

    // 장변 기준 최대 픽셀. 영수증 글자를 읽기에 충분한 해상도다.
    static let maxDimension: CGFloat = 1600
    static let compressionQuality: CGFloat = 0.7

    // 사진 라이브러리에서 받은 원본 Data 를 축소·압축한다.
    // 디코딩에 실패하면 nil 을 돌려주어 호출부가 첨부를 취소하도록 한다.
    static func process(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: compressionQuality)
    }

    static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longSide = max(image.size.width, image.size.height)
        guard longSide > maxDimension else { return image }

        let scale = maxDimension / longSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // 목록에서 용량을 보여줄 때 쓴다.
    static func formattedSize(of data: Data) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}
