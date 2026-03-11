import Foundation
import Combine

struct AIProviderDisclosure: Identifiable, Hashable {
    let key: String
    let serviceName: String
    let companyName: String

    var id: String { key }
}

@MainActor
final class AIDataConsentStore: ObservableObject {
    private let storageKey = "approvedAIProviderKeys"
    private let defaults: UserDefaults

    @Published private(set) var approvedProviderKeys: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.approvedProviderKeys = Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    func requiresConsent(for providers: [String]) -> Bool {
        !missingDisclosures(for: providers).isEmpty
    }

    func missingDisclosures(for providers: [String]) -> [AIProviderDisclosure] {
        let requiredKeys = Set(
            providers
                .map(Self.normalizeProviderKey)
                .filter { !$0.isEmpty }
        )

        return requiredKeys
            .subtracting(approvedProviderKeys)
            .sorted()
            .map(Self.disclosure(for:))
    }

    func approve(providers: [String]) {
        let normalized = Set(
            providers
                .map(Self.normalizeProviderKey)
                .filter { !$0.isEmpty }
        )

        guard !normalized.isEmpty else { return }
        approvedProviderKeys.formUnion(normalized)
        defaults.set(Array(approvedProviderKeys).sorted(), forKey: storageKey)
    }

    static func disclosures(for providers: [String]) -> [AIProviderDisclosure] {
        Array(
            Set(
                providers
                    .map(normalizeProviderKey)
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
        .map(disclosure(for:))
    }

    static func normalizeProviderKey(_ raw: String) -> String {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? "unknown" : normalized
    }

    static func disclosure(for key: String) -> AIProviderDisclosure {
        switch key {
        case "claude":
            return AIProviderDisclosure(key: key, serviceName: "Claude", companyName: "Anthropic")
        case "gemini":
            return AIProviderDisclosure(key: key, serviceName: "Gemini", companyName: "Google")
        case "codex", "openai":
            return AIProviderDisclosure(key: key, serviceName: "OpenAI", companyName: "OpenAI")
        case "qwen":
            return AIProviderDisclosure(key: key, serviceName: "Qwen", companyName: "Alibaba")
        case "kimi":
            return AIProviderDisclosure(key: key, serviceName: "Kimi", companyName: "Moonshot AI")
        case "unknown":
            return AIProviderDisclosure(key: key, serviceName: "Selected AI Provider", companyName: "Third-Party AI Provider")
        default:
            let title = key.isEmpty ? "Selected AI Provider" : key.capitalized
            return AIProviderDisclosure(key: key, serviceName: title, companyName: "Third-Party AI Provider")
        }
    }
}
