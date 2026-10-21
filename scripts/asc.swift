// App Store Connect API from the command line, signed with the account's key.
//
//   swift scripts/asc.swift GET  '/v1/apps?filter[bundleId]=com.thomashan.CourtsideHoopStats'
//   swift scripts/asc.swift POST /v1/reviewSubmissions body.json
//   swift scripts/asc.swift screenshots <versionLocalizationID> APP_IPHONE_65 docs/img/*.png
//
// Reads ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (the .p8) from the
// environment, or else `.asc.local.json` ({"keyID", "issuerID", "keyPath"}),
// which is git-ignored: the repo is public, and the key never enters it.
import CryptoKit
import Foundation

let env = ProcessInfo.processInfo.environment
let local = (try? Data(contentsOf: URL(fileURLWithPath: ".asc.local.json")))
    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] } ?? [:]
guard let keyID = env["ASC_KEY_ID"] ?? local["keyID"],
      let issuer = env["ASC_ISSUER_ID"] ?? local["issuerID"],
      let keyPath = env["ASC_KEY_PATH"] ?? local["keyPath"] else {
    FileHandle.standardError.write("Set ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH, or write .asc.local.json.\n".data(using: .utf8)!)
    exit(2)
}
let args = Array(CommandLine.arguments.dropFirst())

func base64url(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
func token() throws -> String {
    let pem = try String(contentsOfFile: keyPath, encoding: .utf8)
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
    let now = Int(Date().timeIntervalSince1970)
    let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyID, "typ": "JWT"])
    let claims = try JSONSerialization.data(withJSONObject: [
        "iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"])
    let signingInput = base64url(header) + "." + base64url(claims)
    let signature = try key.signature(for: Data(signingInput.utf8)).rawRepresentation
    return signingInput + "." + base64url(signature)
}

/// One API call; throws on a non-2xx with Apple's error body.
@discardableResult
func call(_ method: String, _ path: String, _ body: Data? = nil) async throws -> (Int, Data) {
    var request = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com" + path)!)
    request.httpMethod = method
    request.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
    if let body {
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
}
func json(_ data: Data) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
}
func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

// swift scripts/asc.swift screenshots <versionLocalizationID> <displayType> <png...>
// Replaces that display type's screenshots with the files, in order.
if args.first == "screenshots" {
    guard args.count >= 4 else { fail("usage: asc.swift screenshots LOCALIZATION DISPLAY_TYPE file.png...") }
    let localization = args[1], displayType = args[2], files = Array(args[3...])

    // Find or create the set.
    let (_, setsData) = try await call("GET",
        "/v1/appStoreVersionLocalizations/\(localization)/appScreenshotSets?filter[screenshotDisplayType]=\(displayType)")
    var setID = ((json(setsData)["data"] as? [[String: Any]])?.first?["id"] as? String)
    if setID == nil {
        let body = try JSONSerialization.data(withJSONObject: ["data": [
            "type": "appScreenshotSets", "attributes": ["screenshotDisplayType": displayType],
            "relationships": ["appStoreVersionLocalization": ["data": [
                "type": "appStoreVersionLocalizations", "id": localization]]]]])
        let (status, data) = try await call("POST", "/v1/appScreenshotSets", body)
        guard status == 201 else { fail("create set: HTTP \(status) \(String(decoding: data, as: UTF8.self))") }
        setID = (json(data)["data"] as? [String: Any])?["id"] as? String
        print("created set \(displayType)")
    }
    guard let setID else { fail("no set") }

    // Clear what's there.
    let (_, oldData) = try await call("GET", "/v1/appScreenshotSets/\(setID)/relationships/appScreenshots?limit=50")
    for old in (json(oldData)["data"] as? [[String: Any]]) ?? [] {
        let id = old["id"] as! String
        let (status, data) = try await call("DELETE", "/v1/appScreenshots/\(id)")
        guard status == 204 else { fail("delete \(id): HTTP \(status) \(String(decoding: data, as: UTF8.self))") }
    }

    // Reserve, upload, commit — one file at a time keeps the order.
    for file in files {
        let bytes = try Data(contentsOf: URL(fileURLWithPath: file))
        let name = URL(fileURLWithPath: file).lastPathComponent
        let reserve = try JSONSerialization.data(withJSONObject: ["data": [
            "type": "appScreenshots", "attributes": ["fileName": name, "fileSize": bytes.count],
            "relationships": ["appScreenshotSet": ["data": ["type": "appScreenshotSets", "id": setID]]]]])
        let (status, data) = try await call("POST", "/v1/appScreenshots", reserve)
        guard status == 201, let shot = json(data)["data"] as? [String: Any],
              let id = shot["id"] as? String,
              let operations = (shot["attributes"] as? [String: Any])?["uploadOperations"] as? [[String: Any]]
        else { fail("reserve \(name): HTTP \(status) \(String(decoding: data, as: UTF8.self))") }
        for op in operations {
            let offset = op["offset"] as! Int, length = op["length"] as! Int
            var put = URLRequest(url: URL(string: op["url"] as! String)!)
            put.httpMethod = op["method"] as? String ?? "PUT"
            for header in (op["requestHeaders"] as? [[String: String]]) ?? [] {
                put.setValue(header["value"], forHTTPHeaderField: header["name"]!)
            }
            let (_, response) = try await URLSession.shared.upload(for: put, from: bytes.subdata(in: offset..<offset + length))
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { fail("upload \(name): HTTP \(code)") }
        }
        let checksum = Insecure.MD5.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let commit = try JSONSerialization.data(withJSONObject: ["data": [
            "type": "appScreenshots", "id": id,
            "attributes": ["uploaded": true, "sourceFileChecksum": checksum]]])
        let (commitStatus, commitData) = try await call("PATCH", "/v1/appScreenshots/\(id)", commit)
        guard commitStatus == 200 else { fail("commit \(name): HTTP \(commitStatus) \(String(decoding: commitData, as: UTF8.self))") }
        print("uploaded \(name)")
    }
    exit(0)
}

guard args.count >= 2 else {
    FileHandle.standardError.write("usage: asc.swift METHOD PATH [body.json] | screenshots LOC TYPE files...\n".data(using: .utf8)!)
    exit(2)
}
let method = args[0], path = args[1]
let body = args.count > 2 ? try Data(contentsOf: URL(fileURLWithPath: args[2])) : nil
let (status, data) = try await call(method, path, body)
FileHandle.standardOutput.write(data)
print()
if !(200..<300).contains(status) {
    FileHandle.standardError.write("HTTP \(status)\n".data(using: .utf8)!)
    exit(1)
}
