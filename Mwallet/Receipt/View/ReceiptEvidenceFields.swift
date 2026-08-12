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

    /// 한 지출에 붙일 수 있는 사진의 수.
    ///
    /// 영수증은 앞면·뒷면·카드전표 정도라 다섯이면 넉넉하다. 막아 두지 않으면
    /// 앨범을 통째로 고르는 일이 생기고, 그만큼 저장소와 동기화가 무거워진다.
    static let limit = 5

    @Binding var draft: ReceiptDraft
    @Binding var errorMessage: String?
    /// 사진을 다듬는 동안에는 저장 버튼이 잠긴다. 그 판단은 밖에서 하므로
    /// 이 상태만 밖과 나눠 갖는다.
    @Binding var isProcessingImage: Bool

    @State private var pickedItems: [PhotosPickerItem] = []

    private var canAddMore: Bool { draft.photos.count < Self.limit }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if draft.photos.isEmpty {
                emptyPicker
            } else {
                thumbnails
                footer
            }
        }
        .padding(.top, 12)
        .onChange(of: pickedItems) { _, items in
            load(items)
        }
    }

    // MARK: - 아직 없을 때

    private var emptyPicker: some View {
        // PhotosPicker 의 label 클로저는 메인 액터에 묶여 있지 않다.
        // 화면 상태를 안에서 읽지 않도록 문자열을 미리 뽑아 둔다.
        let title = isProcessingImage ? "불러오는 중…" : "영수증 사진 첨부"
        return VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(selection: $pickedItems,
                         maxSelectionCount: Self.limit,
                         matching: .images,
                         photoLibrary: .shared()) {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    Text(title)
                }
                .font(.body1)
                .foregroundStyle(.gray400)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isProcessingImage)

            Text("최대 \(Self.limit)장까지, 장변 \(Int(ReceiptImageProcessor.maxDimension))px 로 줄여 저장합니다.")
                .font(.caption1)
                .foregroundStyle(.gray300)
        }
    }

    // MARK: - 붙인 뒤

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(draft.photos.enumerated()), id: \.offset) { index, data in
                    thumbnail(data, at: index)
                }
                if canAddMore { addTile }
            }
            .padding(.vertical, 2)
        }
    }

    private func thumbnail(_ data: Data, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // 열지 못하는 사진도 자리는 지킨다. 그래야 몇 번째가
                    // 잘못됐는지 보고 지울 수 있다.
                    Color.gray100.overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.gray400)
                    }
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                draft.photos.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("\(index + 1)번째 사진 지우기")
        }
    }

    private var addTile: some View {
        // 위와 같은 이유로 화면 상태를 라벨 클로저 안에서 읽지 않는다.
        let icon = isProcessingImage ? "ellipsis" : "plus"
        return PhotosPicker(selection: $pickedItems,
                            maxSelectionCount: Self.limit - draft.photos.count,
                            matching: .images,
                            photoLibrary: .shared()) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray100)
                .frame(width: 92, height: 92)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.gray400)
                }
        }
        .disabled(isProcessingImage)
        .accessibilityLabel("사진 더 붙이기")
    }

    private var footer: some View {
        HStack {
            Text("\(draft.photos.count)장 · \(ReceiptImageProcessor.formattedSize(bytes: totalBytes))")
                .font(.caption1)
                .foregroundStyle(.gray300)
            Spacer()
            Button {
                draft.photos.removeAll()
                pickedItems = []
            } label: {
                Text("모두 삭제")
                    .font(.caption2)
                    .foregroundStyle(.mainAccent)
            }
        }
    }

    /// 붙인 사진을 다 합친 크기. 한 장씩 재면 얼마나 무거운지 알기 어렵다.
    private var totalBytes: Int {
        draft.photos.reduce(0) { $0 + $1.count }
    }

    // MARK: - 불러오기

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isProcessingImage = true

        Task {
            defer {
                isProcessingImage = false
                // 고른 것을 비워야 같은 사진을 다시 고를 수 있다.
                pickedItems = []
            }

            var loaded: [Data] = []
            for item in items {
                // 한 장이 실패해도 나머지는 붙인다. 여러 장을 고른 뒤
                // 하나 때문에 전부 잃으면 다시 고르는 수고가 크다.
                do {
                    guard let original = try await item.loadTransferable(type: Data.self) else {
                        errorMessage = "사진을 불러오지 못했습니다."
                        continue
                    }
                    guard let processed = ReceiptImageProcessor.process(original) else {
                        errorMessage = "지원하지 않는 이미지 형식입니다."
                        continue
                    }
                    loaded.append(processed)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }

            let room = Self.limit - draft.photos.count
            if loaded.count > room {
                errorMessage = "사진은 \(Self.limit)장까지 붙일 수 있습니다."
            }
            draft.photos.append(contentsOf: loaded.prefix(max(room, 0)))
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
                            .font(.body1)
                            .foregroundStyle(.black)
                            .lineLimit(1)
                        Text("지도에서 다시 고르기")
                            .font(.caption1)
                            .foregroundStyle(.gray300)
                    } else {
                        Text("어디서 썼나요")
                            .font(.body1)
                            .foregroundStyle(.gray400)
                        Text("지도로 위치를 남겨 두면 나중에 지출을 지도에서 볼 수 있어요")
                            .font(.caption1)
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
