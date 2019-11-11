import ComposableArchitecture
import SwiftUI

public typealias PrimeModalState = (count: Int, favoritePrimes: [Int], isPrime: Bool)

public enum PrimeModalAction {
  case saveFavoritePrimeTapped
  case removeFavoritePrimeTapped
  case checkIsPrime
  case isPrimeResponse(Bool)
}

private let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

public func primeModalReducer(state: inout PrimeModalState, action: PrimeModalAction) -> [Effect<PrimeModalAction>] {
  switch action {
  case .removeFavoritePrimeTapped:
    state.favoritePrimes.removeAll(where: { $0 == state.count })
    return []

  case .saveFavoritePrimeTapped:
    state.favoritePrimes.append(state.count)
    return []

  case .checkIsPrime:
    return [
      isPrime(state.count)
        .map(PrimeModalAction.isPrimeResponse)
        .run(on: backgroundQueue)
        .receive(on: .main)
    ]

  case .isPrimeResponse(let isPrime):
    state.isPrime = isPrime
    return []
  }
}

public struct IsPrimeModalView: View {
  @ObservedObject var store: Store<PrimeModalState, PrimeModalAction>

  public init(store: Store<PrimeModalState, PrimeModalAction>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      if self.store.value.isPrime {
        Text("\(self.store.value.count) is prime 🎉")
        if self.store.value.favoritePrimes.contains(self.store.value.count) {
          Button("Remove from favorite primes") {
            self.store.send(.removeFavoritePrimeTapped)
          }
        } else {
          Button("Save to favorite primes") {
            self.store.send(.saveFavoritePrimeTapped)
          }
        }
      } else {
        Text("\(self.store.value.count) is not prime :(")
      }
    }
    .onAppear { self.store.send(.checkIsPrime) }
  }
}

func isPrime(_ p: Int) -> Effect<Bool> {
  return Effect { callback in
    if p <= 1 {
      callback(false)
      return
    }

    if p <= 3 {
      callback(true)
      return
    }

    for i in 2...Int(sqrtf(Float(p))) {
      if p % i == 0 {
        callback(false)
        return
      }
    }

    callback(true)
    return
  }
}
