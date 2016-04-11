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
    
    public init (clientId: String, clientSecret : String, callbackUrl : String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
    }
    
    public var usersCache : NSCache?
    
    /// https://developers.google.com/youtube/v3/guides/auth/server-side-web-apps#Obtaining_Access_Tokens
    public func authenticate (request: RouterRequest, response: RouterResponse, options: [String:AnyObject], onSuccess: (UserProfile) -> Void, onFailure: () -> Void, onPass: () -> Void, inProgress: () -> Void) {
        
        if let code = request.queryParams["code"] {
            var requestOptions = [ClientRequestOptions]()
            requestOptions.append(.Schema("https://"))
            requestOptions.append(.Hostname("accounts.google.com"))
            requestOptions.append(.Method("POST"))
            requestOptions.append(.Path("/o/oauth2/token"))
            var headers = [String:String]()
            headers["Accept"] = "application/json"
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            requestOptions.append(.Headers(headers))
 
            let body = "code=\(code)&client_id=\(clientId)&client_secret=\(clientSecret)&redirect_uri=\(callbackUrl)&grant_type=authorization_code"
            
            let requestForToken = Http.request(requestOptions) { googleResponse in
                if let googleResponse = googleResponse where googleResponse.statusCode == HttpStatusCode.OK {
                    do {
                        var body = NSMutableData()
                        try googleResponse.readAllData(body)
                        var jsonBody = JSON(data: body)
                        if let token = jsonBody["access_token"].string {
                            requestOptions = [ClientRequestOptions]()
                            requestOptions.append(.Schema("https://"))
                            requestOptions.append(.Hostname("www.googleapis.com"))
                            requestOptions.append(.Method("GET"))
                            requestOptions.append(.Path("//oauth2/v3/userinfo?access_token=\(token)"))
                            headers = [String:String]()
                            headers["Accept"] = "application/json"
                            requestOptions.append(.Headers(headers))
                            
                            let requestForProfile = Http.request(requestOptions) { profileResponse in
                                if let profileResponse = profileResponse where profileResponse.statusCode == HttpStatusCode.OK {
                                    do {
                                        body = NSMutableData()
                                        try profileResponse.readAllData(body)
                                        jsonBody = JSON(data: body)
                                        if let id = jsonBody["sub"].string,
                                            let name = jsonBody["name"].string {
                                            let userProfile = UserProfile(id: id, displayName: name, provider: self.name)
                                            let newCacheElement = BaseCacheElement(profile: userProfile)
                                            self.usersCache!.setObject(newCacheElement, forKey: token.bridge())
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
