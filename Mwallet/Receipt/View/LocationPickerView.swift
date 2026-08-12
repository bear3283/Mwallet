//
//  LocationPickerView.swift
//  Mwallet
//
//  "이곳이 맞나요?" — 영수증 입력 마지막에 지출한 위치를 지도로 확인한다.
//  현재 GPS 위치를 기본으로 찍고, 지도를 움직여 핀을 맞춘다.
//  지도 타일은 온라인이 필요하지만 좌표 자체는 오프라인에서도 기록된다.
//

import CoreLocation
import MapKit
import SwiftUI

struct LocationPickerView: View {

    @Environment(\.dismiss) private var dismiss

    // 확정한 좌표와 지명을 돌려준다.
    let onConfirm: (CLLocationCoordinate2D, String?) -> Void

    @State private var cameraPosition: MapCameraPosition
    @State private var centerCoordinate: CLLocationCoordinate2D
    @State private var placeName: String?
    @State private var isResolving = false

    private let geocoder = CLGeocoder()

    init(
        initial: CLLocationCoordinate2D?,
        onConfirm: @escaping (CLLocationCoordinate2D, String?) -> Void
    ) {
        self.onConfirm = onConfirm
        // 저장된 좌표가 있으면 그 자리, 없으면 현재 GPS, 그마저 없으면 서울.
        let start = initial
            ?? DateGapHandler.shared.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        _centerCoordinate = State(initialValue: start)
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(center: start, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition)
                    .ignoresSafeArea(edges: .bottom)
                    .onMapCameraChange(frequency: .onEnd) { context in
                        centerCoordinate = context.region.center
                        resolvePlaceName()
                    }

                // 지도는 움직이고 핀은 화면 중앙에 고정한다.
                // 지도를 끌어 원하는 지점을 중앙 핀에 맞추는 방식이라 조작이 명확하다.
                centerPin
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    confirmCard
                }
            }
            .navigationTitle("이곳이 맞나요?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .font(.subhead2_2)
                        .foregroundStyle(.gray400)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        recenterToCurrentLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.black)
                    }
                }
            }
            .onAppear {
                DateGapHandler.shared.requestAuthorization()
                DateGapHandler.shared.getLocation()
                resolvePlaceName()
            }
        }
    }

    // MARK: - 중앙 핀

    private var centerPin: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.mainAccent, .black)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            // 핀 끝이 정확히 중앙을 가리키도록 아래로 반만큼 올린다.
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundStyle(.black)
                .offset(y: -4)
        }
        .offset(y: -22)
    }

    // MARK: - 확인 카드

    private var confirmCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mappin")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray400)
                if isResolving {
                    Text("위치를 확인하는 중…")
                        .font(.body1)
                        .foregroundStyle(.gray300)
                } else {
                    Text(placeName ?? "이름을 찾지 못한 곳")
                        .font(.body1)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            ReceiptPrimaryButton(title: "이 위치로 저장") {
                onConfirm(centerCoordinate, placeName)
                dismiss()
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, ReceiptLayout.gutter)
        .padding(.bottom, 16)
    }

    // MARK: - 동작

    private func recenterToCurrentLocation() {
        guard let current = DateGapHandler.shared.currentLocation?.coordinate else { return }
        centerCoordinate = current
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(center: current, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            )
        }
        resolvePlaceName()
    }

    private func resolvePlaceName() {
        isResolving = true
        geocoder.cancelGeocode()
        let location = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) { placemarks, _ in
            // 지오코딩 콜백은 메인으로 온다고 문서화돼 있지만 클로저 타입이
            // @Sendable 이라 컴파일러가 그걸 알 수 없다.
            MainActor.assumeIsolated {
                isResolving = false
                guard let place = placemarks?.first else {
                    placeName = nil
                    return
                }
                // 상호명이 없으면 동네·거리 이름을 조합한다.
                let parts = [place.name, place.locality, place.subLocality]
                    .compactMap { $0 }
                placeName = parts.first.map { first in
                    place.locality.map { first == $0 ? first : "\($0) \(first)" } ?? first
                }
            }
        }
    }
}
