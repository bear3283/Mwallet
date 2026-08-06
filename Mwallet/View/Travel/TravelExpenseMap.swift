//
//  TravelExpenseMap.swift
//  Mwallet
//
//  한 여행에서 돈을 쓴 곳을 지도에 찍는다.
//  핀에는 기록 순서(1, 2, 3…)를 적어, 지도만 봐도 어디부터 들렀는지 읽힌다.
//
//  여행 지도 탭(TravelMapView)과 여행 상세(TravelDetailView)가 함께 쓴다.
//  두 화면이 각자 지도를 그리면 핀 모양과 번호 규칙이 갈라지므로 여기 모은다.
//

import CoreData
import CoreLocation
import MapKit
import SwiftUI

// MARK: - 지도에 찍을 한 곳

struct TravelExpenseStop: Identifiable {

    let id: NSManagedObjectID
    let order: Int                       // 기록 순서. 1부터 센다.
    let coordinate: CLLocationCoordinate2D
    let merchantName: String
    let category: ExpenseInfoCategory
    let paidDate: Date
    let amountInKRW: Double?
    let currencyCode: String
    let payAmount: Double

    // 좌표가 있는 지출만 이른 순서대로 세워 번호를 매긴다.
    // BudgetStore 는 최신순으로 주므로 여기서 다시 정렬한다.
    static func stops(from expenses: [Expense]) -> [TravelExpenseStop] {
        expenses
            .filter { $0.coordinate != nil }
            .sorted { $0.paidDate < $1.paidDate }
            .enumerated()
            .compactMap { index, expense in
                guard let coordinate = expense.coordinate else { return nil }
                return TravelExpenseStop(
                    id: expense.objectID,
                    order: index + 1,
                    coordinate: coordinate,
                    merchantName: expense.merchantName,
                    category: ExpenseInfoCategory(rawValue: Int(expense.category)) ?? .unknown,
                    paidDate: expense.paidDate,
                    amountInKRW: expense.amountInKRW,
                    currencyCode: expense.currencyCode,
                    payAmount: expense.payAmount
                )
            }
    }

    // 원화면 환산 표기를 겹쳐 쓰지 않는다.
    var amountText: String {
        if currencyCode == ExpenseCode.baseCurrency {
            return ReceiptFormat.krw(payAmount)
        }
        guard let amountInKRW else { return "\(currencyCode) \(Int(payAmount))" }
        return ReceiptFormat.krw(amountInKRW)
    }

    var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter.string(from: paidDate)
    }
}

// MARK: - 지도

struct TravelExpenseMap: View {

    let stops: [TravelExpenseStop]
    @Binding var cameraPosition: MapCameraPosition
    /// 고정 높이. nil 이면 남는 세로 공간을 모두 채운다.
    /// 여행 탭에서는 지도가 화면의 주인공이라 채우고, 여행 상세에서는
    /// 아래에 지출 목록이 이어지므로 고정 높이를 쓴다.
    var height: CGFloat? = 320
    var highlightedID: NSManagedObjectID?
    var onSelect: ((TravelExpenseStop) -> Void)?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(position: $cameraPosition) {
                // 들른 순서를 잇는 선. 두 곳 이상일 때만 그린다.
                if stops.count > 1 {
                    MapPolyline(coordinates: stops.map(\.coordinate))
                        .stroke(Color.mainAccent.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [7, 6]))
                }

                ForEach(stops) { stop in
                    Annotation(stop.merchantName, coordinate: stop.coordinate, anchor: .bottom) {
                        Button {
                            onSelect?(stop)
                        } label: {
                            OrderPin(stop: stop, isHighlighted: stop.id == highlightedID)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(maxHeight: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if stops.isEmpty {
                Text("위치를 남긴 지출이 아직 없어요")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray400)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }
        }
    }
}

// MARK: - 순서가 적힌 핀

private struct OrderPin: View {

    let stop: TravelExpenseStop
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(stop.category.color)
                .frame(width: isHighlighted ? 34 : 28, height: isHighlighted ? 34 : 28)
                .overlay(
                    Circle().stroke(isHighlighted ? Color.black : .white, lineWidth: isHighlighted ? 3 : 2)
                )
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            Text("\(stop.order)")
                .font(.system(size: isHighlighted ? 15 : 13, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .animation(.snappy(duration: 0.2), value: isHighlighted)
    }
}

// MARK: - 카메라 맞추기

enum TravelMapCamera {

    // 핀이 모두 들어오도록 카메라를 맞춘다.
    static func fitted(to stops: [TravelExpenseStop]) -> MapCameraPosition {
        let coordinates = stops.map(\.coordinate)
        guard !coordinates.isEmpty else { return .automatic }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return .automatic }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        // 핀이 가장자리에 붙지 않도록 여유를 1.4배 준다. 한 곳뿐이면 기본 폭.
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.02)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    // 한 곳만 가깝게 본다. 목록에서 항목을 눌렀을 때.
    static func focused(on stop: TravelExpenseStop) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: stop.coordinate,
                                   span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
    }
}

// MARK: - 지출 순서 목록의 한 줄
//
// 지도 위 점선 경로와 같은 여정을 목록에서 한 번 더 그린다.
// 번호를 잇는 세로 레일이 그 역할을 하고, 번호와 색은 지도의 핀과 정확히 같다.
// 지도에서 ③번 핀을 본 사람이 목록에서 ③을 그대로 찾을 수 있어야 한다.

struct TravelExpenseRow: View {

    let stop: TravelExpenseStop
    let isHighlighted: Bool
    var isFirst = false
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            rail

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(stop.merchantName)
                        .font(.subhead2_1_fixed)
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(stop.amountText)
                        .font(.subhead2_1_fixed)
                        .foregroundStyle(.black)
                        .monospacedDigit()
                }

                Text("\(stop.category.description) · \(stop.timeText)")
                    .font(.caption1_fixed)
                    .foregroundStyle(.gray300)
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isHighlighted ? Color.gray100 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 2)
        }
        .contentShape(Rectangle())
    }

    // 번호 + 위아래 연결선. 첫 줄 위와 마지막 줄 아래는 비운다.
    private var rail: some View {
        VStack(spacing: 0) {
            railLine
                .frame(height: 12)
                .opacity(isFirst ? 0 : 1)

            ZStack {
                Circle()
                    .fill(stop.category.color)
                    .frame(width: 26, height: 26)

                Text("\(stop.order)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                // 선택은 색이 아니라 링으로 알린다.
                // 색은 카테고리가 이미 쓰고 있어, 여기에 또 색을 얹으면 뜻이 겹친다.
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: 33, height: 33)
                    .opacity(isHighlighted ? 1 : 0)
            }

            railLine
                .frame(maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 33)
        .animation(.snappy(duration: 0.2), value: isHighlighted)
    }

    private var railLine: some View {
        Rectangle()
            .fill(Color.gray200)
            .frame(width: 1.5)
    }
}
