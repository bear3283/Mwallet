//
//  DateGapHandler.swift
//  Mwallet
//
//  Created by Wonil Lee on 11/5/23.
//
//  현재 위치를 확보하고, 날짜의 하루 시작·끝을 구한다.
//
//  ⚠️ 예전에는 여기서 "기준지(서울)와 현재 위치의 시차"를 구해 저장 직전에 더하고
//     표시 직전에 빼는 보정을 했다(convertBeforeSaving / convertBeforeShowing).
//     그 보정은 두 가지 이유로 제거했다.
//
//     1. Expense.timeZoneIdentifier 에 기록 당시 시간대를 이미 저장하고 있고,
//        표시·CSV 는 그 값으로 현지 시각을 복원한다. 절대시각을 밀어 두는 것은
//        같은 정보를 두 번, 서로 다른 방식으로 표현하는 이중 보정이었다.
//     2. 시차 값은 위치 권한 승인 → 역지오코딩 2회가 모두 끝나야 채워졌다.
//        대부분의 기록은 0(보정 없음)으로, 일부만 보정된 채로 저장돼
//        한 저장소 안에 두 가지 규칙이 섞였다.
//
//     이제 payDate 는 언제나 실제 절대시각이다.
//

import Foundation
import CoreLocation

final class LocationManagerDelegateForDateGapHandler: NSObject, CLLocationManagerDelegate {
    var parent: DateGapHandler?
    var updateActivityIsDone = false
    var authActivityIsDone = false

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !updateActivityIsDone {
            parent?.currentLocation = locations.first
            if let loc = parent?.currentLocation {
                UserDefaults.standard.set(loc.coordinate.latitude, forKey: "currentLocationLatitude")
                UserDefaults.standard.set(loc.coordinate.longitude, forKey: "currentLocationLongitude")
            }
            updateActivityIsDone = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if !authActivityIsDone {
                parent?.getLocation()
                authActivityIsDone = true
            }
        }
    }
}

final class DateGapHandler {
    static let shared = DateGapHandler()
    let calendar = Calendar.current

    private init() { }

    private var locationManager: CLLocationManager?
    private var locationManagerDelegate = LocationManagerDelegateForDateGapHandler()
    var currentLocation: CLLocation?

    // 위치가 실제로 필요한 시점(지출 기록 시작)에 호출한다.
    // 앱을 켜자마자 묻지 않으려고 진입점을 옮겼고, 이제 여러 화면에서 불리므로
    // 매니저를 두 번 만들지 않도록 한 번만 준비한다.
    func requestAuthorization() {
        guard locationManager == nil else { return }

        locationManager = CLLocationManager()
        locationManager?.delegate = locationManagerDelegate
        locationManagerDelegate.parent = self

        locationManager?.requestWhenInUseAuthorization()
    }

    func getLocation() {
        locationManager?.startUpdatingLocation()
    }

    func getLocal000(of date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        var newComponents = DateComponents()
        newComponents.year = components.year
        newComponents.month = components.month
        newComponents.day = components.day
        newComponents.hour = 0
        newComponents.minute = 0
        newComponents.second = 0

        if let newDate = calendar.date(from: newComponents) {
            return newDate
        } else {
            return date
        }
    }

    func getLocal235959(of date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        var newComponents = DateComponents()
        newComponents.year = components.year
        newComponents.month = components.month
        newComponents.day = components.day
        newComponents.hour = 23
        newComponents.minute = 59
        newComponents.second = 59

        if let newDate = calendar.date(from: newComponents) {
            return newDate
        } else {
            return date
        }
    }
}
