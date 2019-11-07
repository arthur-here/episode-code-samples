import Combine
import SwiftUI

struct Parallel<A> {
  let run: (@escaping (A) -> Void) -> Void
}

//DispatchQueue.main.async(execute: () -> Void) -> Void
//UIView.animate(withDuration: TimeInterval, animations: () -> Void) -> Void
//URLSession.shared.dataTask(with: URL, completionHandler: (Data?, URLResponse?, Error?) -> Void) -> Void

//public typealias Effect<Action> = (@escaping (Action) -> Void) -> Void

public struct Effect<A> {
  public init(run: @escaping (@escaping (A) -> Void) -> Void) {
    self.run = run
  }

  let run: (@escaping (A) -> Void) -> Void
}

extension Effect {
  public func map<B>(_ f: @escaping (A) -> B) -> Effect<B> {
    return Effect<B> { callback in
      self.run { a in
        callback(f(a))
      }
    }
  }

  public func receive(on queue: DispatchQueue) -> Effect<A> {
    return Effect { callback in
      queue.async {
        self.run(callback)
      }
    }
  }

  public func flatMap<B>(_ f: @escaping (A) -> Effect<B>) -> Effect<B> {
    return Effect<B> { callback in
      self.run { aValue in
        f(aValue).run { bValue in
          callback(bValue)
        }
      }
    }
  }
}

public func zip<A, B>(_ a: Effect<A>, _ b: Effect<B>) -> Effect<(A, B)> {
  return Effect { callback in
    a.run { aValue in
      b.run { bValue in
        callback((aValue, bValue))
      }
    }
  }
}

public typealias Reducer<Value, Action> = (inout Value, Action) -> [Effect<Action>]

//Button.init("Save", action: <#() -> Void#>)

public final class Store<Value, Action>: ObservableObject {
  private let reducer: Reducer<Value, Action>
  @Published public private(set) var value: Value
  private var viewCancellable: Cancellable?

  public init(initialValue: Value, reducer: @escaping Reducer<Value, Action>) {
    self.reducer = reducer
    self.value = initialValue
  }

  public func send(_ action: Action) {
    let effects = self.reducer(&self.value, action)
    effects.forEach { effect in
      effect.run(self.send)
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
      return Effect { callback in
        localEffect.run { localAction in
          var globalAction = globalAction
          globalAction[keyPath: action] = localAction
          callback(globalAction)
        }
      }
    }
  }
}

public func logging<Value, Action>(
  _ reducer: @escaping Reducer<Value, Action>
) -> Reducer<Value, Action> {
  return { value, action in
    let effects = reducer(&value, action)
    let newValue = value
    return [Effect(run: { _ in
      print("Action: \(action)")
      print("Value:")
      dump(newValue)
      print("---")
    })] + effects
  }
}
//
//extension Store {
//  func presentation<PresentedValue>(
//    _ value: KeyPath<Value, PresentedValue?>,
//    dismissAction: Action
//    ) -> Binding<Store<PresentedValue, Action>?> {
//    return Binding(
//      get: {
//        if value[
//      },
//      set: { _ in self.send(dismissAction) }
//    )
//  }
//}
