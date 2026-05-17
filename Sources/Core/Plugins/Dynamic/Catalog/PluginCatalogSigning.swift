import CryptoKit
import Foundation

enum PluginCatalogSigning {
    static let productionPublicKey: Curve25519.Signing.PublicKey? = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "MTPluginCatalogPublicKey") as? String,
            !value.isEmpty,
            let data = Data(base64Encoded: value)
        else {
            return nil
        }

        return try? Curve25519.Signing.PublicKey(rawRepresentation: data)
    }()

    static func signedPayload(fromCatalogData data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)

        guard var dictionary = object as? [String: Any] else {
            throw PluginCatalogVerifierError.signatureVerificationUnavailable
        }

        dictionary.removeValue(forKey: "signature")

        guard JSONSerialization.isValidJSONObject(dictionary) else {
            throw PluginCatalogVerifierError.signatureVerificationUnavailable
        }

        return try JSONSerialization.data(
            withJSONObject: dictionary,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }
}
