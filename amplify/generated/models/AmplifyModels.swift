// swiftlint:disable all
import Amplify
import Foundation

// Contains the set of classes that conforms to the `Model` protocol. 

final public class AmplifyModels: AmplifyModelRegistration {
  public let version: String = "00265f141d6acc2f132501296c3a4276"
  
  public func registerModels(registry: ModelRegistry.Type) {
    ModelRegistry.register(modelType: Post.self)
  }
}