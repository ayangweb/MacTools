import Foundation
import Security

enum PluginTrustValidatorError: LocalizedError, Equatable {
    case signatureCheckFailed(String)
    case teamIdentifierUnavailable(URL)
    case teamIdentifierMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case let .signatureCheckFailed(reason):
            return "插件签名校验失败：\(reason)"
        case let .teamIdentifierUnavailable(url):
            return "无法读取插件签名团队：\(url.path)"
        case let .teamIdentifierMismatch(expected, actual):
            return "插件签名团队不匹配，期望 \(expected)，实际 \(actual)。"
        }
    }
}

protocol PluginTrustValidating {
    func validatePluginBundle(at bundleURL: URL) throws
}

struct SameTeamPluginTrustValidator: PluginTrustValidating {
    private let hostTeamIdentifier: String?
    private let codeSignatureInfoProvider: CodeSignatureInfoProviding

    init(
        hostBundleURL: URL = Bundle.main.bundleURL,
        codeSignatureInfoProvider: CodeSignatureInfoProviding = SecurityCodeSignatureInfoProvider()
    ) {
        self.codeSignatureInfoProvider = codeSignatureInfoProvider
        self.hostTeamIdentifier = try? codeSignatureInfoProvider.teamIdentifier(for: hostBundleURL)
    }

    func validatePluginBundle(at bundleURL: URL) throws {
        try codeSignatureInfoProvider.validateCodeSignature(at: bundleURL)

        guard let expectedTeamID = hostTeamIdentifier, !expectedTeamID.isEmpty else {
            return
        }

        guard let actualTeamID = try codeSignatureInfoProvider.teamIdentifier(for: bundleURL), !actualTeamID.isEmpty else {
            throw PluginTrustValidatorError.teamIdentifierUnavailable(bundleURL)
        }

        guard actualTeamID == expectedTeamID else {
            throw PluginTrustValidatorError.teamIdentifierMismatch(
                expected: expectedTeamID,
                actual: actualTeamID
            )
        }
    }
}

protocol CodeSignatureInfoProviding {
    func validateCodeSignature(at url: URL) throws
    func teamIdentifier(for url: URL) throws -> String?
}

struct SecurityCodeSignatureInfoProvider: CodeSignatureInfoProviding {
    func validateCodeSignature(at url: URL) throws {
        let code = try staticCode(for: url)
        let status = SecStaticCodeCheckValidity(code, SecCSFlags(), nil)

        guard status == errSecSuccess else {
            throw PluginTrustValidatorError.signatureCheckFailed(secErrorMessage(status))
        }
    }

    func teamIdentifier(for url: URL) throws -> String? {
        let code = try staticCode(for: url)
        var info: CFDictionary?
        let status = SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info
        )

        guard status == errSecSuccess else {
            throw PluginTrustValidatorError.signatureCheckFailed(secErrorMessage(status))
        }

        guard let dictionary = info as? [String: Any] else {
            return nil
        }

        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }

    private func staticCode(for url: URL) throws -> SecStaticCode {
        var code: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &code)

        guard status == errSecSuccess, let code else {
            throw PluginTrustValidatorError.signatureCheckFailed(secErrorMessage(status))
        }

        return code
    }

    private func secErrorMessage(_ status: OSStatus) -> String {
        SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
    }
}
