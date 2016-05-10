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

public class CredentialsGoogle : CredentialsPluginProtocol {
    
    private var clientId : String
    
    private var clientSecret : String
    
    public var callbackUrl : String
    
    public var name : String {
        return "Google"
    }
    
    public var type : CredentialsPluginType {
        return .session
    }

#if os(OSX)
    public var usersCache : NSCache<NSString, BaseCacheElement>?
#else
    public var usersCache : NSCache?
#endif

    
    public init (clientId: String, clientSecret : String, callbackUrl : String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
    }
    
    /// https://developers.google.com/youtube/v3/guides/auth/server-side-web-apps#Obtaining_Access_Tokens
    public func authenticate (request: RouterRequest, response: RouterResponse, options: [String:OptionValue], onSuccess: (UserProfile) -> Void, onFailure: () -> Void, onPass: () -> Void, inProgress: () -> Void) {
        
        if let code = request.queryParams["code"] {
            var requestOptions = [ClientRequestOptions]()
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
                if let googleResponse = googleResponse where googleResponse.statusCode == HTTPStatusCode.OK {
                    do {
                        var body = NSMutableData()
                        try googleResponse.readAllData(into: body)
                        var jsonBody = JSON(data: body)
                        if let token = jsonBody["access_token"].string {
                            requestOptions = [ClientRequestOptions]()
                            requestOptions.append(.schema("https://"))
                            requestOptions.append(.hostname("www.googleapis.com"))
                            requestOptions.append(.method("GET"))
                            requestOptions.append(.path("//oauth2/v3/userinfo?access_token=\(token)"))
                            headers = [String:String]()
                            headers["Accept"] = "application/json"
                            requestOptions.append(.headers(headers))
                            
                            let requestForProfile = HTTP.request(requestOptions) { profileResponse in
                                if let profileResponse = profileResponse where profileResponse.statusCode == HTTPStatusCode.OK {
                                    do {
                                        body = NSMutableData()
                                        try profileResponse.readAllData(into: body)
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
                                    onFailure()
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
                    onFailure()
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
