# Kitura-CredentialsGoogle
A plugin for the Kitura-Credentials framework that authenticates using the Google web login

![Mac OS X](https://img.shields.io/badge/os-Mac%20OS%20X-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)

## Summary
A plugin for [Kitura-Credentials](https://github.com/IBM-Swift/Kitura-Credentials) framework that authenticates using the [Google web login with OAuth 2.0](https://developers.google.com/youtube/v3/guides/auth/server-side-web-apps).

## Table of Contents
* [Swift version](#swift-version)
* [Example](#example)
* [License](#license)

## Swift version
The latest version of Kitura-CredentialsGoogle works with the DEVELOPMENT-SNAPSHOT-2016-03-24-a version of the Swift binaries. You can download this version of the Swift binaries by following this [link](https://swift.org/download/). Compatibility with other Swift versions is not guaranteed.

## Example
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
And call `authenticate` to login with Google and to handle the redirect (callback) from the Google login web page after successful login:

```swift
router.get("/login/google",
           handler: credentials.authenticate(googleCredentials.name))

router.get("/login/google/callback",
           handler: credentials.authenticate(googleCredentials.name))
```


## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
