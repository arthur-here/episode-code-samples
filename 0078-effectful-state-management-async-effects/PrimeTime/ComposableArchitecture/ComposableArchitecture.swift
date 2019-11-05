import Combine
import SwiftUI

struct Parallel<A> {
  let run: (@escaping (A) -> Void) -> Void
}

//DispatchQueue.main.async(execute: () -> Void) -> Void
//UIView.animate(withDuration: TimeInterval, animations: () -> Void) -> Void
//URLSession.shared.dataTask(with: URL, completionHandler: (Data?, URLResponse?, Error?) -> Void) -> Void

//public typealias Effect<Action> = (@escaping (Action) -> Void) -> Void

public struct Effect<Output>: Publisher {
  public typealias Failure = Never

  let publisher: AnyPublisher<Output, Failure>

  public func receive<S>(
    subscriber: S
  ) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    self.publisher.receive(subscriber: subscriber)
  }
}

extension Publisher where Failure == Never {
  public func eraseToEffect() -> Effect<Output> {
    return Effect(publisher: self.eraseToAnyPublisher())
  }
}

public typealias Reducer<Value, Action> = (inout Value, Action) -> [Effect<Action>]

//Button.init("Save", action: <#() -> Void#>)

public final class Store<Value, Action>: ObservableObject {
  private let reducer: Reducer<Value, Action>
  @Published public private(set) var value: Value
  private var viewCancellable: Cancellable?
  private var effectCancellables: [AnyCancellable] = []

  public init(initialValue: Value, reducer: @escaping Reducer<Value, Action>) {
    self.reducer = reducer
    self.value = initialValue
  }

  public func send(_ action: Action) {
    let effects = self.reducer(&self.value, action)
    effects.forEach { effect in
      var effectCancellable: AnyCancellable!
      effectCancellable = effect
        .sink(
          receiveCompletion: { [weak self] _ in
            self?.effectCancellables.removeAll(where: { $0 == effectCancellable })
        },
          receiveValue: self.send
      )
      self.effectCancellables.append(effectCancellable)
    }
//    DispatchQueue.global().async {
//      effects.forEach { effect in
//        if let action = effect() {
//          DispatchQueue.main.async {
//            self.send(action)
//          }
//        }
//      }
//    }
  }

  public func view<LocalValue, LocalAction>(
    value toLocalValue: @escaping (Value) -> LocalValue,
    action toGlobalAction: @escaping (LocalAction) -> Action
  ) -> Store<LocalValue, LocalAction> {
    let localStore = Store<LocalValue, LocalAction>(
      initialValue: toLocalValue(self.value),
      reducer: { localValue, localAction in
        self.send(toGlobalAction(localAction))
        localValue = toLocalValue(self.value)
        return []
    }
    )
    localStore.viewCancellable = self.$value.sink { [weak localStore] newValue in
      localStore?.value = toLocalValue(newValue)
    }
    return localStore
  }
}

public func combine<Value, Action>(
  _ reducers: Reducer<Value, Action>...
) -> Reducer<Value, Action> {
  return { value, action in
    let effects = reducers.flatMap { $0(&value, action) }
    return effects
  }
}

public func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction>(
  _ reducer: @escaping Reducer<LocalValue, LocalAction>,
  value: WritableKeyPath<GlobalValue, LocalValue>,
  action: WritableKeyPath<GlobalAction, LocalAction?>
) -> Reducer<GlobalValue, GlobalAction> {
  return { globalValue, globalAction in
    guard let localAction = globalAction[keyPath: action] else { return [] }
    let localEffects = reducer(&globalValue[keyPath: value], localAction)
    return localEffects.map { localEffect in
      localEffect
        .map { localAction -> GlobalAction in
          var globalAction = globalAction
          globalAction[keyPath: action] = localAction
          return globalAction
      }
      .eraseToEffect()
    }
  }
}

public func logging<Value, Action>(
  _ reducer: @escaping Reducer<Value, Action>
) -> Reducer<Value, Action> {
  return { value, action in
    let effects = reducer(&value, action)
    let newValue = value
    return [
      Deferred {
        Future { _ in
          print("Action: \(action)")
          print("Value:")
          dump(newValue)
          print("---")
        }
      }.eraseToEffect()
      ] + effects
  }
}

extension Effect {
  public static func fireAndForget(work: @escaping () -> Void) -> Effect {
    return Deferred { () -> Empty<Output, Never> in
      work()
      return Empty<Output, Never>(completeImmediately: true)
    }
    .eraseToEffect()
  }

  public static func sync(work: @escaping () -> Output) -> Effect {
    return Deferred {
      Just(work())
    }
    .eraseToEffect()
  }
}
