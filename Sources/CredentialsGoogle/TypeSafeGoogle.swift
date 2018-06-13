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

import Foundation
import KituraNet
import Credentials
import LoggerAPI

/// A protocol that defines common attributes of Facebook authentication methods.
///
/// It is not intended for a user's type to conform to this protocol directly. Instead,
/// your type should conform to a specific authentication type, such as
/// `TypeSafeFacebookToken`.
public protocol TypeSafeGoogle: TypeSafeCredentials {

}

extension TypeSafeGoogle {
    /// Provides a default provider name of `Google`.
    public var provider: String {
        return "Google"
    }

    /// Gets a subject's profile information from Google using an access token, and
    /// returns an instance of `Self` by decoding the response from Google using JSONDecoder.
    ///
    /// Failure could occur if the response from Google could not be decoded to our type. An
    /// example of when failure might occur is if the user's type declares a field that the
    /// subject declines to share as a non-optional type, for example: `let email: String`.
    ///
    /// - Parameter token: a Google OAuth token
    /// - Parameter callback: A callback that will be invoked with an instance of `Self`
    ///   on success, or `nil` on failure.
    static func getGoogleProfile(token: String, callback: @escaping (Self?) -> Void) {
        let googleReq = HTTP.request("https://www.googleapis.com/oauth2/v2/userinfo?access_token=\(token)") { response in
            // Check we have recieved an OK response from Google
            guard let response = response else {
                Log.error("Request to Google failed: response was nil")
                return callback(nil)
            }
            var body = Data()
            guard response.statusCode == HTTPStatusCode.OK,
                let _ = try? response.readAllData(into: &body)
                else {
                    Log.error("Google request failed: statusCode=\(response.statusCode), body=\(String(data: body, encoding: .utf8) ?? "")")
                    return callback(nil)
            }
            // Attempt to construct the user's type by decoding the Google response
            guard let profile = decodeGoogleResponse(data: body) else {
                Log.debug("Google response data: \(String(data: body, encoding: .utf8) ?? "")")
                return callback(nil)
            }
            return callback(profile)
        }
        googleReq.end()
    }

    /// Attempt to decode the JSON response from Google into an instance of `Self`.
    static func decodeGoogleResponse(data: Data) -> Self? {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Self.self, from: data)
        } catch {
            Log.error("Failed to decode \(Self.self) from Google response, error=\(error)")
            return nil
        }
    }

}
