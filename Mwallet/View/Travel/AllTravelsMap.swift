//
//  AllTravelsMap.swift
//  Mwallet
//
//  여행 탭 맨 위의 지도. 모든 여행에서 돈을 쓴 곳을 한 장에 찍는다.
//
//  여행 상세의 지도(TravelExpenseMap)와는 답하는 질문이 다르다.
//
//    여행 상세  이 여행에서 어디를 어떤 차례로 들렀나  → 번호 + 카테고리 색 + 경로선
//    여기       지금까지 어디를 다녔나                → 여행 색 점만
//
//  그래서 번호도 경로선도 그리지 않는다. 여행이 여럿이면 번호는 서로 다른
//  여행끼리 이어져 뜻이 없어지고, 경로선은 방콕과 제주를 잇는 선이 된다.
//

import CoreData
import CoreLocation
import MapKit
import SwiftUI

/// 한 여행이 남긴 자취. 색이 곧 그 여행의 이름표다.
struct TravelMapTrace: Identifiable {
    let id: NSManagedObjectID
    let color: Color
    let stops: [TravelExpenseStop]
}

struct AllTravelsMap: View {

    let traces: [TravelMapTrace]
    @Binding var cameraPosition: MapCameraPosition
    var height: CGFloat = 260

    private var isEmpty: Bool { traces.allSatisfy { $0.stops.isEmpty } }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(position: $cameraPosition) {
                ForEach(traces) { trace in
                    ForEach(trace.stops) { stop in
                        Annotation(stop.merchantName, coordinate: stop.coordinate, anchor: .center) {
                            PlaceDot(color: trace.color)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if isEmpty {
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
}

// MARK: - 한 곳

// 번호를 적지 않으므로 핀보다 작게 찍는다. 점이 많이 몰려도 서로 가리지 않고,
// 흰 테두리가 지도의 어떤 바탕 위에서도 색을 지켜 준다.
private struct PlaceDot: View {

    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}
