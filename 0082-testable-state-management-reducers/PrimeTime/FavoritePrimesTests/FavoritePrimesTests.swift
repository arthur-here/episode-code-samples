import XCTest
@testable import FavoritePrimes
import Combine

class FavoritePrimesTests: XCTestCase {
  private var cancellable: AnyCancellable?
  func testDeleteFavoritePrimes() {
    var state = [2, 3, 5, 7]
    let effects = favoritePrimesReducer(state: &state, action: .deleteFavoritePrimes([2]))

    XCTAssertEqual(state, [2, 3, 7])
    XCTAssert(effects.isEmpty)
  }

  func testSaveButtonTapped() {
    var state = [2, 3, 5, 7]
    let effects = favoritePrimesReducer(state: &state, action: .saveButtonTapped)

    XCTAssertEqual(state, [2, 3, 5, 7])
    XCTAssertEqual(effects.count, 1)

    let effect = effects[0]

    var saveWasCalled = false
    let mockEnvironment = Environment(
      savePrimes: { _ in saveWasCalled = true },
      loadPrimes: { return [] }
    )

    AppEnvironment.pushEnvironment(mockEnvironment)

    let saveExpect = expectation(description: "Save Effect")
    cancellable = effect.sink(receiveCompletion: { _ in
      saveExpect.fulfill()
    }, receiveValue: { _ in
      XCTFail()
    })

    wait(for: [saveExpect], timeout: 1.0)

    XCTAssertTrue(saveWasCalled)
  }

  func testLoadFavoritePrimesFlow() {
    var state = [2, 3, 5, 7]
    var effects = favoritePrimesReducer(state: &state, action: .loadButtonTapped)

    XCTAssertEqual(state, [2, 3, 5, 7])
    XCTAssertEqual(effects.count, 1)

    // EFFECT
    let effect = effects[0]
    let loadReturnValue = [1, 2, 3]

    let mockEnvironment = Environment(
      savePrimes: { _ in },
      loadPrimes: { return loadReturnValue }
    )
    AppEnvironment.pushEnvironment(mockEnvironment)

    let loadCompletesExpect = expectation(description: "Load Completed")
    let loadReceivedValueExpect = expectation(description: "Load Received")
    var receivedValue: FavoritePrimesAction? = nil

    cancellable = effect.sink(receiveCompletion: { _ in
      loadCompletesExpect.fulfill()
    }, receiveValue: {
      receivedValue = $0
      loadReceivedValueExpect.fulfill()
    })

    wait(for: [loadReceivedValueExpect, loadCompletesExpect], timeout: 1.0)
    XCTAssertNotNil(receivedValue)

    // REDUCER
    effects = favoritePrimesReducer(state: &state, action: receivedValue!)

    XCTAssertEqual(state, loadReturnValue)
    XCTAssert(effects.isEmpty)
  }
}
