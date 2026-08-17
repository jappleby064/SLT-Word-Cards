import SwiftUI

/// The app's palette, type and shape, in one place.
///
/// Until now every view styled itself inline: the accent came from the asset
/// catalog and everything else was `Color(.systemGroupedBackground)` and friends.
/// That gave a grey iOS-default app, while the website is warm paper and teal.
/// These are the same values `styles.css` uses, so the two read as one product.
///
/// The colours resolve through the asset catalog rather than being written as
/// literals here, because each one carries a dark variant. Hardcoding the light
/// palette would leave the app unreadable in dark mode.
enum Theme {

    // MARK: Colour

    /// Deep teal. The one colour that means "this is actionable".
    static let brand = Color.accentColor
    /// The ground the app sits on.
    static let paper = Color("Paper")
    /// Cards, rows and sheets, a shade brighter than the ground.
    static let paperRaised = Color("PaperRaised")
    /// Wells: things recessed into the page.
    static let paperSunk = Color("PaperSunk")

    static let ink = Color("Ink")
    static let inkSoft = Color("InkSoft")
    static let rule = Color("Rule")

    /// For text and glyphs drawn on top of `brand`. Not plain white: the
    /// dark-mode brand is a light teal, and white on it is barely legible.
    static let onBrand = Color("OnBrand")

    /// Terracotta. Used sparingly, and never decoratively — a "not yet" or a
    /// warning, nothing else.
    static let terracotta = Color("Terracotta")
    static let success = Color("Success")

    // MARK: Shape

    /// Four radii doing four jobs, rather than one radius on everything.
    enum Radius {
        static let small: CGFloat = 6    // keys, chips, thumbnails
        static let medium: CGFloat = 10  // rows, controls
        static let large: CGFloat = 14   // cards, sheets
        static let hero: CGFloat = 20    // the presenter card
    }

    static let hairline: CGFloat = 1

    // MARK: Type

    /// Headings and the big presenter word are serif, matching the website's
    /// old-style headings. `.serif` resolves to New York, which is close in
    /// character to the Iowan Old Style the site asks for first.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - Shared modifiers

extension View {
    /// Puts a view on the app's paper ground instead of the system grey, and
    /// stops `List`/`Form` painting their own background over it.
    func paperBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
    }

    /// A raised surface: card, row or panel. Flat and opaque with a hairline
    /// rule — no blur, and no shadow except on the presenter's hero card.
    func paperSurface(radius: CGFloat = Theme.Radius.large) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.paperRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.rule, lineWidth: Theme.hairline)
            )
    }

    /// The 2pt ring drawn around deck thumbnails where they overlap. It was
    /// duplicated verbatim in four views.
    func thumbnailRing(radius: CGFloat = Theme.Radius.small) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Theme.paper, lineWidth: 2)
        )
    }
}
