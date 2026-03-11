import SwiftUI
import BattleLMShared

struct GroupChatView: View {
    let chatId: UUID
    @EnvironmentObject var connection: RemoteConnection
    @EnvironmentObject var aiDataConsentStore: AIDataConsentStore

    @State private var inputText = ""
    @State private var pendingMessageForConsent: String?
    @State private var consentDisclosures: [AIProviderDisclosure] = []
    @State private var showConsentSheet = false
    @FocusState private var isInputFocused: Bool

    private var chat: GroupChatDTO? {
        connection.groupChat(for: chatId)
    }

    private var targetProviders: [String] {
        guard let chat else { return [] }
        let providersById = Dictionary(uniqueKeysWithValues: connection.aiList.map { ($0.id, $0.provider) })
        let providers = chat.memberIds.compactMap { providersById[$0] }
        return providers.isEmpty ? ["unknown"] : providers
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chat?.messages ?? []) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: (chat?.messages.count ?? 0)) { _ in
                    if let last = chat?.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
            inputArea
        }
        .navigationTitle(chat?.name ?? "Group Chat")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConsentSheet) {
            AIDataConsentSheet(disclosures: consentDisclosures) {
                aiDataConsentStore.approve(providers: targetProviders)
                sendConfirmedMessage()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(chat?.memberIds.count ?? 0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .focused($isInputFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if aiDataConsentStore.requiresConsent(for: targetProviders) {
            pendingMessageForConsent = text
            consentDisclosures = aiDataConsentStore.missingDisclosures(for: targetProviders)
            showConsentSheet = true
            return
        }

        inputText = ""
        pendingMessageForConsent = text
        sendConfirmedMessage()
    }

    private func sendConfirmedMessage() {
        guard let text = pendingMessageForConsent?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            pendingMessageForConsent = nil
            return
        }

        inputText = ""
        pendingMessageForConsent = nil

        Task {
            try? await connection.sendGroupMessage(text, to: chatId)
        }
    }
}
