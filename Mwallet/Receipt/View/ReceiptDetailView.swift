//
//  ReceiptDetailView.swift
//  Mwallet
//
//  영수증 상세. 수정은 AddReceiptView 를 편집 모드로 재사용한다.
//

import PhotosUI
import SwiftUI

struct ReceiptDetailView: View {

    @Environment(\.dismiss) private var dismiss

    @ObservedObject var expense: Expense

    private let store = ReceiptStore()

    @State private var isEditing = false
    @State private var isViewingImage = false
    /// 지금 보고 있는 사진의 차례. 상세와 전체 화면이 같은 자리를 가리키도록 함께 쓴다.
    @State private var viewingIndex = 0
    @State private var isConfirmingDeletion = false
    @State private var errorMessage: String?
    @State private var pickedItem: PhotosPickerItem?
    @State private var isAttaching = false
    @State private var isPickingFromLibrary = false
    @State private var isTakingPhoto = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                amountBlock
                    .padding(.top, 8)

                Divider()
                    .padding(.top, 20)

                ReceiptSectionTitle(text: String(localized: "상세"))
                    .padding(.top, 20)

                detailBlock
                    .padding(.top, 4)

                Divider()

                ReceiptSectionTitle(text: String(localized: "영수증"))
                    .padding(.top, 20)

                receiptSection
                    .padding(.top, 12)

                Divider()
                    .padding(.top, 20)

                Button {
                    isConfirmingDeletion = true
                } label: {
                    Text("영수증 삭제")
                        .font(.body1)
                        .foregroundStyle(.mainAccent)
                        .padding(.vertical, 16)
                }
                // 확인창은 누른 버튼에 붙인다. 화면 전체에 붙이면 버튼과
                // 동떨어진 곳에 떠서 무엇을 묻는지 한눈에 이어지지 않는다.
                .confirmationDialog(
                    "이 영수증을 삭제할까요?",
                    isPresented: $isConfirmingDeletion,
                    titleVisibility: .visible
                ) {
                    Button("삭제", role: .destructive) { delete() }
                    Button("취소", role: .cancel) { }
                } message: {
                    Text("첨부한 사진도 함께 삭제되며 되돌릴 수 없습니다.")
                }

                // 떠 있는 탭바가 마지막 항목을 가리지 않도록 여유를 둔다.
                Spacer(minLength: 100)
            }
            .padding(.horizontal, ReceiptLayout.gutter)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(expense.merchantName)
                    .font(.title1)
                    .foregroundStyle(.black)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("편집") { isEditing = true }
                    .font(.subhead2_2)
                    .foregroundStyle(.black)
            }
        }
        .onChange(of: pickedItem) { _, newItem in
            attachPhoto(from: newItem)
        }
        .sheet(isPresented: $isEditing) {
            AddReceiptView(mode: .edit(expense))
        }
        .fullScreenCover(isPresented: $isViewingImage) {
            ReceiptPhotoViewer(photos: photos, index: $viewingIndex,
                              onClose: { isViewingImage = false })
        }
        .photosPicker(isPresented: $isPickingFromLibrary, selection: $pickedItem, matching: .images)
        .fullScreenCover(isPresented: $isTakingPhoto) {
            CameraPicker { data in
                isTakingPhoto = false
                attachCaptured(data)
            } onCancel: {
                isTakingPhoto = false
            }
            .ignoresSafeArea()
        }
        .alert("처리하지 못했습니다", isPresented: errorBinding) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 영수증 사진

    private var photos: [Data] { expense.photoDataList }

    /// 사진 아래 한 줄. 여러 장일 때는 지금 몇 번째인지도 알린다.
    private var photoCaption: String {
        let size = ReceiptImageProcessor.formattedSize(
            bytes: photos.reduce(0) { $0 + $1.count })
        guard photos.count > 1 else { return String(localized: "사진을 누르면 크게 볼 수 있어요 · \(size)") }
        return String(localized: "\(viewingIndex + 1)/\(photos.count)장 · 누르면 크게 볼 수 있어요 · \(size)")
    }

    // 등록돼 있으면 사진을, 없으면 바로 첨부할 수 있는 버튼을 하단에 보여 준다.
    @ViewBuilder
    private var receiptSection: some View {
        if !photos.isEmpty {
            // 여러 장이면 옆으로 넘긴다. 세로로 쌓으면 영수증 한 건을 보는데
            // 화면을 몇 번씩 굴려야 해서 다른 항목이 눈에서 사라진다.
            TabView(selection: $viewingIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        Button {
                            isViewingImage = true
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                    }
                }
            }
            // 점을 띄우지 않는다. 흰 점이라 밝은 영수증 위에서는 보이지 않고,
            // 아래 한 줄이 이미 '1/2장' 이라 몇 번째인지 말해 준다.
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)

            Text(photoCaption)
                .font(.caption1)
                .foregroundStyle(.gray300)
                .padding(.top, 8)
        } else {
            // 목록의 썸네일과 같은 메뉴를 쓴다. 여기서만 보관함으로 곧장
            // 들어가면, 방금 받은 영수증을 찍으려 할 때 목록으로 되돌아가야 한다.
            Menu {
                ReceiptPhotoSourceButtons(onPickLibrary: { isPickingFromLibrary = true },
                                          onTakePhoto: { isTakingPhoto = true })
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    Text(isAttaching ? String(localized: "불러오는 중…") : String(localized: "영수증 사진 첨부"))
                }
                .font(.body1)
                .foregroundStyle(.gray400)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isAttaching)

            Text("사진은 장변 \(Int(ReceiptImageProcessor.maxDimension))px 로 줄여 저장합니다.")
                .font(.caption1)
                .foregroundStyle(.gray300)
                .padding(.top, 8)
        }
    }

}

