import ComposableArchitecture
import SwiftUI


struct AppEnvironment {
  private static var stack: [Environment] = [makeEnvironment()]

  static var current: Environment! {
    return stack.last
  }

  static func pushEnvironment(_ environment: Environment) {
    stack.append(environment)
  }

  @discardableResult
  static func popEnvironment() -> Environment? {
    return stack.popLast()
  }
}

struct Environment {
  let savePrimes: ([Int]) -> Void
  let loadPrimes: () throws -> [Int]
}

private func makeEnvironment() -> Environment {
  return Environment(
    savePrimes: { favoritePrimes in
      let data = try! JSONEncoder().encode(favoritePrimes)
      let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
      let documentsUrl = URL(fileURLWithPath: documentsPath)
      let favoritePrimesUrl = documentsUrl.appendingPathComponent("favorite-primes.json")
      try! data.write(to: favoritePrimesUrl)
    },
    loadPrimes: {
      let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
      let documentsUrl = URL(fileURLWithPath: documentsPath)
      let favoritePrimesUrl = documentsUrl.appendingPathComponent("favorite-primes.json")
      let data = try Data(contentsOf: favoritePrimesUrl)
      let favoritePrimes = try JSONDecoder().decode([Int].self, from: data)
      return favoritePrimes
    }
  )
}

public enum FavoritePrimesAction: Equatable {
  case deleteFavoritePrimes(IndexSet)
  case loadButtonTapped
  case loadedFavoritePrimes([Int])
  case saveButtonTapped
}

public func favoritePrimesReducer(state: inout [Int], action: FavoritePrimesAction) -> [Effect<FavoritePrimesAction>] {
  switch action {
  case let .deleteFavoritePrimes(indexSet):
    for index in indexSet {
      state.remove(at: index)
    }
    return [
    ]

  case let .loadedFavoritePrimes(favoritePrimes):
    state = favoritePrimes
    return []

  case .saveButtonTapped:
    return [
      saveEffect(favoritePrimes: state)
    ]

  case .loadButtonTapped:
    return [
      loadEffect
        .compactMap { $0 }
        .eraseToEffect()
    ]
  }
}

internal func saveEffect(favoritePrimes: [Int]) -> Effect<FavoritePrimesAction> {
  return .fireAndForget {
    AppEnvironment.current.savePrimes(favoritePrimes)
  }
}

internal let loadEffect = Effect<FavoritePrimesAction?>.sync {
  guard let favoritePrimes = try? AppEnvironment.current.loadPrimes() else {
    return nil
  }
  return .loadedFavoritePrimes(favoritePrimes)
}

public struct FavoritePrimesView: View {
  @ObservedObject var store: Store<[Int], FavoritePrimesAction>

  public init(store: Store<[Int], FavoritePrimesAction>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(self.store.value, id: \.self) { prime in
        Text("\(prime)")
      }
      .onDelete { indexSet in
        self.store.send(.deleteFavoritePrimes(indexSet))
      }
    }
    .navigationBarTitle("Favorite primes")
    .navigationBarItems(
      trailing: HStack {
        Button("Save") {
          self.store.send(.saveButtonTapped)
        }
        Button("Load") {
          self.store.send(.loadButtonTapped)
        }
      }
    )
  }
}
