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

@testable import CredentialsGoogle

extension GoogleTokenProfile: Equatable {
    public static func == (lhs: GoogleTokenProfile, rhs: GoogleTokenProfile) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.provider == rhs.provider
            && lhs.email == rhs.email
            && lhs.family_name == rhs.family_name
            && lhs.gender == rhs.gender
            && lhs.given_name == rhs.given_name
            && lhs.locale == rhs.locale
            && lhs.picture == rhs.picture
            && lhs.verified_email == rhs.verified_email
    }
}

