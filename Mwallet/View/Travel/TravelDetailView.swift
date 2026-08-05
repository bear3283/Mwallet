//
//  TravelDetailView.swift
//  Mwallet
//
//  Created by GYURI PARK on 2023/10/26.
//
//  여행 상세. 지도와 지출 흐름이 주인공이다.
//  기간·국가·인원은 한 번 확인하면 되는 값이라 위쪽 한 줄로 접어 두고,
//  화면의 대부분은 '어디서 어떤 순서로 썼는가' 에 쓴다.
//

import CoreData
import MapKit
import SwiftUI

struct TravelDetailView: View {

    @EnvironmentObject var mainVM: MainViewModel
    @Environment(\.dismiss) private var dismiss

    private let budgetStore = BudgetStore()

    let travel: Travel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var highlightedID: NSManagedObjectID?
    @State private var isWarningOn = false
    @State private var refreshToken = UUID()

    init(travel: Travel) {
        self.travel = travel
    }

    // MARK: - 파생 값

    private var stops: [TravelExpenseStop] {
        _ = refreshToken
        return TravelExpenseStop.stops(from: budgetStore.expenses(for: travel))
    }

    private var summary: BudgetSummary {
        _ = refreshToken
        return budgetStore.summary(for: travel)
    }

    private var travelName: String {
        let name = travel.name ?? ""
        return name.isEmpty ? "이름 없는 여행" : name
    }

    private var isOngoing: Bool {
        let now = Date()
        return (travel.startDate ?? .distantFuture) <= now && now <= (travel.endDate ?? .distantFuture)
    }

    private var dayCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: travel.startDate ?? Date())
        let today = calendar.startOfDay(for: Date())
        return max(calendar.dateComponents([.day], from: start, to: today).day ?? 0, 0) + 1
    }

    private var periodText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "MM.dd"
        guard let start = travel.startDate else { return "미정" }
        guard let end = travel.endDate else { return "\(formatter.string(from: start)) ~ 미정" }
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    // 지출에 남은 국가 코드로 방문 국가를 만든다.
    private var countries: [CountryInfo] {
        _ = refreshToken
        let indices = Set(budgetStore.expenses(for: travel).map { Int($0.country) })
        return indices
            .sorted()
            .compactMap { CountryInfoModel.shared.countryResult[$0] }
            .filter { $0.koreanNm != "알 수 없음" }
    }

    private var participants: [String] {
        ["나"] + (travel.participantArray ?? [])
    }

    // MARK: - 본문

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    basicInfoStrip
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 16)

                    mapSection
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 20)

                    expenseListSection
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 24)

                    // 하단 버튼에 가리지 않도록 여유를 둔다.
                    Spacer(minLength: 120)
                }
            }

            bottomButtons
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.black)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isWarningOn = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.black)
                }
            }
        }
        .alert("여행 삭제하기", isPresented: $isWarningOn) {
            Button("삭제하기", role: .destructive, action: deleteTravel)
            Button("취소", role: .cancel) { }
        } message: {
            Text("현재 선택한 여행방에 저장된 지출 기록 및 관련 데이터를 모두 삭제할까요?")
        }
        .onAppear {
            refreshToken = UUID()
            cameraPosition = TravelMapCamera.fitted(to: stops)
        }
    }

    // MARK: - 머리말

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isOngoing {
                HStack(spacing: 6) {
                    Text("여행 중")
                        .font(.caption1_fixed)
                        .foregroundStyle(Color.mainAccent)
                    Text("DAY \(dayCount)")
                        .font(.caption1_fixed)
                        .foregroundStyle(.gray400)
                        .monospacedDigit()
                }
            }

            Text(travelName)
                .font(.display2_fixed)
                .foregroundStyle(.black)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ReceiptLayout.gutter)
        .padding(.top, 8)
    }

    // MARK: - 기본 정보 (기간 · 국가 · 인원)

    private var basicInfoStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            infoCell(title: "기간", value: periodText)

            divider

            infoCell(title: "국가",
                     value: countries.isEmpty ? "기록 없음" : countries.map(\.koreanNm).joined(separator: ", "))

            divider

            infoCell(title: "인원", value: "\(participants.count)명")
        }
        .padding(.vertical, 12)
        .background(Color.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func infoCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption1_fixed)
                .foregroundStyle(.gray300)
            Text(value)
                .font(.caption2_fixed)
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray200)
            .frame(width: 0.5, height: 30)
    }

    // MARK: - 지도

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Text("지출한 곳")
                    .font(.subhead1_fixed)
                    .foregroundStyle(.gray400)
                Spacer()
                if !stops.isEmpty {
                    Text("\(stops.count)곳 · 기록 순서")
                        .font(.caption1_fixed)
                        .foregroundStyle(.gray300)
                }
            }

            TravelExpenseMap(
                stops: stops,
                cameraPosition: $cameraPosition,
                height: 360,
                highlightedID: highlightedID,
                onSelect: focus(on:)
            )
        }
    }

    // MARK: - 지출 순서 목록

    private var expenseListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Text("지출 순서")
                    .font(.subhead1_fixed)
                    .foregroundStyle(.gray400)
                Spacer()
                Text(ReceiptFormat.krw(summary.totalSpent))
                    .font(.subhead1_fixed)
                    .foregroundStyle(.gray400)
                    .monospacedDigit()
            }

            if stops.isEmpty {
                // 빈 화면은 다음에 할 일을 알려 준다.
                Text("아직 위치가 남은 지출이 없습니다.\n기록할 때 위치를 함께 남기면 들른 순서가 지도에 그려집니다.")
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray300)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        Button {
                            focus(on: stop)
                        } label: {
                            TravelExpenseRow(
                                stop: stop,
                                isHighlighted: stop.id == highlightedID,
                                isFirst: index == 0,
                                isLast: index == stops.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 하단 버튼

    private var bottomButtons: some View {
        HStack {
            MediumButtonWhite(title: "예결산 보기", action: {
                mainVM.selectedTravel = travel
                NavigationUtil.popToRootView()
                mainVM.navigationToExpenseView()
            })

            MediumButtonMain(title: "지출 기록하기", action: {
                mainVM.selectedTravel = travel
                NavigationUtil.popToRootView()
                mainVM.navigationToRecordView()
            })
        }
        .padding(.horizontal, ReceiptLayout.gutter)
        .padding(.top, 10)
        .background(
            LinearGradient(colors: [Color.white.opacity(0), Color.white, Color.white],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    // MARK: - 동작

    // 목록이나 핀을 누르면 그 지점을 지도 가운데로 옮기고 강조한다.
    private func focus(on stop: TravelExpenseStop) {
        withAnimation(.snappy) {
            highlightedID = stop.id
            cameraPosition = TravelMapCamera.focused(on: stop)
        }
    }

    private func deleteTravel() {
        let deletedID = travel.id

        // 화면이 사라진 뒤에 지워야, 삭제된 객체를 그리려다 죽지 않는다.
        dismiss()

        DispatchQueue.main.async {
            PersistenceController.shared.deleteItems(object: travel)

            if let deletedID,
               deletedID == mainVM.selectedTravel?.id || deletedID == mainVM.selectedTravelInExpense?.id {
                mainVM.selectedTravelInExpense = findInitialTravelInExpense()
                mainVM.selectedTravel = findCurrentTravel()
            }
        }
    }
}
