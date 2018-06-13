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
import XCTest

import Kitura
import KituraNet
import LoggerAPI

@testable import CredentialsGoogle

class TestTypeSafeToken : XCTestCase {

    static var allTests : [(String, (TestTypeSafeToken) -> () throws -> Void)] {
        return [
            ("testDefaultTokenProfile", testDefaultTokenProfile),
            ("testMinimalTokenProfile", testMinimalTokenProfile),
            ("testCache", testCache),
            ("testTwoInCache", testTwoInCache),
            ("testCachedProfile", testCachedProfile),
            ("testMissingTokenType", testMissingTokenType),
            ("testMissingAccessToken", testMissingAccessToken),
        ]
    }

    override func tearDown() {
        doTearDown()
    }

    // An example of a user-defined GoogleToken profile.
    struct TestGoogleToken: TypeSafeGoogleToken, Equatable {
        // Fields that should be retrieved from Google
        var id: String
        var name: String
        var email: String?

        // Fields that should be ignored (not part of the Google API)
        var favouriteArtist: String?
        var favouriteNumber: Int?

        // Testing requirement: Equatable
        static func == (lhs: TestGoogleToken, rhs: TestGoogleToken) -> Bool {
            return lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.provider == rhs.provider
                && lhs.email == rhs.email
                && lhs.favouriteArtist == rhs.favouriteArtist
                && lhs.favouriteNumber == rhs.favouriteNumber
        }
    }

    let token = "Test token"
    let token2 = "Test token 2"

    // A Google response JSON fragment. Two optional fields are present (email, verified_email).
    // Another optional field (gender) is not provided.
    //
    // This data will be decoded into two types during these tests:
    // - an instance of GoogleTokenProfile, which is capable of representing all fields (plus
    //   gender, which is absent from this fragment)
    // - an instance of TestGoogleToken, which defines only 'id', 'name' and 'email'.
    let testGoogleResponse = """
{
  "family_name": "Doe",
  "name": "John Doe",
  "picture": "https://lh4.googleusercontent.com/-abc123/abc123/abc123/abc123/photo.jpg",
  "locale": "en",
  "email": "john_doe@invalid.com",
  "given_name": "John",
  "id": "123456789012345678901",
  "verified_email": true
}
""".data(using: .utf8)!

    // A second Google response JSON fragment, used when testing multiple tokens in a single
    // cache. This subject has declined to share their e-mail address.
    let testGoogleResponse2 = """
{
  "family_name": "Doe",
  "name": "Jane Doe",
  "picture": "https://lh4.googleusercontent.com/-xyz456/xyz456/xyz456/xyz456/photo.jpg",
  "locale": "en",
  "given_name": "Jane",
  "id": "112233445566778899001"
}
""".data(using: .utf8)!

    let router = TestTypeSafeToken.setupCodableRouter()

    // Tests that the pre-constructed GoogleTokenProfile type maps correctly to the
    // JSON response retrieved from the Google user profile API.
    func testDefaultTokenProfile() {
        guard let profileInstance = GoogleTokenProfile.decodeGoogleResponse(data: testGoogleResponse) else {
            return XCTFail("Google JSON response cannot be decoded to GoogleTokenProfile")
        }
        // An equivalent test profile, constructed directly.
        let testTokenProfile = GoogleTokenProfile(id: "123456789012345678901", name: "John Doe", family_name: "Doe", given_name: "John", picture: "https://lh4.googleusercontent.com/-abc123/abc123/abc123/abc123/photo.jpg", locale: "en", gender: nil, email: "john_doe@invalid.com", verified_email: true)

        XCTAssertEqual(profileInstance, testTokenProfile, "The reference GoogleTokenProfile instance did not match the instance decoded from the Google JSON response")
    }

    // Tests that a minimal TypeSafeGoogleToken can be decoded from the same Google
    // JSON response, and that it matches the content that we expect.
    func testMinimalTokenProfile() {
        guard let profileInstance = TestGoogleToken.decodeGoogleResponse(data: testGoogleResponse) else {
            return XCTFail("Google JSON response cannot be decoded to TestGoogleToken")
        }
        let expectedProfile = TestGoogleToken(id: "123456789012345678901", name: "John Doe", email: "john_doe@invalid.com", favouriteArtist: nil, favouriteNumber: nil)
        XCTAssertEqual(profileInstance, expectedProfile, "The reference TestGoogleToken instance did not match the instance decoded from the Google JSON response")
    }
    
    // Tests that a profile can be saved and retreived from the cache
    func testCache() {
        guard let profileInstance = TestGoogleToken.decodeGoogleResponse(data: testGoogleResponse) else {
            return XCTFail("Google JSON response cannot be decoded to TestGoogleToken")
        }
        TestGoogleToken.saveInCache(profile: profileInstance, token: token)
        guard let cacheProfile = TestGoogleToken.getFromCache(token: token) else {
            return XCTFail("Failed to get from cache")
        }
        XCTAssertEqual(cacheProfile, profileInstance, "retrieved different profile from cache")
    }

