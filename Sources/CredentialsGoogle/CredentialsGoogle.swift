/**
 * Copyright IBM Corporation 2016
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

import SwiftyJSON

import Foundation

// MARK CredentialsGoogle

/// Authentication using Google web login with OAuth.
/// See [Google's manual](https://developers.google.com/youtube/v3/guides/auth/server-side-web-apps#Obtaining_Access_Tokens)
/// for more information.
public class CredentialsGoogle : CredentialsPluginProtocol {
    
    private var clientId: String
    
    private var clientSecret: String
    
    /// The URL that Google redirects back to.
    public var callbackUrl: String
    
    /// The name of the plugin.
    public var name: String {
        return "Google"
    }
    
    /// An indication as to whether the plugin is redirecting or not.
    public var redirecting: Bool {
        return true
    }

    /// User profile cache.
    public var usersCache: NSCache<NSString, BaseCacheElement>?

    /// Initialize a `CredentialsGoogle` instance.
    ///
    /// - Parameter clientId: The Client ID in the Google Developer's console.
    /// - Parameter clientSecret: The Client Secret in the Google Developer's console.
    /// - Parameter callbackUrl: The URL that Google redirects back to.
    public init (clientId: String, clientSecret: String, callbackUrl: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
    }
    
    /// Authenticate incoming request using Google web login with OAuth.
    ///
    /// - Parameter request: The `RouterRequest` object used to get information
    ///                     about the request.
    /// - Parameter response: The `RouterResponse` object used to respond to the
    ///                       request.
    /// - Parameter options: The dictionary of plugin specific options.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onPass: The closure to invoke when the plugin doesn't recognize the
    ///                     authentication data in the request.
    /// - Parameter inProgress: The closure to invoke to cause a redirect to the login page in the
    ///                     case of redirecting authentication.
    public func authenticate (request: RouterRequest, response: RouterResponse,
                              options: [String:Any], onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              inProgress: @escaping () -> Void) {
        
        if let code = request.queryParameters["code"] {
            var requestOptions: [ClientRequest.Options] = []
            requestOptions.append(.schema("https://"))
            requestOptions.append(.hostname("accounts.google.com"))
            requestOptions.append(.method("POST"))
            requestOptions.append(.path("/o/oauth2/token"))
            var headers = [String:String]()
            headers["Accept"] = "application/json"
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            requestOptions.append(.headers(headers))
 
            let body = "code=\(code)&client_id=\(clientId)&client_secret=\(clientSecret)&redirect_uri=\(callbackUrl)&grant_type=authorization_code"
            
            let requestForToken = HTTP.request(requestOptions) { googleResponse in
                if let googleResponse = googleResponse, googleResponse.statusCode == HTTPStatusCode.OK {
                    do {
                        var body = Data()
                        try googleResponse.readAllData(into: &body)
                        var jsonBody = JSON(data: body)
                        if let token = jsonBody["access_token"].string {
                            requestOptions = []
                            requestOptions.append(.schema("https://"))
                            requestOptions.append(.hostname("www.googleapis.com"))
                            requestOptions.append(.method("GET"))
                            requestOptions.append(.path("//oauth2/v3/userinfo?access_token=\(token)"))
                            headers = [String:String]()
                            headers["Accept"] = "application/json"
                            requestOptions.append(.headers(headers))
                            
                            let requestForProfile = HTTP.request(requestOptions) { profileResponse in
                                if let profileResponse = profileResponse, profileResponse.statusCode == HTTPStatusCode.OK {
                                    do {
                                        body = Data()
                                        try profileResponse.readAllData(into: &body)
                                        jsonBody = JSON(data: body)
                                        if let id = jsonBody["sub"].string,
                                            let name = jsonBody["name"].string {
                                            let userProfile = UserProfile(id: id, displayName: name, provider: self.name)
                                            onSuccess(userProfile)
                                            return
                                        }
                                    }
                                    catch {
                                        Log.error("Failed to read Google response")
                                    }
                                }
                                else {
                                    onFailure(nil, nil)
                                }
                            }
                            requestForProfile.end()
                        }
                    }
                    catch {
                        Log.error("Failed to read Google response")
                    }
                }
                else {
                    onFailure(nil, nil)
                }
            }
            requestForToken.end(body)
        }
        else {
            // Log in
            do {
                try response.redirect("https://accounts.google.com/o/oauth2/auth?client_id=\(clientId)&redirect_uri=\(callbackUrl)&scope=profile&response_type=code")
                inProgress()
            }
            catch {
                Log.error("Failed to redirect to Google login page")
            }
        }
    }
}
