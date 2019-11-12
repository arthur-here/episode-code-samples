import UIKit


public struct Effect<A> {
  public let run: (@escaping (A) -> Void) -> Void

  public func map<B>(_ f: @escaping (A) -> B) -> Effect<B> {
    return Effect<B> { callback in self.run { a in callback(f(a)) } }
  }
}

import Dispatch

final class EagerEffect<A> {
  private var cachedValue: A?
  private var waiters = [(A) -> Void]()
  private var lock = os_unfair_lock()

  init(worker: (@escaping (A) -> Void) -> Void) {
    worker { [weak self] value in
      guard let self = self else {
        return
      }

      os_unfair_lock_lock(&self.lock)
      self.cachedValue = value

      for waiter in self.waiters {
        waiter(value)
      }

      self.waiters.removeAll()
      os_unfair_lock_unlock(&self.lock)
    }
  }

  func run(callback: @escaping (A) -> Void) {
    os_unfair_lock_lock(&lock)
    if let value = cachedValue {
      print("used cached value")
      callback(value)
    } else {
      print("added to waiters queue")
      waiters.append(callback)
    }
    os_unfair_lock_unlock(&lock)
  }
}

let delayedInt = EagerEffect<Int> { callback in
  print("worker started")
  DispatchQueue.main.asyncAfter(wallDeadline: .now() + 1) {
    callback(420)
  }
}

delayedInt.run { int in
  print("1 \(int)")
}

delayedInt.run { print("2 \($0)") }

DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
  delayedInt.run { print("3 \($0)") }
}


import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true
