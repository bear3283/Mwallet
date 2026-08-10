//
//  ReceiptEvidenceFields.swift
//  Mwallet
//
//  영수증을 남길 때의 '증빙' 두 칸 — 사진과 위치.
//
//  AddReceiptView 에서 떼어 냈다. 둘 다 자기 상태(고르는 중인지, 처리
//  중인지)를 스스로 들고 있어, 밖에서는 무엇이 담겼는지만 알면 된다.
//

import PhotosUI
import SwiftUI

// MARK: - 사진

struct ReceiptPhotoField: View {

    @Binding var draft: ReceiptDraft
    @Binding var errorMessage: String?
    /// 사진을 다듬는 동안에는 저장 버튼이 잠긴다. 그 판단은 밖에서 하므로
    /// 이 상태만 밖과 나눠 갖는다.
    @Binding var isProcessingImage: Bool

    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data = draft.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Text(ReceiptImageProcessor.formattedSize(of: data))
                        .font(.caption1_fixed)
                        .foregroundStyle(.gray300)
                    Spacer()
                    Button {
                        draft.imageData = nil
                        pickedItem = nil
                    } label: {
                        Text("사진 삭제")
                            .font(.caption2_fixed)
                            .foregroundStyle(.mainAccent)
                    }
                }
            } else {
                // PhotosPicker 의 label 클로저는 메인 액터에 묶여 있지 않다.
                // 화면 상태를 안에서 읽지 않도록 문자열을 미리 뽑아 둔다.
                let title = isProcessingImage ? "불러오는 중…" : "영수증 사진 첨부"
                PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text(title)
                    }
                    .font(.body1_fixed)
                    .foregroundStyle(.gray400)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isProcessingImage)

                Text("사진은 장변 \(Int(ReceiptImageProcessor.maxDimension))px 로 줄여 저장합니다.")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
            }
        }
        .padding(.top, 12)
        .onChange(of: pickedItem) { _, newItem in
            loadImage(from: newItem)
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        isProcessingImage = true
        Task {
            defer { isProcessingImage = false }
            do {
                guard let original = try await item.loadTransferable(type: Data.self) else {
                    errorMessage = "사진을 불러오지 못했습니다."
                    return
                }
                guard let processed = ReceiptImageProcessor.process(original) else {
                    errorMessage = "지원하지 않는 이미지 형식입니다."
                    return
                }
                draft.imageData = processed
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - 위치

struct ReceiptLocationField: View {

    @Binding var draft: ReceiptDraft

    @State private var isPickingLocation = false

    var body: some View {
        Button {
            isPickingLocation = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: draft.coordinate == nil ? "mappin.slash" : "mappin.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(draft.coordinate == nil ? Color.gray300 : Color.mainAccent)

                VStack(alignment: .leading, spacing: 2) {
                    if let name = draft.placeName, draft.coordinate != nil {
                        Text(name)
                            .font(.body1_fixed)
                            .foregroundStyle(.black)
                            .lineLimit(1)
                        Text("지도에서 다시 고르기")
                            .font(.caption1_fixed)
                            .foregroundStyle(.gray300)
                    } else {
                        Text("어디서 썼나요")
                            .font(.body1_fixed)
                            .foregroundStyle(.gray400)
                        Text("지도로 위치를 남겨 두면 나중에 지출을 지도에서 볼 수 있어요")
                            .font(.caption1_fixed)
                            .foregroundStyle(.gray300)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray300)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPickingLocation) {
            LocationPickerView(initial: draft.coordinate) { coordinate, name in
                draft.coordinate = coordinate
                draft.placeName = name
            }
        }
    }
}
