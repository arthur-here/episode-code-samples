import ComposableArchitecture
import SwiftUI
import Combine

public enum FavoritePrimesAction {
  case deleteFavoritePrimes(IndexSet)
  case loadButtonTapped
  case loadedFavoritePrimes([Int])
  case loadFavoritePrimesFailed(String)
  case saveButtonTapped
  case saveSuccess(Date)
  case dismissAlert
}

public struct FavoritePrimesState {
  public var favoritePrimes: [Int]
  public var lastSavedAt: Date?
  public var errorMessage: String?

  public init(favoritePrimes: [Int], lastSavedAt: Date?) {
    self.favoritePrimes = favoritePrimes
    self.lastSavedAt = lastSavedAt
    self.errorMessage = nil
  }
}

public func favoritePrimesReducer(state: inout FavoritePrimesState, action: FavoritePrimesAction) -> [Effect<FavoritePrimesAction>] {
  switch action {
  case let .deleteFavoritePrimes(indexSet):
    for index in indexSet {
      state.favoritePrimes.remove(at: index)
    }
    return []

  case let .loadedFavoritePrimes(favoritePrimes):
    state.favoritePrimes = favoritePrimes
    return []

  case let .loadFavoritePrimesFailed(error):
    state.errorMessage = error
    return []

  case .saveButtonTapped:
    return [saveEffect(favoritePrimes: state.favoritePrimes)]

  case .loadButtonTapped:
    return [loadEffect]

  case let .saveSuccess(date):
    state.lastSavedAt = date
    return []

  case .dismissAlert:
    state.errorMessage = nil
    return []
  }
}

private func saveEffect(favoritePrimes: [Int]) -> Effect<FavoritePrimesAction> {
  return {
    let data = try! JSONEncoder().encode(favoritePrimes)
    let documentsPath = NSSearchPathForDirectoriesInDomains(
      .documentDirectory, .userDomainMask, true
      )[0]
    let documentsUrl = URL(fileURLWithPath: documentsPath)
    let favoritePrimesUrl = documentsUrl
      .appendingPathComponent("favorite-primes.json")
    try! data.write(to: favoritePrimesUrl)

    return .saveSuccess(Date())
  }
}

private let loadEffect: Effect<FavoritePrimesAction> = {
  let documentsPath = NSSearchPathForDirectoriesInDomains(
    .documentDirectory, .userDomainMask, true
    )[0]
  let documentsUrl = URL(fileURLWithPath: documentsPath)
  let favoritePrimesUrl = documentsUrl
    .appendingPathComponent("favorite-primes.json")
  return .loadFavoritePrimesFailed("No save available")
  guard let data = try? Data(contentsOf: favoritePrimesUrl) else {
    return .loadFavoritePrimesFailed("No save available")
  }

  do {
    let favoritePrimes = try JSONDecoder().decode([Int].self, from: data)
    return .loadedFavoritePrimes(favoritePrimes)
  } catch {
    return .loadFavoritePrimesFailed(error.localizedDescription)
  }
}

public struct FavoritePrimesView: View {
  private static let dateFormatter: DateFormatter = {
    var df = DateFormatter()
    df.dateStyle = .none
    df.timeStyle = .short
    return df
  }()

  private var cancellable: Cancellable?

  @ObservedObject var store: Store<FavoritePrimesState, FavoritePrimesAction>

  public init(store: Store<FavoritePrimesState, FavoritePrimesAction>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      List {
        ForEach(self.store.value.favoritePrimes, id: \.self) { prime in
          Text("\(prime)")
        }
        .onDelete { indexSet in
          self.store.send(.deleteFavoritePrimes(indexSet))
        }
      }
      Text(self.store.value.lastSavedAt.map(FavoritePrimesView.dateFormatter.string(from:)) ?? "No Saves")
    }
    .navigationBarTitle("Favorite primes")
    .navigationBarItems(
      trailing: HStack {
        Button("Save") {
          self.store.send(.saveButtonTapped)
//          let data = try! JSONEncoder().encode(self.store.value)
//          let documentsPath = NSSearchPathForDirectoriesInDomains(
//            .documentDirectory, .userDomainMask, true
//            )[0]
//          let documentsUrl = URL(fileURLWithPath: documentsPath)
//          let favoritePrimesUrl = documentsUrl
//            .appendingPathComponent("favorite-primes.json")
//          try! data.write(to: favoritePrimesUrl)
        }
        Button("Load") {
          self.store.send(.loadButtonTapped)
//          let documentsPath = NSSearchPathForDirectoriesInDomains(
//            .documentDirectory, .userDomainMask, true
//            )[0]
//          let documentsUrl = URL(fileURLWithPath: documentsPath)
//          let favoritePrimesUrl = documentsUrl
//            .appendingPathComponent("favorite-primes.json")
//          guard
//            let data = try? Data(contentsOf: favoritePrimesUrl),
//            let favoritePrimes = try? JSONDecoder().decode([Int].self, from: data)
//            else { return }
//          self.store.send(.loadedFavoritePrimes(favoritePrimes))
        }
      }
      )
      .alert(isPresented: Binding(
          get: { self.store.value.errorMessage != nil },
          set: { _ in self.store.send(.dismissAlert) }
      )) { Alert(
        title: Text("Save Error"),
        message: self.store.value.errorMessage.map(Text.init),
        dismissButton: .default(Text("OK"), action: { self.store.send(.dismissAlert) })
      ) }
  }
}


