import SwiftUI

struct ExtensionIconButton: View {
    let icon: ExtensionIcon
    let muxyExtension: MuxyExtension
    var size: CGFloat = 13
    var color: Color = MuxyTheme.fgMuted
    var hoverColor: Color = MuxyTheme.fg
    var isEnabled = true
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        IconButtonChrome(
            color: color,
            hoverColor: hoverColor,
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel,
            action: action
        ) {
            ExtensionIconView(icon: icon, muxyExtension: muxyExtension, size: size)
        }
    }
}
