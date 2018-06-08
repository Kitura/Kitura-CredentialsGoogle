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

/// A pre-constructed TypeSafeGoogleToken which contains the default
/// that can be requested from Google.
///
/// Note that the Optional fields will only be initialized if the user's OAuth token grants
/// access to the data, and many extended permissions require a Facebook app review prior
/// to that app being allowed to request them.
/**
 ### Usage Example: ###
 router.get("/googleProfile") { (user: GoogleTokenProfile, respondWith: (GoogleTokenProfile?, RequestError?) -> Void) in
 respondWith(user, nil)
 }
 */
public struct GoogleTokenProfile: TypeSafeGoogleToken {
    
    public let id: String
    
    public let name: String
    
    public let family_name: String
    
    public let picture: String
    
    public let locale: String
    
    public let gender: String
    
    public let email: String?
    
    public let given_name: String
    
    public let verified_email: Bool
}
