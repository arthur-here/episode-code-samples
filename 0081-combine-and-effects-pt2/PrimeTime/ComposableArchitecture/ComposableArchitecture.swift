import Combine
import SwiftUI

//public struct Effect<A> {
//  public let run: (@escaping (A) -> Void) -> Void
//
//  public init(run: @escaping (@escaping (A) -> Void) -> Void) {
//    self.run = run
//  }
//
//  public func map<B>(_ f: @escaping (A) -> B) -> Effect<B> {
//    return Effect<B> { callback in self.run { a in callback(f(a)) } }
//  }
//}

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

public typealias Reducer<Value, Action> = (inout Value, Action) -> Effect<Action>

public final class Store<Value, Action>: ObservableObject {
  private let reducer: Reducer<Value, Action>
  @Published public private(set) var value: Value
  private var viewCancellable: Cancellable?
  private var effectCancellables: Set<AnyCancellable> = []

  public init(initialValue: Value, reducer: @escaping Reducer<Value, Action>) {
    self.reducer = reducer
    self.value = initialValue
  }

  public func send(_ action: Action) {
    let effect = self.reducer(&self.value, action)
    var effectCancellable: AnyCancellable?
    var didComplete = false
    effectCancellable = effect.sink(
      receiveCompletion: { [weak self] _ in
        didComplete = true
        guard let effectCancellable = effectCancellable else { return }
        self?.effectCancellables.remove(effectCancellable)
    },
      receiveValue: self.send
    )
    if !didComplete, let effectCancellable = effectCancellable {
      self.effectCancellables.insert(effectCancellable)
    }
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
        return Empty().eraseToEffect()
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
    let effects = reducers.map { $0(&value, action) }
    return Publishers.MergeMany(effects).eraseToEffect()
  }
}

public func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction>(
  _ reducer: @escaping Reducer<LocalValue, LocalAction>,
  value: WritableKeyPath<GlobalValue, LocalValue>,
  action: WritableKeyPath<GlobalAction, LocalAction?>
) -> Reducer<GlobalValue, GlobalAction> {
  return { globalValue, globalAction in
    guard let localAction = globalAction[keyPath: action] else { return Empty().eraseToEffect() }
    let localEffect = reducer(&globalValue[keyPath: value], localAction)

    return localEffect.map { localAction -> GlobalAction in
      var globalAction = globalAction
      globalAction[keyPath: action] = localAction
      return globalAction
    }
    .eraseToEffect()
  }
}

public func logging<Value, Action>(
  _ reducer: @escaping Reducer<Value, Action>
) -> Reducer<Value, Action> {
  return { value, action in
    let effects = reducer(&value, action)
    let newValue = value
    return Effect.fireAndForget(work: {
      print("Action: \(action)")
      print("Value:")
      dump(newValue)
      print("---")
      }).merge(with: effects).eraseToEffect()
  }
}

extension Effect {
  public static func fireAndForget(work: @escaping () -> Void) -> Effect {
    return Deferred { () -> Empty<Output, Never> in
      work()
      return Empty(completeImmediately: true)
    }.eraseToEffect()
  }
}

extension Effect {
  public static func async(
    work: @escaping (@escaping (Output) -> Void) -> Void
  ) -> Effect {
    return Deferred {
      Future<Output, Never> { fullfill in
        work { value in
          fullfill(Result.success(value))
        }
      }
    }
    .eraseToEffect()
  }
}

extension Publisher {
  func hush() -> Effect<Output> {
    return map(Optional.init)
      .replaceError(with: nil)
      .compactMap { $0 }
      .eraseToEffect()
  }
}
