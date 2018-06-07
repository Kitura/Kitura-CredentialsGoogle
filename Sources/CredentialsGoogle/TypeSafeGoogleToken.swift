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

public protocol TypeSafeGoogleToken: TypeSafeCredentials {
    
    var id: String { get }
    
    var name: String { get }
    
}

// MARK FacebookCacheElement

/// The cache element for keeping google profile information.
public class GoogleCacheElement {
    /// The user profile information stored as `TypeSafeGoogleToken`.
    public var userProfile: TypeSafeGoogleToken
    
    /// Initialize a `FacebookCacheElement`.
    ///
    /// - Parameter profile: the `TypeSafeGoogleToken` to store.
    public init (profile: TypeSafeGoogleToken) {
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
    // Associates a token cache with the user's type. This relieves the user from having to
    // declare a usersCache property on their conforming type.
    private static var usersCache: NSCache<NSString, GoogleCacheElement> {
        let key = String(reflecting: Self.self)
        if let usersCache = TypeSafeGoogleTokenCache.cacheForType[key] {
            return usersCache
        } else {
            let usersCache = NSCache<NSString, GoogleCacheElement>()
            TypeSafeGoogleTokenCache.cacheForType[key] = usersCache
            return usersCache
        }
    }
    
    /// Provides a default provider name of `Facebook`.
    public var provider: String {
        return "Google"
    }
    
    /// Authenticate incoming request using Facebook OAuth token.
    ///
    /// - Parameter request: The `RouterRequest` object used to get information
    ///                     about the request.
    /// - Parameter response: The `RouterResponse` object used to respond to the
    ///                       request.
    /// - Parameter options: The dictionary of plugin specific options.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onSkip: The closure to invoke when the plugin doesn't recognize
    ///                     the authentication token in the request.
    public static func authenticate(request: RouterRequest, response: RouterResponse, onSuccess: @escaping (Self) -> Void, onFailure: @escaping (HTTPStatusCode?, [String : String]?) -> Void, onSkip: @escaping (HTTPStatusCode?, [String : String]?) -> Void) {
        
        guard let type = request.headers["X-token-type"], type == "GoogleToken" else {
            return onSkip(nil, nil)
        }
        
        guard let token = request.headers["access_token"] else {
            return onFailure(nil, nil)
        }
        
        if let cacheProfile = getFromCache(token: token) {
            return onSuccess(cacheProfile)
        }
        
        getTokenProfile(token: token, callback: { (tokenProfile) in
            guard let tokenProfile = tokenProfile else {
                Log.error("Failed to retrieve Google profile for token")
                return onFailure(nil, nil)
            }
            return onSuccess(tokenProfile)
        })
    }

    
    private static func getTokenProfile(token: String, callback: @escaping (Self?) -> Void) {
        let fbreq = HTTP.request("https://www.googleapis.com/oauth2/v2/userinfo?access_token=\(token)") { response in
            // check you have recieved an ok response from Google
            var body = Data()
            let decoder = JSONDecoder()
            guard let response = response,
                response.statusCode == HTTPStatusCode.OK,
                let _ = try? response.readAllData(into: &body),
                let selfInstance = try? decoder.decode(Self.self, from: body)
                else {
                    return callback(nil)
            }
            
            #if os(Linux)
            let key = NSString(string: token)
            #else
            let key = token as NSString
            #endif
            Self.usersCache.setObject(GoogleCacheElement(profile: selfInstance), forKey: key)
            return callback(selfInstance)
        }
        fbreq.end()
    }
    
    private static func getFromCache(token: String) -> Self? {
        #if os(Linux)
        let key = NSString(string: token)
        #else
        let key = token as NSString
        #endif
        let cacheElement = Self.usersCache.object(forKey: key)
        return cacheElement?.userProfile as? Self
    }
}