// 금액·상세 블록과 동작. 본문이 길어져 화면 짜임과 갈라 둔다.
extension ReceiptDetailView {

    // MARK: - 금액

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(expense.formattedAmount)
                .font(.display4)
                .foregroundStyle(.black)
                .monospacedDigit()

            if expense.currencyCode != ExpenseCode.baseCurrency {
                if let rate = expense.validExchangeRate {
                    Text("\(expense.formattedAmountInKRW) · 1 \(expense.currencyCode) = \(ReceiptFormat.exchangeRate(rate))")
                        .font(.caption2)
                        .foregroundStyle(.gray300)
                        .padding(.top, 6)
                } else {
                    unavailableRate
                        .padding(.top, 10)
                }
            }
        }
    }

    // 오프라인에서 기록해 환율을 못 받은 건을 되살리는 통로.
    // 목록에서 "합계에서 빠졌습니다" 라고 알리기만 하고 고칠 방법이 없으면 막다른 길이 된다.
    private var unavailableRate: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReceiptNotice(text: String(localized: "환율을 받지 못해 원화 합계에서 빠져 있어요"))

            Button {
                applyCurrentRate()
            } label: {
                Text("현재 환율 적용")
                    .font(.caption2)
                    .foregroundStyle(.black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("지출 당일이 아닌 오늘 기준 환율이 적용됩니다.")
                .font(.caption1)
                .foregroundStyle(.gray300)
        }
    }

    // MARK: - 상세

    private var detailBlock: some View {
        VStack(spacing: 0) {
            ReceiptValueRow(label: String(localized: "여행"), value: expense.missionTitle)
            Divider()
            ReceiptValueRow(label: String(localized: "카테고리"),
                            value: ExpenseInfoCategory.displayName(forStored: expense.categoryName))
            Divider()
            ReceiptValueRow(label: String(localized: "결제 일자"), value: expense.formattedDate())

            if expense.recordedTimeZone.identifier != TimeZone.current.identifier {
                Divider()
                ReceiptValueRow(label: String(localized: "기록 지역"), value: expense.recordedTimeZone.identifier)
            }

            if !expense.memoText.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("메모")
                        .font(.body1)
                        .foregroundStyle(.gray400)
                    Text(expense.memoText)
                        .font(.body1)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 동작

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private func applyCurrentRate() {
        do {
            try store.applyCurrentExchangeRate(to: expense)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 편집 폼을 열지 않고 상세에서 바로 사진만 붙인다.
    private func attachPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        isAttaching = true
        Task {
            defer { isAttaching = false }
            do {
                guard let original = try await item.loadTransferable(type: Data.self) else {
                    errorMessage = String(localized: "사진을 불러오지 못했습니다.")
                    return
                }
                guard let processed = ReceiptImageProcessor.process(original) else {
                    errorMessage = String(localized: "지원하지 않는 이미지 형식입니다.")
                    return
                }
                try store.attachPhoto(processed, to: expense)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // 카메라는 이미 다듬은 사진을 넘겨 준다. 목록에서 찍을 때와 같은 길이다.
    private func attachCaptured(_ data: Data) {
        do {
            try store.attachPhoto(data, to: expense)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try store.delete(expense)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