    // Tests that two different profiles can be saved and retreived from the cache
    func testTwoInCache() {
        guard let profileInstance1 = TestGoogleToken.decodeGoogleResponse(data: testGoogleResponse) else {
            return XCTFail("Google JSON response cannot be decoded to TestGoogleToken")
        }
        guard let profileInstance2 = TestGoogleToken.decodeGoogleResponse(data: testGoogleResponse2) else {
            return XCTFail("Google JSON response cannot be decoded to GoogleTokenProfile")
        }
        TestGoogleToken.saveInCache(profile: profileInstance1, token: token)
        TestGoogleToken.saveInCache(profile: profileInstance2, token: token2)
        guard let cacheProfile1 = TestGoogleToken.getFromCache(token: token) else {
            return XCTFail("Failed to get from cache")
        }
        guard let cacheProfile2 = TestGoogleToken.getFromCache(token: token2) else {
            return XCTFail("Failed to get from cache")
        }
        XCTAssertEqual(cacheProfile1, profileInstance1, "retrieved different profile from cache1")
        XCTAssertEqual(cacheProfile2, profileInstance2, "retrieved different profile from cache2")
    }

    // Tests that a profile stored in the token cache can be retrieved and returned by a Codable
    // route that includes this middleware.
    func testCachedProfile() {
        guard let profileInstance = TestGoogleToken.decodeGoogleResponse(data: testGoogleResponse) else {
            return XCTFail("Google JSON response cannot be decoded to TestGoogleToken")
        }
        TestGoogleToken.saveInCache(profile: profileInstance, token: token)
        performServerTest(router: router) { expectation in
            // Note that currently, this request to /multipleHandlers will fail, as both handlers
            // are invoked and both write a JSON response body (which is itself invalid JSON).
            // If Codable routing in the future equates the writing of data with ending the
            // response, this would work.
            self.performRequest(method: "get", path: "/singleHandler", callback: {response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response?.statusCode))")
                do {
                    guard let body = try response?.readString(), let tokenData = body.data(using: .utf8) else {
                        XCTFail("No response body")
                        return
                    }
                    let decoder = JSONDecoder()
                    let profile = try decoder.decode(TestGoogleToken.self, from: tokenData)
                    XCTAssertEqual(profile, profileInstance, "Body \(profile) is not equal to \(profileInstance)")
                } catch {
                    XCTFail("Could not decode response: \(error)")
                }
                expectation.fulfill()
            }, headers: ["X-token-type" : "GoogleToken", "access_token" : self.token])
        }
    }

    // Tests that when a request to a Codable route that includes this middleware does not
    // contain the matching X-token-type header, the middleware skips authentication and a
    // second handler is instead invoked.
    func testMissingTokenType() {
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path: "/multipleHandlers", callback: {response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response?.statusCode))")
                do {
                    guard let body = try response?.readString(), let responseData = body.data(using: .utf8) else {
                        XCTFail("No response body")
                        return
                    }
                    let decoder = JSONDecoder()
                    let testResponse = try decoder.decode(TestGoogleToken.self, from: responseData)
                    let expectedResponse = TestGoogleToken(id: "123", name: "abc", email: "def", favouriteArtist: "ghi", favouriteNumber: 123)
                    XCTAssertEqual(testResponse, expectedResponse, "Response from second handler did not contain expected data")
                } catch {
                    XCTFail("Could not decode response: \(error)")
                }
                expectation.fulfill()
            }, headers: ["access_token" : self.token])
        }
    }

    // Tests that when a request to a Codable route that includes this middleware contains
    // the matching X-token-type header, but does not supply an access_token, the middleware
    // fails authentication and returns unauthorized.
    func testMissingAccessToken() {
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path: "/multipleHandlers", callback: {response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.unauthorized, "HTTP Status code was \(String(describing: response?.statusCode))")
                expectation.fulfill()
            }, headers: ["X-token-type" : "GoogleToken"])
        }
    }

    static func setupCodableRouter() -> Router {
        let router = Router()
        PrintLogger.use(colored: true)

        router.get("/singleHandler") { (profile: TestGoogleToken, respondWith: (TestGoogleToken?, RequestError?) -> Void) in
            respondWith(profile, nil)
        }

        router.get("/multipleHandlers") { (profile: TestGoogleToken, respondWith: (TestGoogleToken?, RequestError?) -> Void) in
            respondWith(profile, nil)
        }

        router.get("/multipleHandlers") { (respondWith: (TestGoogleToken?, RequestError?) -> Void) in
            respondWith(TestGoogleToken(id: "123", name: "abc", email: "def", favouriteArtist: "ghi", favouriteNumber: 123), nil)
        }

        return router
    }
}
