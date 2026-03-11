import SwiftUI

struct AIDataConsentSheet: View {
    let disclosures: [AIProviderDisclosure]
    let onApprove: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var resolvedDisclosures: [AIProviderDisclosure] {
        disclosures.isEmpty ? [AIDataConsentStore.disclosure(for: "unknown")] : disclosures
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Data Sharing")
                            .font(.title3.weight(.semibold))
                        Text("Before sending this message, BattleLM needs your permission to share it through your paired Mac with the AI provider below.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    consentCard
                    dataCard
                    providersCard
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Agree & Send") {
                        onApprove()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What happens")
                .font(.headline)

            Text("Your message and the conversation context needed to answer it will be transmitted to the selected AI provider.")
                .font(.subheadline)

            Text("Do not send personal, confidential, or regulated information unless you are comfortable with that provider's policies.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data sent")
                .font(.headline)

            ConsentBullet(systemName: "text.bubble", text: "Your message or prompt")
            ConsentBullet(systemName: "text.append", text: "Conversation context needed to generate a reply")
            ConsentBullet(systemName: "arrow.triangle.branch", text: "Provider and model routing details required to deliver the request")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var providersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sent to")
                .font(.headline)

            ForEach(resolvedDisclosures) { disclosure in
                VStack(alignment: .leading, spacing: 2) {
                    Text(disclosure.serviceName)
                        .font(.body.weight(.medium))
                    Text(disclosure.companyName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ConsentBullet: View {
    let systemName: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemName)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 18)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer(minLength: 0)
        }
    }
}
