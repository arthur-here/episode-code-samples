import Combine
import SwiftUI

struct Parallel<A> {
  let run: (@escaping (A) -> Void) -> Void
}

//DispatchQueue.main.async(execute: () -> Void) -> Void
//UIView.animate(withDuration: TimeInterval, animations: () -> Void) -> Void
//URLSession.shared.dataTask(with: URL, completionHandler: (Data?, URLResponse?, Error?) -> Void) -> Void
