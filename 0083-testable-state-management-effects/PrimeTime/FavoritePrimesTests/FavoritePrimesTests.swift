import XCTest
@testable import FavoritePrimes

class FavoritePrimesTests: XCTestCase {
  override class func setUp() {
    super.setUp()
    Current = .mock
  }

  func testDeleteFavoritePrimes() {
    var state = [2, 3, 5, 7]
    let effects = favoritePrimesReducer(state: &state, action: .deleteFavoritePrimes([2]))

    XCTAssertEqual(state, [2, 3, 7])
    XCTAssert(effects.isEmpty)
  }

  func testSaveButtonTapped() {

    var savedData: Data! = nil
    Current.fileClient.save = { _, data in
      .fireAndForget {
        savedData = data
      }
    }

    var state = [2, 3, 5, 7]
    let effects = favoritePrimesReducer(state: &state, action: .saveButtonTapped)

    XCTAssertEqual(state, [2, 3, 5, 7])
    XCTAssertEqual(effects.count, 1)

    effects[0].sink { _ in XCTFail() }

    let decodedSavedData = try! JSONDecoder().decode([Int].self, from: XCTUnwrap(savedData))
    XCTAssertEqual(decodedSavedData, [2, 3, 5, 7])
  }

  func testLoadFavoritePrimesFlow() {
    Current.fileClient.load = { _ in .sync { try! JSONEncoder().encode([2, 31]) } }

    var state = [2, 3, 5, 7]
    var effects = favoritePrimesReducer(state: &state, action: .loadButtonTapped)

    XCTAssertEqual(state, [2, 3, 5, 7])
    XCTAssertEqual(effects.count, 1)

    var nextAction: FavoritePrimesAction!
    let receivedCompletion = self.expectation(description: "receivedCompletion")
    let receivedValue = self.expectation(description: "receivedValue")
    effects[0].sink(
      receiveCompletion: { _ in
        receivedCompletion.fulfill()
    },
      receiveValue: { action in
        XCTAssertEqual(action, .loadedFavoritePrimes([2, 31]))
        nextAction = action
        receivedValue.fulfill()
    })
    self.wait(for: [receivedCompletion, receivedValue], timeout: 0)

    effects = favoritePrimesReducer(state: &state, action: nextAction)

    XCTAssertEqual(state, [2, 31])
    XCTAssert(effects.isEmpty)
  }

}
