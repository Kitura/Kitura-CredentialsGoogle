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

/**
 A pre-constructed TypeSafeGoogleToken which contains the default fields that can be
 requested from Google.

 Note that the Optional fields will only be initialized if the subject grants access
 to the data.

 ### Usage Example: ###

 ```swift
 router.get("/googleProfile") { (user: GoogleTokenProfile, respondWith: (GoogleTokenProfile?, RequestError?) -> Void) in
 respondWith(user, nil)
 }
 ```
 */
public struct GoogleTokenProfile: TypeSafeGoogleToken {
    
    /// The subject's unique Google identifier.
    public let id: String
    
    /// The subject's display name.
    public let name: String
    
    /// The subject's family name (last name).
    public let family_name: String
    
    /// The subject's given name (first name).
    public let given_name: String
    
    /// A URL providing access to the subject's profile picture.
    public let picture: String
    
    /// The subject's locale, for example: `en`.
    public let locale: String
    
    // MARK: Optional fields
    
    /// The subject's gender. The subject may not have provided this information in
    /// their Google profile.
    public let gender: String?
    
    /// The subject's e-mail address. The subject may choose not to share this information.
    public let email: String?
    
    /// Indicates whether the subject's e-mail address has been verified. Note that
    /// this field is only present if `email` is has been granted.
    public let verified_email: Bool?
}
