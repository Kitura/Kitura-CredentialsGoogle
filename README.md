# Kitura-CredentialsGoogle
Plugins for the Kitura-Credentials framework that authenticate using the Google web login and a Google OAuth token

![Mac OS X](https://img.shields.io/badge/os-Mac%20OS%20X-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)

## Summary
Plugins for [Kitura-Credentials](https://github.com/IBM-Swift/Kitura-Credentials) framework that authenticate using the [Google web login with OAuth 2.0](https://developers.google.com/youtube/v3/guides/auth/server-side-web-apps) and a [Google OAuth token](https://developers.google.com/identity/protocols/OAuth2) that was acquired by a mobile app or other client of the Kitura based backend.

## Table of Contents
* [Swift version](#swift-version)
* [Example of Google web login](#example-of-google-web-login)
* [Example of authentication with a Google OAuth token](#example-of-authentication-with-a-google-oauth-token)
* [License](#license)

## Swift version
The latest version of Kitura-CredentialsGoogle requires **Swift 3.0**. You can download this version of the Swift binaries by following this [link](https://swift.org/download/). Compatibility with other Swift versions is not guaranteed.

## Example of Google web login
A complete sample can be found in [Kitura-Credentials-Sample](https://github.com/IBM-Swift/Kitura-Credentials-Sample).
<br>

First create an instance of `CredentialsGoogle` plugin and register it with `Credentials` framework:
```swift
import Credentials
import CredentialsGoogle

let credentials = Credentials()
let googleCredentials = CredentialsGoogle(clientId: googleClientId, clientSecret: googleClientSecret, callbackUrl: serverUrl + "/login/google/callback")
credentials.register(googleCredentials)
```
**Where:**
   - *googleClientId* is the Client ID from the credentials tab of your project in the Google Developer's console
   - *googleClientSecret* is the Client Secret from the credentials tab of your project in the Google Developer's console

**Note:** The *callbackUrl* parameter above is used to tell the Google web login page where the user's browser should be redirected when the login is successful. It should be a URL handled by the server you are writing.

Specify where to redirect non-authenticated requests:
```swift
credentials.options["failureRedirect"] = "/login/google"
```

Connect `credentials` middleware to requests to `/private`:

```swift
router.all("/private", middleware: credentials)
router.get("/private/data", handler:
    { request, response, next in
        ...  
        next()
})
```
And call `authenticate` to login with Google and to handle the redirect (callback) from the Google login web page after a successful login:

```swift
router.get("/login/google",
           handler: credentials.authenticate(googleCredentials.name))

router.get("/login/google/callback",
           handler: credentials.authenticate(googleCredentials.name))
```

## Example of authentication with a Google OAuth token

This example shows how to use `CredentialsGoogleToken` plugin to authenticate post requests, it shows both the server side and the client side of the request involved.

### Server side

First create an instance of `Credentials` and an instance of `CredentialsGoogleToken` plugin:

```swift
import Credentials
import CredentialsGoogle

let credentials = Credentials()
let googleCredentials = CredentialsGoogleToken()
```
Now register the plugin:
```swift
credentials.register(googleCredentials)
```

Connect `credentials` middleware to post requests:

```swift
router.post("/collection/:new", middleware: credentials)
```
If the authentication is successful, `request.userProfile` will contain user profile information received from Google:
```swift
router.post("/collection/:new") {request, response, next in
  ...
  let profile = request.userProfile
  let userId = profile.id
  let userName = profile.displayName
  ...
  next()
}
```

### Client side
The client needs to put [Google access token](https://developers.google.com/identity/protocols/OAuth2) in request's `access_token` HTTP header field, and "GoogleToken" in `X-token-type` field:
```swift
let urlRequest = NSMutableURLRequest(URL: NSURL(string: "http://\(serverUrl)/collection/\(name)"))
urlRequest.HTTPMethod = "POST"
urlRequest.HTTPBody = ...

urlRequest.addValue(googleAccessToken, forHTTPHeaderField: "id_token")
urlRequest.addValue("GoogleToken", forHTTPHeaderField: "X-token-type")     
Alamofire.request(urlRequest).responseJSON {response in
  ...
}

```

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
