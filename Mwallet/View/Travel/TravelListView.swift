//
//  TravelListView.swift
//  Mwallet
//
//  여행 탭. 위에 지금까지의 지출 지도, 아래에 여행을 고르는 그리드.
//
//  이 탭이 답해야 할 질문은 둘이다 — '어디를 다녔나' 와 '어느 여행을 볼까'.
//  지도가 앞을 맡고 그리드가 뒤를 맡는다.
//
//  둘을 잇는 것은 색이다. 여행마다 색 하나를 주어 지도의 점과 그리드 칸의
//  테두리를 같은 색으로 묶는다. 범례를 따로 두지 않아도 어느 점이 어느
//  여행인지 읽힌다.
//
//  칸을 4열로 좁게 두는 것은 이 그리드가 '보는 것' 이 아니라 '고르는 것'
//  이기 때문이다. 화면의 주인공은 지도이고, 그리드는 그 아래에서 한 번에
//  여러 여행을 훑을 수 있으면 된다. 자세한 것은 여행 상세에서 본다.
//

import CoreData
import MapKit
import SwiftUI

struct TravelListView: View {

    @EnvironmentObject private var mainVM: MainViewModel

    private let budgetStore = BudgetStore()

    @State private var travels: [Travel] = []
    @State private var traces: [TravelMapTrace] = []
    @State private var cameraPosition: MapCameraPosition = .automatic

    // 4열. 칸 하나가 82pt 남짓이라 사진 한 장과 이름 두 줄이 들어간다.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 12)

                headerRow

                if travels.isEmpty {
                    ReceiptEmptyState(
                        message: "아직 여행이 없어요",
                        detail: "오른쪽 위 + 로 여행을 만들면\n지출이 그 여행에 모입니다."
                    )
                } else {
                    AllTravelsMap(traces: traces, cameraPosition: $cameraPosition)
                        .padding(.horizontal, ReceiptLayout.gutter)
                        .padding(.top, 12)

                    grid
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarTitleDisplayMode(.inline)
            // 동작 버튼을 본문 첫 줄로 옮겼다. 네비게이션 바를 남겨 두면
            // 빈 밴드가 하나 더 생겨 본문 전체가 아래로 밀린다.
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: reload)
        }
    }

    // MARK: - 첫 줄

    private var headerRow: some View {
        TabHeaderRow {
            VStack(alignment: .leading, spacing: 4) {
                Text("여행")
                    .font(.title3_fixed)
                    .foregroundStyle(.black)
                Text(travels.isEmpty ? "여행을 만들어 시작하세요" : "\(travels.count)개의 여행")
                    .font(.caption2_fixed)
                    .foregroundStyle(.gray400)
            }
        } actions: {
            NavigationLink { SettingView() } label: { TabActionIcon(systemName: "gearshape") }
            NavigationLink { AddTravelView() } label: { TabActionIcon(systemName: "plus") }
        }
    }

    // MARK: - 그리드

    private var grid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(Array(travels.enumerated()), id: \.element.objectID) { index, travel in
                    NavigationLink {
                        TravelDetailView(travel: travel)
                            .environmentObject(mainVM)
                    } label: {
                        TravelGridCell(travel: travel, color: TravelPalette.color(at: index))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ReceiptLayout.gutter)
            .padding(.top, 18)
            // 떠 있는 탭바가 마지막 줄을 가리지 않도록 비워 둔다.
            .padding(.bottom, 24)
        }
    }

    // MARK: - 동작

    private func reload() {
        travels = budgetStore.availableTravels()
        traces = travels.enumerated().map { index, travel in
            TravelMapTrace(id: travel.objectID,
                           color: TravelPalette.color(at: index),
                           stops: TravelExpenseStop.stops(from: budgetStore.expenses(for: travel)))
        }
        cameraPosition = TravelMapCamera.fitted(to: traces.flatMap(\.stops))
    }
}

// MARK: - 여행 한 칸

struct TravelGridCell: View {

    let travel: Travel
    let color: Color

    private var isOngoing: Bool { TravelSchedule.state(of: travel) == .current }

    var body: some View {
        VStack(spacing: 6) {
            cover
            name
        }
    }

    // 테두리 색이 지도 위 점과 같다. 이 칸의 여행이 지도 어디에 있는지 알려 준다.
    private var cover: some View {
        // 정사각 자리를 먼저 잡고 그 안을 사진으로 채운다. 사진에 곧바로
        // scaledToFill 을 걸면 원본 비율대로 칸 밖까지 번져 그리드가 어긋난다.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let data = travel.coverImageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image("DefaultImage").resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) { ongoingMark }
    }

    // 여행 중이라는 표시. 지도의 점과 같은 생김새라 '지금 여기' 로 읽힌다.
    // 이름에 색을 입히지 않는 것은, 테두리가 이미 '어느 여행인가' 를 맡고 있어
    // 한 칸에 뜻이 다른 색이 둘이 되면 무엇을 가리키는지 흐려지기 때문이다.
    @ViewBuilder
    private var ongoingMark: some View {
        if isOngoing {
            Circle()
                .fill(Color.mainAccent)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .padding(5)
        }
    }

    private var name: some View {
        Text(travel.displayName)
            .font(.caption1_fixed)
            .foregroundStyle(.black)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
