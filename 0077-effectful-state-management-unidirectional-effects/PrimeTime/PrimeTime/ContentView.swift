import Combine
import ComposableArchitecture
import Counter
import FavoritePrimes
import SwiftUI

struct AppState {
  var count = 0
  var favoritePrimes: [Int] = []
  var lastFavoritePrimesSaveDate: Date?
  var loggedInUser: User? = nil
  var activityFeed: [Activity] = []

  struct Activity {
    let timestamp: Date
    let type: ActivityType

    enum ActivityType {
      case addedFavoritePrime(Int)
      case removedFavoritePrime(Int)
    }
  }

  struct User {
    let id: Int
    let name: String
    let bio: String
  }
}

enum AppAction {
//  case counter(CounterAction)
//  case primeModal(PrimeModalAction)
  case counterView(CounterViewAction)
  case favoritePrimes(FavoritePrimesAction)

  var favoritePrimes: FavoritePrimesAction? {
    get {
      guard case let .favoritePrimes(value) = self else { return nil }
      return value
    }
    set {
      guard case .favoritePrimes = self, let newValue = newValue else { return }
      self = .favoritePrimes(newValue)
    }
  }

  var counterView: CounterViewAction? {
    get {
      guard case let .counterView(value) = self else { return nil }
      return value
    }
    set {
      guard case .counterView = self, let newValue = newValue else { return }
      self = .counterView(newValue)
    }
  }
}

extension AppState {
  var counterView: CounterViewState {
    get {
      CounterViewState(
        count: self.count,
        favoritePrimes: self.favoritePrimes
      )
    }
    set {
      self.count = newValue.count
      self.favoritePrimes = newValue.favoritePrimes
    }
  }

  var favoritePrimesState: FavoritePrimesState {
    get {
      FavoritePrimesState(
        favoritePrimes: self.favoritePrimes,
        lastSavedAt: self.lastFavoritePrimesSaveDate
      )
    }
    set {
      self.favoritePrimes = newValue.favoritePrimes
      self.lastFavoritePrimesSaveDate = newValue.lastSavedAt
    }
  }
}

let appReducer: Reducer<AppState, AppAction> = combine(
  pullback(counterViewReducer, value: \AppState.counterView, action: \AppAction.counterView),
  pullback(favoritePrimesReducer, value: \AppState.favoritePrimesState, action: \AppAction.favoritePrimes)
)
//
//func activityFeed(
//  _ reducer: Reducer<AppState, AppAction>
//) -> Reducer<AppState, AppAction> {
//
//  return { state, action in
//    switch action {
//    case .counterView(.counter),
//         .favoritePrimes(.loadedFavoritePrimes),
//         .favoritePrimes(.setSaveDate):
//      break
//    case .counterView(.primeModal(.removeFavoritePrimeTapped)):
//      state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))
//
//    case .counterView(.primeModal(.saveFavoritePrimeTapped)):
//      state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))
//
//    case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
//      for index in indexSet {
//        state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
//      }
//    case .favoritePrimes(.loadButtonTapped): break
//    case .favoritePrimes(.saveButtonTapped): break
//    }
//
//    reducer(&state, action)
//  }
//}

struct ContentView: View {
  @ObservedObject var store: Store<AppState, AppAction>

  var body: some View {
    NavigationView {
      List {
        NavigationLink(
          "Counter demo",
          destination: CounterView(
            store: self.store
              .view(
                value: { $0.counterView },
                action: { .counterView($0) }
            )
          )
        )
        NavigationLink(
          "Favorite primes",
          destination: FavoritePrimesView(
            store: self.store.view(
              value: { $0.favoritePrimesState },
              action: { .favoritePrimes($0) }
            )
          )
        )
      }
      .navigationBarTitle("State management")
    }
  }
}
