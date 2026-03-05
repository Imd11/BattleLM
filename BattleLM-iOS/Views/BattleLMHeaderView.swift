import SwiftUI

struct BattleLMHeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image("BattleLMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            // Match mac sidebar header exactly:
            // `Text("BattleLM").font(.custom("Orbitron", size: 20)).fontWeight(.bold)`
            Text("BattleLM")
                .font(.custom("Orbitron", size: 22))
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("BattleLM")
    }
}
