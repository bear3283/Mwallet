//
//  TravelSummaryStrips.swift
//  Mwallet
//
//  여행 상세 위쪽의 두 줄 — 기본 정보와 예산 집행.
//
//    기본 정보  기간 · 국가 · 인원. 한 번 확인하면 되는 값이라 작게 접어 둔다.
//    예산 집행  여기까지 얼마를 썼나. 여행을 열 때마다 묻게 되는 값이다.
//
//  TravelDetailView 에서 떼어 냈다. 둘 다 받은 값만 그리고 아무것도 바꾸지 않는다.
//

import SwiftUI

// MARK: - 기본 정보

struct TravelBasicInfoStrip: View {

    let periodText: String
    let countryText: String
    let peopleCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            infoCell(title: String(localized: "기간"), value: periodText)

            divider

            infoCell(title: String(localized: "국가"),
                     value: countryText)

            divider

            infoCell(title: String(localized: "인원"), value: String(localized: "\(peopleCount)명"))
        }
        .padding(.vertical, 12)
        .background(Color.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func infoCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption1)
                .foregroundStyle(.gray300)
            Text(value)
                .font(.caption2)
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
}

// MARK: - 예산 집행

struct TravelBudgetStrip: View {

    let summary: BudgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(summary.hasBudget ? String(localized: "예산 \(ReceiptFormat.krw(summary.totalPlanned))")
                     : String(localized: "집행"))
                    .font(.caption1)
                    .foregroundStyle(.gray300)

                Spacer(minLength: 8)

                Text(ReceiptFormat.krw(summary.totalSpent))
                    .font(.subhead2_1)
                    .foregroundStyle(.black)
                    .monospacedDigit()

                if let ratio = summary.ratio {
                    Text("\(Int((ratio * 100).rounded()))%")
                        .font(.caption1)
                        .foregroundStyle(summary.isOverspent ? Color.mainOrange : .gray400)
                        .monospacedDigit()
                }
            }

            if summary.hasBudget {
                progressBar

                Text(summary.isOverspent
                     ? String(localized: "\(ReceiptFormat.krw(-summary.remaining)) 초과")
                     : String(localized: "\(ReceiptFormat.krw(summary.remaining)) 남음"))
                    .font(.caption1)
                    .foregroundStyle(summary.isOverspent ? Color.mainOrange : .gray400)
                    .monospacedDigit()
            }

            // 환율을 못 받은 지출은 집행액에서 빠져 있다. 합계가 실제보다
            // 작게 보이므로 그 사실을 숨기지 않는다.
            if summary.hasUnconvertible {
                Text(String(localized: "환율을 받지 못한 \(summary.unconvertibleCount)건은 집행액에서 빠졌습니다"))
                    .font(.caption1)
                    .foregroundStyle(Color.mainOrange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray200)
                Capsule()
                    .fill(summary.isOverspent ? Color.mainOrange : Color.mainAccent)
                    .frame(width: geometry.size.width * summary.barRatio)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - 머리말

// 대표 사진과 여행 이름. 여행 중이면 며칠째인지 함께 알린다.

struct TravelDetailHeader: View {

    let travel: Travel
    let travelName: String
    let isOngoing: Bool
    let dayCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 여행을 만들 때 고른 대표 사진. 없으면 자리를 차지하지 않는다.
            if let data = travel.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 10)
            }

            if isOngoing {
                HStack(spacing: 6) {
                    Text("여행 중")
                        .font(.caption1)
                        .foregroundStyle(Color.mainAccent)
                    Text("DAY \(dayCount)")
                        .font(.caption1)
                        .foregroundStyle(.gray400)
                        .monospacedDigit()
                }
            }

            Text(travelName)
                .font(.title3)
                .foregroundStyle(.black)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ReceiptLayout.gutter)
        .padding(.top, 8)
    }
}
