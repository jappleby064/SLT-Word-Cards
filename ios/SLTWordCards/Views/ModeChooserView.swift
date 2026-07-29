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
                    .foregroundStyle(Color.accentColor)

                Text("SLT Word Cards")
                    .font(.largeTitle.weight(.bold))

                Text("How will you be using the app?")
                    .font(.body)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func choice(_ mode: AppSettings.Mode) -> some View {
        Button {
            settings.mode = mode
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: mode.symbol)
                    .font(.title)
                    .frame(width: 44)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                    Text(mode.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
