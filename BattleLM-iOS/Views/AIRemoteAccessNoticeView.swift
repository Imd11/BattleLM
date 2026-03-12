import SwiftUI

struct AIRemoteAccessNoticeView: View {
    let disclosures: [AIProviderDisclosure]
    let onDecline: () -> Void
    let onApprove: () -> Void

    private var resolvedDisclosures: [AIProviderDisclosure] {
        disclosures.isEmpty ? [AIDataConsentStore.disclosure(for: "unknown")] : disclosures
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    dataCard
                    routeCard
                    providersCard
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Data Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") {
                        onDecline()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Agree") {
                        onApprove()
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Before you continue, BattleLM needs your permission to share AI chat requests with the provider you choose.")
                .font(.headline)

            Text("This notice is shown before you use remote AI messaging on iPhone.")
                .font(.subheadline)
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

            NoticeBullet(systemName: "text.bubble", text: "Your message or prompt")
            NoticeBullet(systemName: "text.append", text: "Conversation context needed to generate a reply")
            NoticeBullet(systemName: "arrow.triangle.branch", text: "Provider and model routing details required to deliver the request")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it is sent")
                .font(.headline)

            Text("BattleLM sends the request from your iPhone through your paired Mac to the selected third-party AI provider.")
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

private struct NoticeBullet: View {
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
