import Combine
import ComposableArchitecture
import XCTest

public enum StepType<Value, Action> {
  case send(Action, (inout Value) -> Void)
  case receive(Action, (inout Value) -> Void)
  case fireAndForget
}

public struct Step<Value, Action> {
  let type: StepType<Value, Action>
  let file: StaticString
  let line: UInt

  public init(
    _ type: StepType<Value, Action>,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.type = type
    self.file = file
    self.line = line
  }
}

public func assert<Value: Equatable, Action: Equatable>(
  initialValue: Value,
  reducer: Reducer<Value, Action>,
  steps: Step<Value, Action>...,
  file: StaticString = #file,
  line: UInt = #line
) {
  var state = initialValue
  var effects: [Effect<Action>] = []
  var cancellables: [AnyCancellable] = []

  steps.forEach { step in
    var expected = state

    switch step.type {
    case let .send(action, update):
      if !effects.isEmpty {
        XCTFail("Action sent before handling \(effects.count) pending effect(s)", file: step.file, line: step.line)
      }
      effects.append(contentsOf: reducer(&state, action))
      update(&expected)

    case let .receive(action, update):
      guard !effects.isEmpty else {
        XCTFail("No pending effects to receive from", file: step.file, line: step.line)
        break
      }
      let effect = effects.removeFirst()
      var action: Action!
      let receivedCompletion = XCTestExpectation(description: "receivedCompletion")
      cancellables.append(
        effect.sink(
          receiveCompletion: { _ in
            receivedCompletion.fulfill()
        },
          receiveValue: { action = $0 }
        )
      )
      if XCTWaiter.wait(for: [receivedCompletion], timeout: 0.01) != .completed {
        XCTFail("Timed out waiting for the effect to complete", file: step.file, line: step.line)
      }
      XCTAssertEqual(action, action, file: step.file, line: step.line)
      effects.append(contentsOf: reducer(&state, action))
      update(&expected)

    case .fireAndForget:
      guard !effects.isEmpty else {
        XCTFail("No pending effects to fire and forget", file: step.file, line: step.line)
        break
      }

      let effect = effects.removeFirst()
      let receivedCompletion = XCTestExpectation(description: "receivedCompletion")
      cancellables.append(
        effect.sink(
          receiveCompletion: { _ in
            receivedCompletion.fulfill()
        },
          receiveValue: { _ in XCTFail() }
        )
      )
      if XCTWaiter.wait(for: [receivedCompletion], timeout: 0.01) != .completed {
        XCTFail("Timed out waiting for the effect to complete", file: step.file, line: step.line)
      }
    }


    XCTAssertEqual(state, expected, file: step.file, line: step.line)
  }
  if !effects.isEmpty {
    XCTFail("Assertion failed to handle \(effects.count) pending effect(s)", file: file, line: line)
  }
}
