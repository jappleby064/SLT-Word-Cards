import SwiftUI

/// Shown once on first launch. Whatever is picked here can be changed in
/// Settings later without losing anything.
struct ModeChooserView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.brand)

                Text("SLT Word Cards")
                    .font(Theme.display(34, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                Text("How will you be using the app?")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.top, 48)
            .padding(.bottom, 36)

            VStack(spacing: 14) {
                ForEach(AppSettings.Mode.allCases) { mode in
                    choice(mode)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)

            Spacer(minLength: 24)

            Text("You can change this at any time in Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
    }

    private func choice(_ mode: AppSettings.Mode) -> some View {
        Button {
            settings.mode = mode
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: mode.symbol)
                    .font(.title)
                    .frame(width: 44)
                    .foregroundStyle(Theme.brand)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                    Text(mode.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft.opacity(0.6))
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.paperRaised)
            )
        }
        .buttonStyle(.plain)
    }
}
