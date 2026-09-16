//
//  TravelSelectionLoopTests.swift
//  MwalletTests
//
//  여행 선택을 비웠을 때 되돌아 들어오지 않는지 본다.
//

import XCTest
@testable import Mwallet

@MainActor
final class TravelSelectionLoopTests: XCTestCase {

    /// 비운 선택이 스스로를 다시 부르지 않는다.
    ///
    /// 예전에는 `selectedTravelInExpense` 의 didSet 이 비었을 때
    /// `findCurrentTravel()` 의 답을 그대로 넣었다. 그 함수도 nil 을 주면
    /// nil 을 도로 넣는 꼴이라 didSet 이 자기를 다시 불렀고, 멈출 자리가 없어
    /// 여행이 하나도 없는 장부에서는 스택을 넘어 프로세스가 죽었다.
    /// 부를 때마다 Core Data 를 한 번씩 뒤지므로 조용히 느려지다 터진다.
    ///
    /// 죽는 결함이라 이 테스트의 값어치는 단언보다 **끝까지 돌아온다는 것**에 있다.
    /// 되풀이에 빠지면 프로세스가 죽어 이 줄 아래로 오지 못한다.
    func test_선택을_비워도_되풀이하지_않는다() {
        let model = MainViewModel.shared

        model.selectedTravelInExpense = nil

        // 메울 것이 있으면 메우고, 없으면 빈 채로 둔다. 어느 쪽이든 돌아온다.
        XCTAssertEqual(model.selectedTravelInExpense, findCurrentTravel())
    }

    /// 여러 번 비워도 마찬가지다. 한 번은 우연히 빠져나갈 수 있다.
    func test_거듭_비워도_되풀이하지_않는다() {
        let model = MainViewModel.shared

        for _ in 0..<5 {
            model.selectedTravelInExpense = nil
        }

        XCTAssertEqual(model.selectedTravelInExpense, findCurrentTravel())
    }
}
