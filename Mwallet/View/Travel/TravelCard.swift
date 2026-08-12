//
//  TravelCard.swift
//  Mwallet
//
//  여행 선택 시트의 칸 하나.
//
//  석 줄로 세우면 칸이 110pt 남짓이라 넣을 수 있는 것이 얼마 없다. 그래서
//  카드에는 연도를 적지 않는다 — 묶음 머리글이 이미 '2026년' 이라 말하고
//  있어 카드는 월·일만 지면 된다. 같은 말을 두 번 적으면 정작 필요한
//  이름이 줄어든다.
//
//  이름표는 '여행 중' 하나만 단다. 지난 여행과 다가오는 여행까지 이름표를
//  달면 격자 전체가 이름표로 덮여, 정작 지금 다니는 여행이 묻힌다.
//

import SwiftUI

struct TravelCard: View {

    let travel: Travel
    let artwork: TravelArtwork
    let isSelected: Bool

    private var isOngoing: Bool { TravelSchedule.state(of: travel) == .current }

    var body: some View {
        VStack(spacing: 6) {
            cover
            name
            badge
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 사진

    /// 틀을 먼저 세우고 사진을 그 위에 덮는다.
    ///
    /// 사진을 ZStack 에 그냥 넣으면 scaledToFill 이 제 원본 크기를 주장해서
    /// 바깥의 aspectRatio 를 밀어낸다. 그러면 가로 사진이 든 카드와 세로
    /// 사진이 든 카드의 높이가 달라져 격자가 들쭉날쭉해진다. 크기는 빈 칸이
    /// 정하고 사진은 넘치는 만큼 잘리게 둔다.
    private var cover: some View {
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay { background }
            .overlay { flags }
            .overlay { caption }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.mainAccent, lineWidth: isSelected ? 2.5 : 0)
            }
            .overlay(alignment: .topLeading) {
                if isSelected { check }
            }
    }

    /// 손수 고른 대표 사진이 먼저고, 없으면 나라 사진, 그것도 없으면 글자다.
    @ViewBuilder
    private var background: some View {
        if let data = travel.coverImageData, let image = UIImage(data: data) {
            photo(Image(uiImage: image))
        } else if case .photo(let name) = artwork.cover {
            photo(Image(name))
        } else if case .monogram(let letter) = artwork.cover {
            monogram(letter)
        }
    }

    /// 사진은 아래쪽만 어둡게 깐다. 밝은 사진 위에서 흰 날짜가 사라진다.
    private func photo(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.7)],
                               startPoint: .center, endPoint: .bottom)
            }
    }

    /// 사진이 없는 카드. 날짜가 아래에 앉으므로 글자를 조금 올려 둔다.
    private func monogram(_ letter: String) -> some View {
        TravelMonogramTile(letter: letter, tint: tint, glyphSize: 30, offsetY: -6)
    }

    /// 카드마다 다른 색. 서로 구별되기만 하면 되는 자리라 이름에서 뽑는다.
    private var tint: Color { TravelPalette.color(for: travel.displayName) }

    private var isMonogram: Bool {
        if case .monogram = artwork.cover, travel.coverImageData == nil { return true }
        return false
    }

    private var flags: some View {
        // 뒤에 오는 나라일수록 아래에 깔리도록 거꾸로 그린다.
        ZStack {
            ForEach(Array(artwork.flagNames.enumerated()).reversed(), id: \.offset) { index, flag in
                Image(flag)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(x: -11 * CGFloat(artwork.flagNames.count - 1 - index))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(6)
    }

    /// 왼쪽 아래의 한 덩어리 — 첫 글자와 날짜.
    ///
    /// 사진 위에 첫 글자를 얹는 것은 같은 나라를 다녀온 여행끼리 같은 사진을
    /// 받기 때문이다(나라 사진은 나라당 한 장뿐이다). 이름을 읽지 않아도
    /// 어느 여행인지 갈린다.
    ///
    /// 모서리마다 흩뜨리지 않고 한 덩어리로 쌓는다. 칸이 110pt 남짓이라
    /// 글자와 날짜를 좌우로 늘어놓으면 날짜가 줄어들어 읽히지 않는다.
    /// 바탕이 이미 글자 타일이면 얹지 않는다 — 같은 글자가 둘이 된다.
    private var caption: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isMonogram {
                Text(TravelArtworkBuilder.monogram(from: travel.displayName))
                    .font(.custom(FontsManager.WantedSans.semiBold, fixedSize: 19))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }

            Text(TravelSchedule.dayRangeText(travel))
                .font(.caption1_fixed)
                .foregroundStyle(isMonogram ? tint : .white.opacity(0.9))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, 7)
        .padding(.bottom, 6)
    }

    private var check: some View {
        ZStack {
            Circle()
                .fill(Color.mainAccent)
                .overlay { Circle().strokeBorder(.white, lineWidth: 1.5) }
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 21, height: 21)
        .padding(6)
    }

    // MARK: - 이름과 이름표

    private var name: some View {
        Text(travel.displayName)
            .font(.subhead1_fixed)
            .foregroundStyle(isSelected ? Color.mainAccent : .black)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var badge: some View {
        if isOngoing {
            Text("여행 중")
                .font(.caption1_fixed)
                .foregroundStyle(Color.mainAccent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.mainAccent.opacity(0.12), in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessibilityText: String {
        var parts = [travel.displayName, TravelSchedule.periodText(travel)]
        if isOngoing { parts.append("여행 중") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 전체 여행

/// 영수증 탭에서 '고르지 않음' 을 고르는 칸.
///
/// 영수증은 여행을 고르지 않은 것이 '모두 함께 본다' 는 뜻이라, 그 상태로
/// 돌아갈 길이 있어야 한다. 사진이 없으니 여행 카드와 같은 크기의 빈 칸으로
/// 두어 격자가 어긋나지 않게 한다.
struct TravelAllCard: View {

    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray100)
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(isSelected ? Color.mainAccent : .gray400)
            }
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.mainAccent, lineWidth: isSelected ? 2.5 : 0)
            }

            Text("전체 여행")
                .font(.subhead1_fixed)
                .foregroundStyle(isSelected ? Color.mainAccent : .black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("전체 여행")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - 사진이 없을 때

/// 사진 대신 이름 첫 글자를 크게 적는 바탕.
///
/// 예전에는 나라를 모르면 'DefaultImage'(구름 속 비행기 한 장)를 깔았다.
/// 한 번에 하나만 보일 때는 티가 안 났지만, 격자가 되면서 같은 사진이
/// 대여섯 장 늘어서 칸이 서로 구별되지 않았다.
///
/// 색을 안에서 정하지 않고 받는다. 여행 목록의 칸은 테두리 색이 지도 위
/// 점과 짝이라 그 색을 그대로 써야 하고, 선택 시트는 지도가 없어 이름에서
/// 뽑는다. 안에서 하나로 정하면 목록 칸에 뜻이 다른 색이 둘이 된다.
struct TravelMonogramTile: View {

    let letter: String
    let tint: Color
    var glyphSize: CGFloat = 30
    var offsetY: CGFloat = 0

    var body: some View {
        ZStack {
            tint.opacity(0.16)
            Text(letter)
                .font(.custom(FontsManager.WantedSans.semiBold, fixedSize: glyphSize))
                .foregroundStyle(tint)
                .offset(y: offsetY)
        }
    }
}
