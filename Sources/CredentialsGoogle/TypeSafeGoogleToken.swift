/**
 * Copyright IBM Corporation 2018
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/


import Kitura
import KituraNet
import LoggerAPI
import Credentials
import Foundation

/**
 A protocol that a user's type can conform to representing a user authenticated using a
 Google OAuth token.

 ### Usage Example: ###

 ```swift
 public struct ExampleProfile: TypeSafeGoogleToken {
     let id: String                              // Protocol requirement: subject's unique id
     let name: String                            // Protocol requirement: subject's display name
     let email: String?                          // Optional field: may not be granted
 }

 router.get("/googleProfile") { (user: ExampleProfile, respondWith: (ExampleProfile?, RequestError?) -> Void) in
     respondWith(user, nil)
 }
 ```
 */
public protocol TypeSafeGoogleToken: TypeSafeGoogle {
    
    // MARK: Instance fields
    
    /// The subject's unique Google id.
    var id: String { get }
    
    /// The subject's display name.
    var name: String { get }

    // MARK: Static fields

    /// The maximum size of the in-memory token cache for this type. If not specified, then
    /// the cache has an unlimited size.
    static var cacheSize: Int { get }

}

/// The cache element for keeping google profile information.
private class GoogleCacheElement {
    /// The user profile information stored as `TypeSafeGoogleToken`.
    var userProfile: TypeSafeGoogleToken
    
    /// Initialize a `GoogleCacheElement`.
    ///
    /// - Parameter profile: the `TypeSafeGoogleToken` to store.
    init (profile: TypeSafeGoogleToken) {
        userProfile = profile
    }
}

// An internal type to hold the mapping from a user's type to an appropriate token cache.
//
// It is a workaround for the inability to define stored properties in a protocol extension.
//
// We use the `debugDescription` of the user's type (via `String(reflecting:)`) as the
// dictionary key.
private struct TypeSafeGoogleTokenCache {
    internal static var cacheForType: [String: NSCache<NSString, GoogleCacheElement>] = [:]
}

extension TypeSafeGoogleToken {

    /// A default value for the cache size of `0`, which means that there is no limit on how
    /// many profiles the token cache can store.
    public static var cacheSize: Int {
        return 0
    }

    // Associates a token cache with the user's type. This relieves the user from having to
    // declare a usersCache property on their conforming type.
    private static var usersCache: NSCache<NSString, GoogleCacheElement> {
        let key = String(reflecting: Self.self)
        if let usersCache = TypeSafeGoogleTokenCache.cacheForType[key] {
            return usersCache
        } else {
            let usersCache = NSCache<NSString, GoogleCacheElement>()
            Log.debug("Token cache size for \(key): \(cacheSize == 0 ? "unlimited" : String(describing: cacheSize))")
            usersCache.countLimit = cacheSize
            TypeSafeGoogleTokenCache.cacheForType[key] = usersCache
            return usersCache
        }
    }

    /// Authenticate an incoming request using a Google OAuth token. This type of
    /// authentication handles requests with a header of 'X-token-type: GoogleToken' and
    /// an appropriate OAuth token supplied via the 'access_token' header.
    ///
    /// _Note: this function has been implemented for you._
    ///
    /// - Parameter request: The `RouterRequest` object used to get information about the
    ///                      request.
    /// - Parameter response: The `RouterResponse` object used to respond to the request.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onSkip: The closure to invoke when the plugin doesn't recognize
    ///                     the authentication token in the request.
    public static func authenticate(request: RouterRequest, response: RouterResponse,
                                    onSuccess: @escaping (Self) -> Void,
                                    onFailure: @escaping (HTTPStatusCode?, [String : String]?) -> Void,
                                    onSkip: @escaping (HTTPStatusCode?, [String : String]?) -> Void) {
        // Check whether this request declares that a Google token is being supplied
        guard let type = request.headers["X-token-type"], type == "GoogleToken" else {
            return onSkip(nil, nil)
        }
        // Check whether a token has been supplied
        guard let token = request.headers["access_token"] else {
            return onFailure(nil, nil)
        }
        // Return a cached profile from the cache associated with our type, if one is found
        // (ie. if we have successfully authenticated this token before)
        if let cacheProfile = getFromCache(token: token) {
            return onSuccess(cacheProfile)
        }
        // Attempt to retrieve the subject's profile from Google.
        getGoogleProfile(token: token) { tokenProfile in
            guard let tokenProfile = tokenProfile else {
                Log.error("Failed to retrieve Google profile for token")
                return onFailure(nil, nil)
            }
            saveInCache(profile: tokenProfile, token: token)
            return onSuccess(tokenProfile)
        }
    }
    
    static func getFromCache(token: String) -> Self? {
        #if os(Linux)
        let key = NSString(string: token)
        #else
        let key = token as NSString
        #endif
        let cacheElement = Self.usersCache.object(forKey: key)
        return cacheElement?.userProfile as? Self
    }

    static func saveInCache(profile: Self, token: String) {
        #if os(Linux)
        let key = NSString(string: token)
        #else
        let key = token as NSString
        #endif
        Self.usersCache.setObject(GoogleCacheElement(profile: profile), forKey: key)
    }

}




