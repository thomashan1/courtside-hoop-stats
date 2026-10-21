// App Store Connect API from the command line, signed with the account's key.
//
//   swift scripts/asc.swift GET  '/v1/apps?filter[bundleId]=com.thomashan.CourtsideHoopStats'
//   swift scripts/asc.swift POST /v1/reviewSubmissions body.json
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
let args = CommandLine.arguments.dropFirst()
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: asc.swift METHOD PATH [body.json]\n".data(using: .utf8)!)
    exit(2)
}
let method = args[args.startIndex], path = args[args.startIndex + 1]
let bodyFile = args.count > 2 ? args[args.startIndex + 2] : nil

func base64url(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
let pem = try String(contentsOfFile: keyPath, encoding: .utf8)
let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
let now = Int(Date().timeIntervalSince1970)
let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyID, "typ": "JWT"])
let claims = try JSONSerialization.data(withJSONObject: [
    "iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"])
let signingInput = base64url(header) + "." + base64url(claims)
let signature = try key.signature(for: Data(signingInput.utf8)).rawRepresentation
let token = signingInput + "." + base64url(signature)

var request = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com" + path)!)
request.httpMethod = method
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
if let bodyFile {
    request.httpBody = try Data(contentsOf: URL(fileURLWithPath: bodyFile))
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
}
let (data, response) = try await URLSession.shared.data(for: request)
let status = (response as? HTTPURLResponse)?.statusCode ?? 0
FileHandle.standardOutput.write(data)
print()
if !(200..<300).contains(status) {
    FileHandle.standardError.write("HTTP \(status)\n".data(using: .utf8)!)
    exit(1)
}
