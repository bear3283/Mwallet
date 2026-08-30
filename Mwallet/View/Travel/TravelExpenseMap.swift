//
//  TravelExpenseMap.swift
//  Mwallet
//
//  한 여행에서 돈을 쓴 곳을 지도에 찍는다.
//  핀에는 기록 순서(1, 2, 3…)를 적어, 지도만 봐도 어디부터 들렀는지 읽힌다.
//
//  여행 상세(TravelDetailView)에서 쓴다. 여행 탭은 목록이 되면서
//  지도를 내려놓았고, 지도는 한 여행 안을 들여다보는 자리에만 남았다.
//

import CoreData
import CoreLocation
import UIKit
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

    /// 지도의 핀과 목록의 번호에 쓰는 색.
    ///
    /// 카테고리 색을 그대로 쓰면 식비만 다섯 번 나오는 여행에서 다섯 점이
    /// 모두 같은 색이 되어, 지도에서 몇 번 핀인지 색으로는 가릴 수 없었다.
    /// 같은 카테고리가 거듭될 때마다 그 계열 안에서 밝기와 채도를 옮겨
    /// 서로 다른 색이 되게 한다. 계열은 유지되므로 '식비 쪽' 이라는 것은
    /// 그대로 읽힌다.
    let tint: Color

    // 좌표가 있는 지출만 이른 순서대로 세워 번호를 매긴다.
    // BudgetStore 는 최신순으로 주므로 여기서 다시 정렬한다.
    static func stops(from expenses: [Expense]) -> [TravelExpenseStop] {
        var seenPerCategory: [ExpenseInfoCategory: Int] = [:]

        return expenses
            .filter { $0.coordinate != nil }
            .sorted { $0.paidDate < $1.paidDate }
            .enumerated()
            .compactMap { index, expense in
                guard let coordinate = expense.coordinate else { return nil }
                let category = ExpenseInfoCategory(rawValue: Int(expense.category)) ?? .unknown
                let occurrence = seenPerCategory[category, default: 0]
                seenPerCategory[category] = occurrence + 1

                return TravelExpenseStop(
                    id: expense.objectID,
                    order: index + 1,
                    coordinate: coordinate,
                    merchantName: expense.merchantName,
                    category: category,
                    paidDate: expense.paidDate,
                    amountInKRW: expense.amountInKRW,
                    currencyCode: expense.currencyCode,
                    payAmount: expense.payAmount,
                    tint: shade(category.color, occurrence: occurrence)
                )
            }
    }

    /// 같은 계열 안에서 밝기·채도를 옮겨 다른 색을 만든다.
    ///
    /// 색상(hue)은 건드리지 않는다. 색상을 돌리면 식비가 교통 색이 되어
    /// 카테고리 색이라는 약속이 깨진다. 밝기와 채도만 옮기면 '같은 계열의
    /// 다른 색' 으로 남는다.
    static func shade(_ color: Color, occurrence: Int) -> Color {
        guard occurrence > 0 else { return color }

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getHue(&hue, saturation: &saturation,
                                    brightness: &brightness, alpha: &alpha) else { return color }

        // 밝기·채도를 번갈아 반대쪽으로 옮겨, 이웃한 차례끼리 가장 많이 갈린다.
        let steps: [(brightness: CGFloat, saturation: CGFloat)] = [
            (0, 0), (0.17, -0.22), (-0.16, 0.12), (0.30, 0.08), (-0.26, -0.14), (0.09, 0.26)
        ]
        let step = steps[occurrence % steps.count]

        // 너무 밝으면 흰 글씨가, 너무 어두우면 지도 바탕이 먹는다. 양쪽을 묶는다.
        return Color(hue: Double(hue),
                     saturation: Double(min(max(saturation + step.saturation, 0.30), 1)),
                     brightness: Double(min(max(brightness + step.brightness, 0.42), 0.92)))
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
        // "8월 30일 13:39" 는 한국어 차례다. 틀로 주면 언어마다 제 차례로 놓인다.
        formatter.setLocalizedDateFormatFromTemplate("MMMdjm")
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
    /// 처음의 '모두 보이는' 화면으로 되돌린다. nil 이면 버튼을 두지 않는다.
    var onResetCamera: (() -> Void)?

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
            .overlay(alignment: .topTrailing) { resetButton }

            if stops.isEmpty {
                Text("위치를 남긴 지출이 아직 없어요")
                    .font(.caption1)
                    .foregroundStyle(.gray400)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }
        }
    }

    // 핀을 눌러 한 곳을 당겨 보거나 손으로 지도를 옮기고 나면, 처음의
    // '모두 보이는' 화면으로 돌아갈 길이 없었다. 지도를 손으로 다시 맞추는
    // 것은 어렵고, 화면을 나갔다 들어와야 제자리가 됐다.
    //
    // 지도를 움직였는지 가려내려면 카메라를 계속 지켜봐야 하는데, 처음
    // 자리를 잡을 때도 같은 신호가 와서 눌렀는지 아닌지를 가릴 수 없다.
    // 그래서 갈 곳이 둘 이상이면 늘 보여 준다 — 있는데 안 쓰는 편이,
    // 필요할 때 없는 것보다 낫다.
    @ViewBuilder
    private var resetButton: some View {
        if let onResetCamera, stops.count > 1 {
            Button(action: onResetCamera) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("전체 보기")
                        .font(.caption1)
                }
                .foregroundStyle(.black)
                .padding(.vertical, 7)
                .padding(.horizontal, 11)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .padding(10)
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
                .fill(stop.tint)
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
//
// 한 줄 안에 목적지가 둘이라 링크로 묶지 않는다 — 영수증 탭에서 썸네일과
// 본문을 나눠 둔 것과 같은 짜임이다.
//
//   번호  지도의 그 지점으로  (번호가 곧 지도의 이름표다)
//   본문  그 지출의 상세로    (거기서 고치고 지운다)

struct TravelExpenseRow: View {

    let stop: TravelExpenseStop
    let isHighlighted: Bool
    var isFirst = false
    var isLast = false
    /// 번호를 눌렀을 때. 지도를 그 지점으로 옮긴다.
    var onFocus: () -> Void = { }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onFocus) { rail }
                .buttonStyle(.plain)
                .accessibilityLabel("\(stop.order)번 지점을 지도에서 보기")

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(stop.merchantName)
                        .font(.subhead2_1)
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(stop.amountText)
                        .font(.subhead2_1)
                        .foregroundStyle(.black)
                        .monospacedDigit()
                }

                Text("\(stop.category.visibleDescription) · \(stop.timeText)")
                    .font(.caption1)
                    .foregroundStyle(.gray300)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .fill(stop.tint)
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
