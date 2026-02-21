import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Parse Arguments
// Args: runtime projectName projectPath editor ttyDevice [mode]
//   mode = "" | "permission" | "--settings"
//   --menu-bar  → persistent menu bar agent mode

let args = CommandLine.arguments
let isSettingsMode = args.contains("--settings")
let isExplicitMenuBar = args.contains("--menu-bar")
let isNotifyMode = args.contains("--notify")   // Explicit notification-only mode (never starts menu bar)

// Auto-detect .app bundle launch: if we're inside a .app bundle AND no notification args given,
// default to menu bar mode. This means double-clicking DevPing.app enters menu bar mode.
let isInsideAppBundle: Bool = {
    let execPath = args[0]
    return execPath.contains(".app/Contents/MacOS/")
}()
let hasNotificationArgs = args.dropFirst().contains(where: { !$0.hasPrefix("-") })
let isMenuBarMode = !isNotifyMode && (isExplicitMenuBar || (isInsideAppBundle && !hasNotificationArgs && !isSettingsMode))

// MARK: - Single Instance Guard
// Prevent duplicate menu bar icons. If another instance with our bundle ID is already
// running, ask it to surface (via activation) and exit immediately.
if isMenuBarMode {
    let bundleID = Bundle.main.bundleIdentifier ?? "com.devping.app"
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    let others = running.filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if !others.isEmpty {
        // Another instance is already running — bring it forward and bail out
        others.first?.activate(options: [])
        exit(0)
    }
}

// Strip all flag args (starting with "--") to get positional args cleanly
let positionalArgs = args.dropFirst().filter { !$0.hasPrefix("-") }
let runtime     = positionalArgs.count > 0 ? positionalArgs[positionalArgs.startIndex] : "Claude"
let projectName = positionalArgs.count > 1 ? positionalArgs[positionalArgs.index(positionalArgs.startIndex, offsetBy: 1)] : "Project"
let projectPath = positionalArgs.count > 2 ? positionalArgs[positionalArgs.index(positionalArgs.startIndex, offsetBy: 2)] : ""
let editorArg   = positionalArgs.count > 3 ? positionalArgs[positionalArgs.index(positionalArgs.startIndex, offsetBy: 3)] : "Terminal"
let ttyDevice   = positionalArgs.count > 4 ? positionalArgs[positionalArgs.index(positionalArgs.startIndex, offsetBy: 4)] : "none"
let mode        = positionalArgs.count > 5 ? positionalArgs[positionalArgs.index(positionalArgs.startIndex, offsetBy: 5)] : ""

let isPermission = mode == "permission"
let hasTTY = ttyDevice != "none" && !ttyDevice.isEmpty

// MARK: - Settings Enums

enum ScreenPosition: String, CaseIterable, Identifiable {
    case topRight = "topRight"
    case topLeft = "topLeft"
    case bottomRight = "bottomRight"
    case bottomLeft = "bottomLeft"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topRight: return "Top Right"
        case .topLeft: return "Top Left"
        case .bottomRight: return "Bottom Right"
        case .bottomLeft: return "Bottom Left"
        }
    }
}

enum DisplayTarget: String, CaseIterable, Identifiable {
    case main = "main"
    case withCursor = "withCursor"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .main: return "Main Display"
        case .withCursor: return "Display with Cursor"
        }
    }
}

enum NotificationSize: String, CaseIterable, Identifiable {
    case compact = "compact"       // Tiny — minimal footprint, glanceable
    case small = "small"           // Slim — like Apple's native notification banner
    case standard = "standard"     // Default — balanced information density
    case large = "large"           // Roomy — comfortable reading, larger touch targets
    case xlarge = "xlarge"         // Prominent — maximum presence, large type

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact:  return "Compact"
        case .small:    return "Small"
        case .standard: return "Standard"
        case .large:    return "Large"
        case .xlarge:   return "X-Large"
        }
    }

    // Panel dimensions — Apple notification is ~340x90, each size steps clearly
    var panelWidth: CGFloat {
        switch self {
        case .compact:  return 260
        case .small:    return 310
        case .standard: return 360
        case .large:    return 420
        case .xlarge:   return 500
        }
    }

    var panelHeight: CGFloat {
        switch self {
        case .compact:  return 90
        case .small:    return 115
        case .standard: return 150
        case .large:    return 195
        case .xlarge:   return 260
        }
    }

    var contentWidth: CGFloat {
        switch self {
        case .compact:  return 230
        case .small:    return 280
        case .standard: return 330
        case .large:    return 390
        case .xlarge:   return 470
        }
    }

    // Typography — scales proportionally with clear hierarchy per size
    var headerFont: CGFloat {
        switch self {
        case .compact:  return 11
        case .small:    return 12
        case .standard: return 13
        case .large:    return 16
        case .xlarge:   return 20
        }
    }

    var bodyFont: CGFloat {
        switch self {
        case .compact:  return 10
        case .small:    return 11
        case .standard: return 12
        case .large:    return 14
        case .xlarge:   return 17
        }
    }

    var captionFont: CGFloat {
        switch self {
        case .compact:  return 9
        case .small:    return 10
        case .standard: return 11
        case .large:    return 12
        case .xlarge:   return 15
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact:  return 10
        case .small:    return 12
        case .standard: return 14
        case .large:    return 18
        case .xlarge:   return 24
        }
    }

    var smallIconSize: CGFloat {
        switch self {
        case .compact:  return 8
        case .small:    return 9
        case .standard: return 10
        case .large:    return 13
        case .xlarge:   return 16
        }
    }

    /// App icon size in the notification header (used for .icns app icons)
    var appIconSize: CGFloat {
        switch self {
        case .compact:  return 20
        case .small:    return 26
        case .standard: return 32
        case .large:    return 40
        case .xlarge:   return 52
        }
    }

    // Spacing — generous at xlarge, tight at compact
    var outerPadding: CGFloat {
        switch self {
        case .compact:  return 6
        case .small:    return 8
        case .standard: return 10
        case .large:    return 14
        case .xlarge:   return 18
        }
    }

    var innerPadding: CGFloat {
        switch self {
        case .compact:  return 4
        case .small:    return 6
        case .standard: return 8
        case .large:    return 12
        case .xlarge:   return 16
        }
    }

    var buttonPadding: CGFloat {
        switch self {
        case .compact:  return 4
        case .small:    return 5
        case .standard: return 7
        case .large:    return 9
        case .xlarge:   return 12
        }
    }

    var elementSpacing: CGFloat {
        switch self {
        case .compact:  return 2
        case .small:    return 3
        case .standard: return 4
        case .large:    return 6
        case .xlarge:   return 10
        }
    }

    var indicatorWidth: CGFloat {
        switch self {
        case .compact:  return 2.5
        case .small:    return 3
        case .standard: return 4
        case .large:    return 4.5
        case .xlarge:   return 5.5
        }
    }

    var buttonRadius: CGFloat {
        switch self {
        case .compact:  return 4
        case .small:    return 5
        case .standard: return 6
        case .large:    return 7
        case .xlarge:   return 9
        }
    }

    var buttonFontSize: CGFloat {
        switch self {
        case .compact:  return 10
        case .small:    return 11
        case .standard: return 13
        case .large:    return 14
        case .xlarge:   return 16
        }
    }
}

// MARK: - Color Theme

enum ColorTheme: String, CaseIterable, Identifiable {
    case system = "system"         // Native macOS (system accent)
    case coral = "coral"           // Airbnb-inspired warm coral
    case cinematic = "cinematic"   // Netflix-inspired deep red
    case sand = "sand"             // Arc/Notion warm sand & peach
    case indigo = "indigo"         // Stripe-inspired rich indigo
    case luxury = "luxury"         // Champagne gold on black
    case ember = "ember"           // Firebase-inspired amber/orange
    case material = "material"     // Google Material teal
    case noir = "noir"             // Vercel-inspired pure black/white
    case electric = "electric"     // Spotify-inspired electric green

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:    return "System"
        case .coral:     return "Coral"
        case .cinematic: return "Cinematic"
        case .sand:      return "Sand"
        case .indigo:    return "Indigo"
        case .luxury:    return "Luxury"
        case .ember:     return "Ember"
        case .material:  return "Material"
        case .noir:      return "Noir"
        case .electric:  return "Electric"
        }
    }

    var subtitle: String {
        switch self {
        case .system:    return "Native macOS look"
        case .coral:     return "Airbnb warmth"
        case .cinematic: return "Netflix drama"
        case .sand:      return "Calm & earthy"
        case .indigo:    return "Stripe precision"
        case .luxury:    return "Gold on black"
        case .ember:     return "Firebase energy"
        case .material:  return "Google clean"
        case .noir:      return "Vercel minimal"
        case .electric:  return "Spotify bold"
        }
    }

    /// Whether this is a custom-surface theme vs system native
    var isCustom: Bool { self != .system }

    // ── Typography personality ──

    /// Font design — gives each theme a distinct typographic feel
    var fontDesign: Font.Design {
        switch self {
        case .system:    return .default        // SF Pro — native Apple
        case .coral:     return .rounded         // Friendly, approachable (Airbnb feel)
        case .cinematic: return .default         // Clean, cinematic
        case .sand:      return .serif           // Literary, editorial (Notion feel)
        case .indigo:    return .default         // Precise, technical (Stripe feel)
        case .luxury:    return .serif           // Elegant, editorial
        case .ember:     return .rounded         // Friendly, energetic
        case .material:  return .rounded         // Soft, Material feel
        case .noir:      return .monospaced      // Terminal, developer (Vercel feel)
        case .electric:  return .default         // Clean, bold
        }
    }

    /// Header font weight — heavier = bolder personality
    var headerWeight: Font.Weight {
        switch self {
        case .system:    return .semibold
        case .coral:     return .bold
        case .cinematic: return .heavy
        case .sand:      return .medium
        case .indigo:    return .semibold
        case .luxury:    return .light
        case .ember:     return .bold
        case .material:  return .medium
        case .noir:      return .bold
        case .electric:  return .heavy
        }
    }

    /// Body font weight
    var bodyWeight: Font.Weight {
        switch self {
        case .luxury:    return .light
        case .cinematic: return .medium
        case .noir:      return .medium
        case .sand:      return .regular
        default:         return .regular
        }
    }

    /// Button font weight
    var buttonWeight: Font.Weight {
        switch self {
        case .cinematic, .electric: return .bold
        case .luxury:               return .medium
        case .noir:                 return .semibold
        default:                    return .semibold
        }
    }

    /// Extra letter spacing for themes that benefit from it
    var headerTracking: CGFloat {
        switch self {
        case .luxury:    return 1.5   // Spaced-out luxury feel
        case .noir:      return 0.8   // Slightly tracked monospace
        case .cinematic: return 0.5   // Cinematic titling
        default:         return 0
        }
    }

    /// Status label is uppercased for certain themes
    var uppercaseStatus: Bool {
        switch self {
        case .luxury, .noir, .cinematic, .electric: return true
        default: return false
        }
    }

    /// Border width for notification edge
    var borderWidth: CGFloat {
        switch self {
        case .noir:   return 1.0    // Crisp 1px Vercel border
        case .luxury: return 0.5    // Thin gold line
        default:      return 0.5
        }
    }

    /// Indicator glow radius — some themes glow more
    var indicatorGlow: CGFloat {
        switch self {
        case .electric:  return 12   // Neon glow
        case .cinematic: return 10   // Dramatic glow
        case .ember:     return 8    // Warm glow
        default:         return 6
        }
    }

    // ── Colors ──

    /// Primary accent color
    var accent: Color {
        switch self {
        case .system:    return Color.accentColor
        case .coral:     return Color(red: 1.0, green: 0.35, blue: 0.37)   // #FF5A5F Airbnb rausch
        case .cinematic: return Color(red: 0.90, green: 0.04, blue: 0.08)  // #E50914 Netflix red
        case .sand:      return Color(red: 0.82, green: 0.62, blue: 0.45)  // warm earth
        case .indigo:    return Color(red: 0.40, green: 0.35, blue: 0.95)  // #635BFF Stripe
        case .luxury:    return Color(red: 0.85, green: 0.75, blue: 0.55)  // champagne gold
        case .ember:     return Color(red: 1.0, green: 0.60, blue: 0.15)   // #FF9800 Firebase amber
        case .material:  return Color(red: 0.0, green: 0.74, blue: 0.65)   // #00BFA5 Google teal
        case .noir:      return Color.white                                 // Pure white accent
        case .electric:  return Color(red: 0.12, green: 0.84, blue: 0.38)  // #1ED760 Spotify green
        }
    }

    /// Secondary accent (for gradients, highlights)
    var accentSecondary: Color {
        switch self {
        case .system:    return Color.accentColor.opacity(0.8)
        case .coral:     return Color(red: 1.0, green: 0.55, blue: 0.50)
        case .cinematic: return Color(red: 0.65, green: 0.0, blue: 0.0)
        case .sand:      return Color(red: 0.72, green: 0.52, blue: 0.38)
        case .indigo:    return Color(red: 0.30, green: 0.50, blue: 1.0)
        case .luxury:    return Color(red: 0.75, green: 0.65, blue: 0.45)
        case .ember:     return Color(red: 1.0, green: 0.42, blue: 0.0)
        case .material:  return Color(red: 0.0, green: 0.58, blue: 0.53)
        case .noir:      return Color(white: 0.6)
        case .electric:  return Color(red: 0.10, green: 0.65, blue: 0.30)
        }
    }

    /// Surface background (dark)
    var surface: Color {
        switch self {
        case .system:    return Color.cardBackground
        case .coral:     return Color(red: 0.12, green: 0.08, blue: 0.07)   // Warm near-black
        case .cinematic: return Color(red: 0.06, green: 0.05, blue: 0.05)   // Movie theater dark
        case .sand:      return Color(red: 0.96, green: 0.94, blue: 0.90)   // Light parchment
        case .indigo:    return Color(red: 0.07, green: 0.06, blue: 0.14)   // Deep indigo night
        case .luxury:    return Color(red: 0.04, green: 0.04, blue: 0.04)   // Near-pure black
        case .ember:     return Color(red: 0.10, green: 0.07, blue: 0.03)   // Warm charcoal
        case .material:  return Color(red: 0.96, green: 0.97, blue: 0.97)   // Material light surface
        case .noir:      return Color(red: 0.0, green: 0.0, blue: 0.0)      // Pure black
        case .electric:  return Color(red: 0.08, green: 0.08, blue: 0.08)   // Spotify dark
        }
    }

    /// Primary text — light themes get dark text, dark themes get white
    var textPrimary: Color {
        switch self {
        case .system:    return Color.inkPrimary
        case .sand:      return Color(red: 0.15, green: 0.12, blue: 0.10)   // Dark brown on light
        case .material:  return Color(red: 0.12, green: 0.14, blue: 0.14)   // Dark grey on light
        default:         return Color.white
        }
    }

    /// Secondary text
    var textSecondary: Color {
        switch self {
        case .system:    return Color.inkSecondary
        case .sand:      return Color(red: 0.40, green: 0.35, blue: 0.30)
        case .material:  return Color(red: 0.35, green: 0.38, blue: 0.38)
        default:         return Color.white.opacity(0.60)
        }
    }

    /// Tertiary text
    var textTertiary: Color {
        switch self {
        case .system:    return Color.inkTertiary
        case .sand:      return Color(red: 0.55, green: 0.50, blue: 0.45)
        case .material:  return Color(red: 0.50, green: 0.53, blue: 0.53)
        default:         return Color.white.opacity(0.35)
        }
    }

    /// Button text on accent background
    var accentTextColor: Color {
        switch self {
        case .luxury:    return Color.black
        case .noir:      return Color.black
        case .sand:      return Color.white
        case .material:  return Color.white
        case .electric:  return Color.black
        default:         return Color.white
        }
    }

    /// Secondary button background — varies per theme
    var secondaryButtonBg: Color {
        switch self {
        case .sand:      return Color(red: 0.15, green: 0.12, blue: 0.10).opacity(0.08)
        case .material:  return Color(red: 0.12, green: 0.14, blue: 0.14).opacity(0.08)
        default:         return Color.white.opacity(0.08)
        }
    }

    /// Secondary button border
    var secondaryButtonBorder: Color {
        switch self {
        case .sand:      return Color(red: 0.15, green: 0.12, blue: 0.10).opacity(0.15)
        case .material:  return Color(red: 0.12, green: 0.14, blue: 0.14).opacity(0.12)
        case .noir:      return Color.white.opacity(0.25)   // Crisp border
        default:         return Color.white.opacity(0.15)
        }
    }

    /// Surface overlay gradient colors (top-left to bottom-right)
    var overlayGradient: [Color] {
        switch self {
        case .cinematic: return [accent.opacity(0.15), Color.clear, Color.clear]  // Red wash from top
        case .indigo:    return [accentSecondary.opacity(0.12), accent.opacity(0.06), Color.clear]
        case .luxury:    return [accent.opacity(0.08), Color.clear, Color.clear]  // Subtle gold shimmer
        case .electric:  return [accent.opacity(0.10), Color.clear, Color.clear]
        case .sand:      return [Color.clear]  // No overlay on light surface
        case .material:  return [Color.clear]  // No overlay on light surface
        default:         return [accentSecondary.opacity(0.10), accent.opacity(0.05), Color.clear]
        }
    }

    /// Edge border gradient
    var borderGradient: [Color] {
        switch self {
        case .noir:      return [Color.white.opacity(0.20), Color.white.opacity(0.08)]  // Clean white border
        case .sand:      return [Color(red: 0.55, green: 0.50, blue: 0.45).opacity(0.25), Color(red: 0.55, green: 0.50, blue: 0.45).opacity(0.10)]
        case .material:  return [Color.black.opacity(0.10), Color.black.opacity(0.05)]
        case .luxury:    return [accent.opacity(0.40), accent.opacity(0.10), Color.white.opacity(0.03)]
        default:         return [accent.opacity(0.30), accentSecondary.opacity(0.15), Color.white.opacity(0.05)]
        }
    }

    /// Timer bar track color
    var trackBg: Color {
        switch self {
        case .sand:      return Color(red: 0.15, green: 0.12, blue: 0.10).opacity(0.10)
        case .material:  return Color(red: 0.12, green: 0.14, blue: 0.14).opacity(0.10)
        default:         return Color.white.opacity(0.08)
        }
    }

    /// Status color: completion
    var statusComplete: Color {
        switch self {
        case .system: return Color.green
        case .coral:  return accent
        case .cinematic: return accent
        default: return accent
        }
    }

    /// Status color: permission needed
    var statusPermission: Color {
        switch self {
        case .system: return Color.orange
        case .sand:   return Color(red: 0.85, green: 0.55, blue: 0.25)
        default:      return Color(red: 1.0, green: 0.65, blue: 0.25)
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Design Variant

/// Each color theme provides 3 variants: light, dark, and glass.
/// Glass builds on top of the base appearance with translucency + blur + tinted overlay.
enum DesignVariant: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case glass = "glass"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark:  return "Dark"
        case .glass: return "Glass"
        }
    }

    var iconName: String {
        switch self {
        case .light: return "sun.max"
        case .dark:  return "moon"
        case .glass: return "rectangle.on.rectangle.angled"
        }
    }
}

/// Complete resolved design — a snapshot of all colors/typography for a given theme + variant.
/// This replaces scattered `theme.isCustom` checks with a single resolved palette.
struct ResolvedDesign {
    // Surface
    let surface: Color
    let surfaceOpacity: Double
    let useVibrancy: Bool          // Whether to use NSVisualEffectView behind the surface
    let vibrancyMaterial: NSVisualEffectView.Material

    // Text
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // Accent
    let accent: Color
    let accentSecondary: Color
    let accentText: Color          // Text color on accent backgrounds

    // Buttons
    let primaryButtonBg: [Color]   // Gradient stops
    let secondaryButtonBg: Color
    let secondaryButtonBorder: Color
    let secondaryButtonText: Color

    // Chrome
    let borderGradient: [Color]
    let overlayGradient: [Color]
    let indicatorGlow: CGFloat
    let borderWidth: CGFloat
    let trackBg: Color

    // Status
    let statusComplete: Color
    let statusPermission: Color

    // Typography personality (from theme)
    let fontDesign: Font.Design
    let headerWeight: Font.Weight
    let bodyWeight: Font.Weight
    let buttonWeight: Font.Weight
    let headerTracking: CGFloat
    let uppercaseStatus: Bool

    // Glass-specific
    let isGlass: Bool
    let glassTint: Color           // Tint color overlaid on blur
    let glassTintOpacity: Double
    let glassBlurRadius: CGFloat   // Extra gaussian blur
    let glassRefractionStrength: Double  // Highlight refraction intensity
}

extension ColorTheme {
    /// Resolve a complete design for this theme + variant combination.
    /// `effectiveAppearance` controls how glass adapts: light glass or dark glass.
    func resolve(variant: DesignVariant, effectiveAppearance: AppearanceMode = .system) -> ResolvedDesign {
        switch variant {
        case .light: return resolveLight()
        case .dark:  return resolveDark()
        case .glass:
            let isDark = effectiveAppearance == .dark ||
                (effectiveAppearance == .system && NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
            return resolveGlass(isDark: isDark)
        }
    }

    // ── Light variant ──
    private func resolveLight() -> ResolvedDesign {
        let isSystem = (self == .system)

        // Light surfaces for each theme
        let lightSurface: Color
        let lightTextPrimary: Color
        let lightTextSecondary: Color
        let lightTextTertiary: Color
        let lightSecBtnBg: Color
        let lightSecBtnBorder: Color

        switch self {
        case .system:
            lightSurface = Color(nsColor: .windowBackgroundColor)
            lightTextPrimary = Color(nsColor: .labelColor)
            lightTextSecondary = Color(nsColor: .secondaryLabelColor)
            lightTextTertiary = Color(nsColor: .tertiaryLabelColor)
            lightSecBtnBg = Color(nsColor: .controlColor)
            lightSecBtnBorder = Color(nsColor: .separatorColor).opacity(0.5)
        case .coral:
            lightSurface = Color(red: 0.99, green: 0.97, blue: 0.96)
            lightTextPrimary = Color(red: 0.18, green: 0.12, blue: 0.10)
            lightTextSecondary = Color(red: 0.45, green: 0.35, blue: 0.32)
            lightTextTertiary = Color(red: 0.60, green: 0.52, blue: 0.48)
            lightSecBtnBg = Color(red: 0.18, green: 0.12, blue: 0.10).opacity(0.06)
            lightSecBtnBorder = Color(red: 0.18, green: 0.12, blue: 0.10).opacity(0.12)
        case .cinematic:
            lightSurface = Color(red: 0.98, green: 0.96, blue: 0.96)
            lightTextPrimary = Color(red: 0.15, green: 0.10, blue: 0.10)
            lightTextSecondary = Color(red: 0.40, green: 0.30, blue: 0.30)
            lightTextTertiary = Color(red: 0.55, green: 0.45, blue: 0.45)
            lightSecBtnBg = Color(red: 0.15, green: 0.10, blue: 0.10).opacity(0.06)
            lightSecBtnBorder = Color(red: 0.15, green: 0.10, blue: 0.10).opacity(0.12)
        case .sand:
            lightSurface = Color(red: 0.96, green: 0.94, blue: 0.90)
            lightTextPrimary = Color(red: 0.15, green: 0.12, blue: 0.10)
            lightTextSecondary = Color(red: 0.40, green: 0.35, blue: 0.30)
            lightTextTertiary = Color(red: 0.55, green: 0.50, blue: 0.45)
            lightSecBtnBg = Color(red: 0.15, green: 0.12, blue: 0.10).opacity(0.08)
            lightSecBtnBorder = Color(red: 0.15, green: 0.12, blue: 0.10).opacity(0.15)
        case .indigo:
            lightSurface = Color(red: 0.96, green: 0.96, blue: 0.99)
            lightTextPrimary = Color(red: 0.10, green: 0.08, blue: 0.20)
            lightTextSecondary = Color(red: 0.30, green: 0.28, blue: 0.50)
            lightTextTertiary = Color(red: 0.50, green: 0.48, blue: 0.65)
            lightSecBtnBg = Color(red: 0.10, green: 0.08, blue: 0.20).opacity(0.06)
            lightSecBtnBorder = Color(red: 0.10, green: 0.08, blue: 0.20).opacity(0.12)
        case .luxury:
            lightSurface = Color(red: 0.97, green: 0.96, blue: 0.94)
            lightTextPrimary = Color(red: 0.12, green: 0.10, blue: 0.08)
            lightTextSecondary = Color(red: 0.35, green: 0.30, blue: 0.25)
            lightTextTertiary = Color(red: 0.55, green: 0.48, blue: 0.40)
            lightSecBtnBg = Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.06)
            lightSecBtnBorder = Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.12)
        case .ember:
            lightSurface = Color(red: 0.99, green: 0.97, blue: 0.94)
            lightTextPrimary = Color(red: 0.18, green: 0.12, blue: 0.05)
            lightTextSecondary = Color(red: 0.45, green: 0.35, blue: 0.20)
            lightTextTertiary = Color(red: 0.60, green: 0.50, blue: 0.35)
            lightSecBtnBg = Color(red: 0.18, green: 0.12, blue: 0.05).opacity(0.06)
            lightSecBtnBorder = Color(red: 0.18, green: 0.12, blue: 0.05).opacity(0.12)
        case .material:
            lightSurface = Color(red: 0.96, green: 0.97, blue: 0.97)
            lightTextPrimary = Color(red: 0.12, green: 0.14, blue: 0.14)
            lightTextSecondary = Color(red: 0.35, green: 0.38, blue: 0.38)
            lightTextTertiary = Color(red: 0.50, green: 0.53, blue: 0.53)
            lightSecBtnBg = Color(red: 0.12, green: 0.14, blue: 0.14).opacity(0.08)
            lightSecBtnBorder = Color(red: 0.12, green: 0.14, blue: 0.14).opacity(0.12)
        case .noir:
            lightSurface = Color(red: 0.97, green: 0.97, blue: 0.97)
            lightTextPrimary = Color(red: 0.08, green: 0.08, blue: 0.08)
            lightTextSecondary = Color(red: 0.30, green: 0.30, blue: 0.30)
            lightTextTertiary = Color(red: 0.50, green: 0.50, blue: 0.50)
            lightSecBtnBg = Color.black.opacity(0.06)
            lightSecBtnBorder = Color.black.opacity(0.15)
        case .electric:
            lightSurface = Color(red: 0.95, green: 0.98, blue: 0.96)
            lightTextPrimary = Color(red: 0.08, green: 0.14, blue: 0.10)
            lightTextSecondary = Color(red: 0.25, green: 0.38, blue: 0.30)
            lightTextTertiary = Color(red: 0.42, green: 0.52, blue: 0.46)
            lightSecBtnBg = Color(red: 0.08, green: 0.14, blue: 0.10).opacity(0.06)
            lightSecBtnBorder = Color(red: 0.08, green: 0.14, blue: 0.10).opacity(0.12)
        }

        let lightBorder: [Color] = isSystem
            ? [Color.black.opacity(0.08), Color.black.opacity(0.04)]
            : [accent.opacity(0.20), accentSecondary.opacity(0.08)]

        let lightOverlay: [Color] = [Color.clear]

        return ResolvedDesign(
            surface: lightSurface,
            surfaceOpacity: 1.0,
            useVibrancy: isSystem,
            vibrancyMaterial: .sheet,
            textPrimary: lightTextPrimary,
            textSecondary: lightTextSecondary,
            textTertiary: lightTextTertiary,
            accent: accent,
            accentSecondary: accentSecondary,
            accentText: accentTextColor,
            primaryButtonBg: [accent, accentSecondary],
            secondaryButtonBg: lightSecBtnBg,
            secondaryButtonBorder: lightSecBtnBorder,
            secondaryButtonText: lightTextPrimary,
            borderGradient: lightBorder,
            overlayGradient: lightOverlay,
            indicatorGlow: indicatorGlow,
            borderWidth: borderWidth,
            trackBg: lightTextTertiary.opacity(0.15),
            statusComplete: statusComplete,
            statusPermission: statusPermission,
            fontDesign: fontDesign,
            headerWeight: headerWeight,
            bodyWeight: bodyWeight,
            buttonWeight: buttonWeight,
            headerTracking: headerTracking,
            uppercaseStatus: uppercaseStatus,
            isGlass: false,
            glassTint: .clear,
            glassTintOpacity: 0,
            glassBlurRadius: 0,
            glassRefractionStrength: 0
        )
    }

    // ── Dark variant ──
    private func resolveDark() -> ResolvedDesign {
        let isSystem = (self == .system)

        // Dark surfaces — use existing theme surfaces (most are already dark)
        let darkSurface: Color
        let darkTextPrimary: Color
        let darkTextSecondary: Color
        let darkTextTertiary: Color
        let darkSecBtnBg: Color
        let darkSecBtnBorder: Color

        switch self {
        case .system:
            darkSurface = Color(nsColor: .windowBackgroundColor)
            darkTextPrimary = Color(nsColor: .labelColor)
            darkTextSecondary = Color(nsColor: .secondaryLabelColor)
            darkTextTertiary = Color(nsColor: .tertiaryLabelColor)
            darkSecBtnBg = Color(nsColor: .controlColor)
            darkSecBtnBorder = Color(nsColor: .separatorColor).opacity(0.5)
        case .coral:
            darkSurface = Color(red: 0.12, green: 0.08, blue: 0.07)
            darkTextPrimary = Color.white
            darkTextSecondary = Color.white.opacity(0.60)
            darkTextTertiary = Color.white.opacity(0.35)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.15)
        case .cinematic:
            darkSurface = Color(red: 0.06, green: 0.05, blue: 0.05)
            darkTextPrimary = Color.white
            darkTextSecondary = Color.white.opacity(0.60)
            darkTextTertiary = Color.white.opacity(0.35)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.15)
        case .sand:
            darkSurface = Color(red: 0.14, green: 0.12, blue: 0.09)
            darkTextPrimary = Color(red: 0.92, green: 0.88, blue: 0.82)
            darkTextSecondary = Color(red: 0.70, green: 0.64, blue: 0.56)
            darkTextTertiary = Color(red: 0.52, green: 0.46, blue: 0.40)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.12)
        case .indigo:
            darkSurface = Color(red: 0.07, green: 0.06, blue: 0.14)
            darkTextPrimary = Color.white
            darkTextSecondary = Color.white.opacity(0.60)
            darkTextTertiary = Color.white.opacity(0.35)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.15)
        case .luxury:
            darkSurface = Color(red: 0.04, green: 0.04, blue: 0.04)
            darkTextPrimary = Color.white
            darkTextSecondary = Color.white.opacity(0.60)
            darkTextTertiary = Color.white.opacity(0.35)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.15)
        case .ember:
            darkSurface = Color(red: 0.10, green: 0.07, blue: 0.03)
            darkTextPrimary = Color.white
            darkTextSecondary = Color.white.opacity(0.60)
            darkTextTertiary = Color.white.opacity(0.35)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.15)
        case .material:
            darkSurface = Color(red: 0.10, green: 0.12, blue: 0.12)
            darkTextPrimary = Color(red: 0.92, green: 0.94, blue: 0.94)
            darkTextSecondary = Color(red: 0.65, green: 0.68, blue: 0.68)
            darkTextTertiary = Color(red: 0.45, green: 0.48, blue: 0.48)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.12)
        case .noir:
            darkSurface = Color.black
            darkTextPrimary = Color.white
            darkTextSecondary = Color(white: 0.6)
            darkTextTertiary = Color(white: 0.4)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.25)
        case .electric:
            darkSurface = Color(red: 0.08, green: 0.08, blue: 0.08)
            darkTextPrimary = Color.white
            darkTextSecondary = Color.white.opacity(0.60)
            darkTextTertiary = Color.white.opacity(0.35)
            darkSecBtnBg = Color.white.opacity(0.08)
            darkSecBtnBorder = Color.white.opacity(0.15)
        }

        return ResolvedDesign(
            surface: darkSurface,
            surfaceOpacity: 1.0,
            useVibrancy: isSystem,
            vibrancyMaterial: .hudWindow,
            textPrimary: darkTextPrimary,
            textSecondary: darkTextSecondary,
            textTertiary: darkTextTertiary,
            accent: accent,
            accentSecondary: accentSecondary,
            accentText: accentTextColor,
            primaryButtonBg: [accent, accentSecondary],
            secondaryButtonBg: darkSecBtnBg,
            secondaryButtonBorder: darkSecBtnBorder,
            secondaryButtonText: darkTextPrimary,
            borderGradient: isSystem
                ? [Color.white.opacity(0.45), Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.05)]
                : borderGradient,
            overlayGradient: overlayGradient,
            indicatorGlow: indicatorGlow,
            borderWidth: borderWidth,
            trackBg: isSystem ? Color(nsColor: .separatorColor).opacity(0.5) : trackBg,
            statusComplete: statusComplete,
            statusPermission: statusPermission,
            fontDesign: fontDesign,
            headerWeight: headerWeight,
            bodyWeight: bodyWeight,
            buttonWeight: buttonWeight,
            headerTracking: headerTracking,
            uppercaseStatus: uppercaseStatus,
            isGlass: false,
            glassTint: .clear,
            glassTintOpacity: 0,
            glassBlurRadius: 0,
            glassRefractionStrength: 0
        )
    }

    // ── Glass variant ──
    /// Glass adapts to the effective system appearance: frosted-light or frosted-dark.
    /// On light: bright translucent surface, dark text, subtle accent tint.
    /// On dark: smoky translucent surface, light text, richer accent tint.
    private func resolveGlass(isDark: Bool) -> ResolvedDesign {
        // Theme-specific tint color (same regardless of light/dark)
        let tint: Color
        switch self {
        case .system:    tint = Color(white: 0.5)
        case .coral:     tint = Color(red: 1.0, green: 0.35, blue: 0.37)
        case .cinematic: tint = Color(red: 0.90, green: 0.04, blue: 0.08)
        case .sand:      tint = Color(red: 0.82, green: 0.72, blue: 0.55)
        case .indigo:    tint = Color(red: 0.40, green: 0.35, blue: 0.95)
        case .luxury:    tint = Color(red: 0.85, green: 0.75, blue: 0.55)
        case .ember:     tint = Color(red: 1.0, green: 0.60, blue: 0.15)
        case .material:  tint = Color(red: 0.0, green: 0.74, blue: 0.65)
        case .noir:      tint = isDark ? Color.white : Color.black
        case .electric:  tint = Color(red: 0.12, green: 0.84, blue: 0.38)
        }

        // ── Appearance-adaptive values ──
        let glassSurface: Color
        let glassSurfaceOpacity: Double
        let glassMaterial: NSVisualEffectView.Material
        let tintOpacity: Double
        let refractionStrength: Double
        let glassTextPrimary: Color
        let glassTextSecondary: Color
        let glassTextTertiary: Color
        let glassSecBtnBg: Color
        let glassSecBtnBorder: Color
        let glassBorder: [Color]
        let glassTrack: Color

        if isDark {
            // ── Dark glass: Apple Control Center style ──
            // Minimal surface fill — let the blur do the work.
            // .hudWindow gives the right smoky translucency.
            glassSurface = Color(white: 0.10)
            glassSurfaceOpacity = 0.12           // Very subtle — mostly blur
            glassMaterial = .hudWindow
            tintOpacity = 0.05                   // Barely-there theme tint
            refractionStrength = 0.10            // Gentle specular, not flashy
            glassTextPrimary = Color.white
            glassTextSecondary = Color.white.opacity(0.88)
            glassTextTertiary = Color.white.opacity(0.65)
            glassSecBtnBg = Color.white.opacity(0.22)
            glassSecBtnBorder = Color.white.opacity(0.45)
            // Strong 3D emboss border
            glassBorder = [Color.white.opacity(0.55), Color.white.opacity(0.20), Color.black.opacity(0.15)]
            glassTrack = Color.white.opacity(0.15)
        } else {
            // ── Light glass: Apple Control Center style (light mode) ──
            // .underWindowBackground is the most translucent light material.
            // Minimal surface fill so the frosted blur dominates.
            glassSurface = Color(white: 0.94)
            glassSurfaceOpacity = 0.08           // Near-zero — let blur dominate
            glassMaterial = .hudWindow
            tintOpacity = 0.03
            refractionStrength = 0.06
            glassTextPrimary = Color.black
            glassTextSecondary = Color.black.opacity(0.70)
            glassTextTertiary = Color.black.opacity(0.50)
            glassSecBtnBg = Color.black.opacity(0.08)
            glassSecBtnBorder = Color.black.opacity(0.20)
            // Strong 3D emboss: bright top → mid → dark bottom
            glassBorder = [Color.white.opacity(0.90), Color.white.opacity(0.30), Color.black.opacity(0.20)]
            glassTrack = Color.black.opacity(0.10)
        }

        // Accent text needs to contrast with the accent background, same as base theme
        let glassAccentText = accentTextColor

        return ResolvedDesign(
            surface: glassSurface,
            surfaceOpacity: glassSurfaceOpacity,
            useVibrancy: true,
            vibrancyMaterial: glassMaterial,
            textPrimary: glassTextPrimary,
            textSecondary: glassTextSecondary,
            textTertiary: glassTextTertiary,
            accent: accent,
            accentSecondary: accentSecondary,
            accentText: glassAccentText,
            primaryButtonBg: [accent, accentSecondary],  // Full saturation buttons
            secondaryButtonBg: glassSecBtnBg,
            secondaryButtonBorder: glassSecBtnBorder,
            secondaryButtonText: glassTextPrimary,
            borderGradient: glassBorder,
            overlayGradient: [tint.opacity(tintOpacity), Color.clear],
            indicatorGlow: indicatorGlow,
            borderWidth: 1.0,  // Thicker border for visible 3D emboss
            trackBg: glassTrack,
            statusComplete: statusComplete,
            statusPermission: statusPermission,
            fontDesign: fontDesign,
            headerWeight: headerWeight,
            bodyWeight: bodyWeight,
            buttonWeight: buttonWeight,
            headerTracking: headerTracking,
            uppercaseStatus: uppercaseStatus,
            isGlass: true,
            glassTint: tint,
            glassTintOpacity: tintOpacity,
            glassBlurRadius: 20,
            glassRefractionStrength: refractionStrength
        )
    }
}

enum AnimationStyle: String, CaseIterable, Identifiable {
    case slide = "slide"
    case fade = "fade"
    case none = "none"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slide: return "Slide"
        case .fade: return "Fade"
        case .none: return "None"
        }
    }
}

// MARK: - Path Resolution

/// Resolves paths for the devping binary, checking .app bundle first, then Homebrew, then ~/.local/bin
enum DevPingPaths {
    /// The path to the notification binary (for spawning test notifications / hooks)
    static var notificationBinary: String {
        // 1. Inside .app bundle (Contents/MacOS/devping)
        if let bundlePath = Bundle.main.executablePath {
            let bundleDir = (bundlePath as NSString).deletingLastPathComponent
            let candidate = (bundleDir as NSString).appendingPathComponent("devping")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
            // If we ARE the binary inside the bundle, use our own path
            if bundlePath.hasSuffix("/devping") {
                return bundlePath
            }
        }
        // 2. Homebrew
        let brewPath = "/opt/homebrew/bin/devping"
        if FileManager.default.isExecutableFile(atPath: brewPath) {
            return brewPath
        }
        // 3. ~/.local/bin
        let localPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/devping").path
        if FileManager.default.isExecutableFile(atPath: localPath) {
            return localPath
        }
        // 4. Current executable as fallback
        return CommandLine.arguments[0]
    }
}

// MARK: - Settings Manager

final class Settings {
    static let shared = Settings()

    private let defaults: UserDefaults
    private let suiteName = "com.devping.app"

    private init() {
        defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            // Onboarding
            "hasCompletedOnboarding": false,
            // General
            "completionSound": "Glass",
            "permissionSound": "Tink",
            "dismissTimeout": 30.0,
            "soundEnabled": true,
            "popupEnabled": true,
            // When editor is focused
            "focusedPopup": false,           // Don't show popup when editor is active
            "focusedSound": true,            // Play sound when editor is active
            "focusedSoundVolume": 0.5,       // 50% of normal volume when focused
            // Position & Display
            "screenPosition": ScreenPosition.topRight.rawValue,
            "displayTarget": DisplayTarget.main.rawValue,
            // Appearance
            "notificationSize": NotificationSize.standard.rawValue,
            "cornerRadius": 12.0,
            "panelOpacity": 1.0,
            "appearanceMode": AppearanceMode.system.rawValue,
            "designProfile": ColorTheme.system.rawValue,
            "designVariant": DesignVariant.dark.rawValue,
            // Sound
            "soundVolume": 0.7,
            // Timing & Animation
            "animationStyle": AnimationStyle.slide.rawValue,
            // Do Not Disturb
            "dndEnabled": false,
            "dndStartHour": 22,
            "dndStartMinute": 0,
            "dndEndHour": 8,
            "dndEndMinute": 0,
        ])
    }

    // ── Onboarding ──

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // ── General ──

    var completionSound: String {
        get { defaults.string(forKey: "completionSound") ?? "Glass" }
        set { defaults.set(newValue, forKey: "completionSound") }
    }

    var permissionSound: String {
        get { defaults.string(forKey: "permissionSound") ?? "Tink" }
        set { defaults.set(newValue, forKey: "permissionSound") }
    }

    var dismissTimeout: Double {
        get { defaults.double(forKey: "dismissTimeout") }
        set { defaults.set(newValue, forKey: "dismissTimeout") }
    }

    var soundEnabled: Bool {
        get { defaults.bool(forKey: "soundEnabled") }
        set { defaults.set(newValue, forKey: "soundEnabled") }
    }

    var popupEnabled: Bool {
        get { defaults.bool(forKey: "popupEnabled") }
        set { defaults.set(newValue, forKey: "popupEnabled") }
    }

    /// Show popup even when the editor is the active window
    var focusedPopup: Bool {
        get { defaults.bool(forKey: "focusedPopup") }
        set { defaults.set(newValue, forKey: "focusedPopup") }
    }

    /// Play sound when the editor is the active window
    var focusedSound: Bool {
        get { defaults.bool(forKey: "focusedSound") }
        set { defaults.set(newValue, forKey: "focusedSound") }
    }

    /// Sound volume multiplier when editor is focused (0.0–1.0, applied on top of soundVolume)
    var focusedSoundVolume: Float {
        get { defaults.float(forKey: "focusedSoundVolume") }
        set { defaults.set(newValue, forKey: "focusedSoundVolume") }
    }

    // ── Position & Display ──

    var screenPosition: ScreenPosition {
        get { ScreenPosition(rawValue: defaults.string(forKey: "screenPosition") ?? "") ?? .topRight }
        set { defaults.set(newValue.rawValue, forKey: "screenPosition") }
    }

    var displayTarget: DisplayTarget {
        get { DisplayTarget(rawValue: defaults.string(forKey: "displayTarget") ?? "") ?? .main }
        set { defaults.set(newValue.rawValue, forKey: "displayTarget") }
    }

    // ── Appearance ──

    var notificationSize: NotificationSize {
        get { NotificationSize(rawValue: defaults.string(forKey: "notificationSize") ?? "") ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: "notificationSize") }
    }

    var cornerRadius: Double {
        get { defaults.double(forKey: "cornerRadius") }
        set { defaults.set(newValue, forKey: "cornerRadius") }
    }

    var panelOpacity: Double {
        get { defaults.double(forKey: "panelOpacity") }
        set { defaults.set(newValue, forKey: "panelOpacity") }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: defaults.string(forKey: "appearanceMode") ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: "appearanceMode") }
    }

    var colorTheme: ColorTheme {
        get { ColorTheme(rawValue: defaults.string(forKey: "designProfile") ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: "designProfile") }
    }

    var designVariant: DesignVariant {
        get { DesignVariant(rawValue: defaults.string(forKey: "designVariant") ?? "") ?? .dark }
        set { defaults.set(newValue.rawValue, forKey: "designVariant") }
    }

    /// Get the fully resolved design based on current theme + variant + appearance settings
    var resolvedDesign: ResolvedDesign {
        colorTheme.resolve(variant: designVariant, effectiveAppearance: appearanceMode)
    }

    // ── Sound ──

    var soundVolume: Float {
        get { defaults.float(forKey: "soundVolume") }
        set { defaults.set(newValue, forKey: "soundVolume") }
    }

    // ── Do Not Disturb ──

    var dndEnabled: Bool {
        get { defaults.bool(forKey: "dndEnabled") }
        set { defaults.set(newValue, forKey: "dndEnabled") }
    }

    var dndStartHour: Int {
        get { defaults.integer(forKey: "dndStartHour") }
        set { defaults.set(newValue, forKey: "dndStartHour") }
    }

    var dndStartMinute: Int {
        get { defaults.integer(forKey: "dndStartMinute") }
        set { defaults.set(newValue, forKey: "dndStartMinute") }
    }

    var dndEndHour: Int {
        get { defaults.integer(forKey: "dndEndHour") }
        set { defaults.set(newValue, forKey: "dndEndHour") }
    }

    var dndEndMinute: Int {
        get { defaults.integer(forKey: "dndEndMinute") }
        set { defaults.set(newValue, forKey: "dndEndMinute") }
    }

    // ── Animation ──

    var animationStyle: AnimationStyle {
        get { AnimationStyle(rawValue: defaults.string(forKey: "animationStyle") ?? "") ?? .slide }
        set { defaults.set(newValue.rawValue, forKey: "animationStyle") }
    }

    /// List available macOS system sounds
    static var availableSounds: [String] {
        let soundDir = "/System/Library/Sounds"
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: soundDir) else { return [] }
        return files
            .filter { $0.hasSuffix(".aiff") }
            .map { $0.replacingOccurrences(of: ".aiff", with: "") }
            .sorted()
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        let domain = suiteName
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        registerDefaults()
    }
}

// MARK: - Sound Player

func playNotificationSound(isPermission: Bool) {
    let settings = Settings.shared
    guard settings.soundEnabled else { return }

    let soundName = isPermission ? settings.permissionSound : settings.completionSound
    playSoundByName(soundName, volume: settings.soundVolume)
}

func playSoundByName(_ name: String, volume: Float = 0.7) {
    let soundPath = "/System/Library/Sounds/\(name).aiff"

    if let sound = NSSound(contentsOfFile: soundPath, byReference: true) {
        sound.volume = volume
        sound.play()
    } else {
        // Fallback: afplay
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        proc.arguments = ["-v", String(volume), soundPath]
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }
}

/// Play a preview sound (for settings UI)
func previewSound(_ name: String) {
    playSoundByName(name, volume: Settings.shared.soundVolume)
}

// MARK: - Focus Detection

/// Check if the given editor app is currently the frontmost application
func isEditorFocused(_ editor: Editor) -> Bool {
    guard let frontmost = NSWorkspace.shared.frontmostApplication else { return false }
    let frontName = frontmost.localizedName ?? ""
    let editorApp = editor.appName

    // Direct name match
    if frontName == editorApp { return true }

    // Fuzzy matching for variants (e.g. "Code" for "Visual Studio Code")
    let frontLower = frontName.lowercased()
    let editorLower = editorApp.lowercased()

    if frontLower.contains(editorLower) || editorLower.contains(frontLower) { return true }

    // Special cases
    switch editor {
    case .vscode:
        return frontLower.contains("code") || frontLower.contains("visual studio")
    case .iterm:
        return frontLower.contains("iterm")
    default:
        return false
    }
}

// MARK: - Editor

enum Editor: String, CaseIterable {
    case zed = "Zed"
    case cursor = "Cursor"
    case vscode = "VSCode"
    case windsurf = "Windsurf"
    case void_ = "Void"
    case sublime = "Sublime"
    case fleet = "Fleet"
    case nova = "Nova"
    case warp = "Warp"
    case iterm = "iTerm"
    case wezterm = "WezTerm"
    case alacritty = "Alacritty"
    case ghostty = "Ghostty"
    case terminal = "Terminal"
    case unknown = "Unknown"

    var appName: String {
        switch self {
        case .zed: return "Zed"
        case .cursor: return "Cursor"
        case .vscode: return "Visual Studio Code"
        case .windsurf: return "Windsurf"
        case .void_: return "Void"
        case .sublime: return "Sublime Text"
        case .fleet: return "Fleet"
        case .nova: return "Nova"
        case .warp: return "Warp"
        case .iterm: return "iTerm2"
        case .wezterm: return "WezTerm"
        case .alacritty: return "Alacritty"
        case .ghostty: return "Ghostty"
        case .terminal, .unknown: return "Terminal"
        }
    }

    var openCommand: String? {
        switch self {
        case .zed: return "zed"
        case .cursor: return "cursor"
        case .vscode: return "code"
        case .windsurf: return "windsurf"
        case .void_: return "void"
        case .sublime: return "subl"
        case .fleet: return "fleet"
        default: return nil
        }
    }

    var isTerminal: Bool {
        switch self {
        case .warp, .iterm, .wezterm, .alacritty, .ghostty, .terminal, .unknown:
            return true
        default: return false
        }
    }

    var iconName: String {
        switch self {
        case .zed, .cursor, .vscode, .windsurf, .void_, .sublime, .fleet, .nova:
            return "chevron.left.forwardslash.chevron.right"
        case .warp, .iterm, .wezterm, .alacritty, .ghostty, .terminal:
            return "rectangle.topthird.inset.filled"
        case .unknown:
            return "questionmark.app"
        }
    }

    /// Bundle identifier used for runtime icon lookup
    var bundleIdentifier: String? {
        switch self {
        case .zed:       return "dev.zed.Zed"
        case .cursor:    return "com.todesktop.230313mzl4w4u92"
        case .vscode:    return "com.microsoft.VSCode"
        case .windsurf:  return "com.codeium.windsurf"
        case .sublime:   return "com.sublimetext.4"
        case .fleet:     return "Fleet.app"
        case .nova:      return "com.panic.Nova"
        case .warp:      return "dev.warp.Warp-Stable"
        case .iterm:     return "com.googlecode.iterm2"
        case .wezterm:   return "com.github.wez.wezterm"
        case .alacritty: return "org.alacritty"
        case .ghostty:   return "com.mitchellh.ghostty"
        case .terminal:  return "com.apple.Terminal"
        case .void_:     return nil
        case .unknown:   return nil
        }
    }

    var displayName: String {
        switch self {
        case .void_: return "Void"
        default: return rawValue
        }
    }

    static func from(_ string: String) -> Editor {
        let lower = string.lowercased()
        for e in allCases where e.rawValue.lowercased() == lower { return e }
        if lower.contains("code") || lower.contains("vscode") { return .vscode }
        if lower.contains("cursor") { return .cursor }
        if lower.contains("zed") { return .zed }
        if lower.contains("windsurf") { return .windsurf }
        if lower.contains("iterm") { return .iterm }
        if lower.contains("ghostty") { return .ghostty }
        return .terminal
    }
}

let editor = Editor.from(editorArg)

// MARK: - App Icon Resolver

/// Resolves app icons from installed macOS applications via their bundle identifiers.
/// Falls back to SF Symbols if the app isn't installed or icon can't be found.
final class AppIconResolver {
    static let shared = AppIconResolver()
    private var cache: [String: NSImage] = [:]

    /// Get the app icon for an editor. Returns nil if no real icon is found (caller should fall back to SF Symbol).
    func icon(for editor: Editor) -> NSImage? {
        if let bundleID = editor.bundleIdentifier {
            return icon(forBundleID: bundleID)
        }
        return nil
    }

    /// Get the app icon for a runtime (e.g. "Claude", "OpenCode")
    func icon(forRuntime runtime: String) -> NSImage? {
        let lower = runtime.lowercased()
        if lower.contains("claude") {
            return icon(forBundleID: "com.anthropic.claudecode")
                ?? icon(forAppName: "Claude")
        }
        if lower.contains("opencode") {
            return icon(forAppName: "OpenCode")
        }
        return nil
    }

    private func icon(forBundleID bundleID: String) -> NSImage? {
        if let cached = cache[bundleID] { return cached }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        // Verify it's not the generic document icon by checking size
        // NSWorkspace returns a valid icon for found apps
        cache[bundleID] = icon
        return icon
    }

    private func icon(forAppName name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        // Search common locations
        let searchPaths = [
            "/Applications/\(name).app",
            "/Applications/Utilities/\(name).app",
            "/System/Applications/\(name).app",
            "/System/Applications/Utilities/\(name).app",
        ]
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                let icon = NSWorkspace.shared.icon(forFile: path)
                cache[name] = icon
                return icon
            }
        }
        return nil
    }
}

/// SwiftUI wrapper that displays an NSImage (app icon) with proper sizing
struct AppIconImage: View {
    let nsImage: NSImage
    let size: CGFloat
    let cornerRadius: CGFloat

    init(_ nsImage: NSImage, size: CGFloat, cornerRadius: CGFloat = 0) {
        self.nsImage = nsImage
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Image(nsImage: nsImage)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius > 0 ? cornerRadius : size * 0.22, style: .continuous))
    }
}

// MARK: - Terminal Focusing

func focusTerminalWindowByTTY(_ tty: String) -> Bool {
    let ttyName = tty.replacingOccurrences(of: "/dev/", with: "")
    let script = """
    tell application "Terminal"
        activate
        repeat with w in every window
            repeat with t in every tab of w
                if tty of t contains "\(ttyName)" then
                    set index of w to 1
                    set selected tab of w to t
                    return true
                end if
            end repeat
        end repeat
        return false
    end tell
    """
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", script]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    try? proc.run()
    proc.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return out.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
}

func focusiTermWindowByTTY(_ tty: String) -> Bool {
    let ttyName = tty.replacingOccurrences(of: "/dev/", with: "")
    let script = """
    tell application "iTerm2"
        activate
        repeat with w in every window
            repeat with t in every tab of w
                repeat with s in every session of t
                    if tty of s contains "\(ttyName)" then
                        select t
                        select s
                        set index of w to 1
                        return true
                    end if
                end repeat
            end repeat
        end repeat
        return false
    end tell
    """
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", script]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    try? proc.run()
    proc.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return out.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
}

// MARK: - Notification Stacking

let stackDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".cache/devping/stack")

func ensureStackDir() {
    try? FileManager.default.createDirectory(at: stackDir, withIntermediateDirectories: true)
}

func claimSlot() -> Int {
    ensureStackDir()
    for slot in 0..<20 {
        let lockFile = stackDir.appendingPathComponent("slot-\(slot).lock")
        if !FileManager.default.fileExists(atPath: lockFile.path) {
            let pid = "\(ProcessInfo.processInfo.processIdentifier)"
            try? pid.write(to: lockFile, atomically: true, encoding: .utf8)
            return slot
        }
        if let pidStr = try? String(contentsOf: lockFile, encoding: .utf8),
           let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if kill(pid, 0) != 0 {
                let myPid = "\(ProcessInfo.processInfo.processIdentifier)"
                try? myPid.write(to: lockFile, atomically: true, encoding: .utf8)
                return slot
            }
        }
    }
    return 0
}

func releaseSlot(_ slot: Int) {
    let lockFile = stackDir.appendingPathComponent("slot-\(slot).lock")
    try? FileManager.default.removeItem(at: lockFile)
}

// MARK: - Runtime & Editor Brand Colors

extension Editor {
    /// Brand color for the accent bar -- each app gets its own identity
    var brandColor: Color {
        switch self {
        case .cursor:    return Color(red: 0.15, green: 0.15, blue: 0.18)   // Near-black
        case .vscode:    return Color(red: 0.18, green: 0.50, blue: 0.90)   // Microsoft blue
        case .zed:       return Color(red: 0.30, green: 0.65, blue: 0.95)   // Zed blue
        case .windsurf:  return Color(red: 0.10, green: 0.75, blue: 0.65)   // Teal
        case .void_:     return Color(red: 0.50, green: 0.50, blue: 0.55)   // Grey
        case .sublime:   return Color(red: 1.0, green: 0.60, blue: 0.20)    // Sublime orange
        case .fleet:     return Color(red: 0.55, green: 0.35, blue: 0.90)   // JetBrains purple
        case .nova:      return Color(red: 0.20, green: 0.55, blue: 0.95)   // Nova blue
        case .warp:      return Color(red: 0.22, green: 0.82, blue: 0.70)   // Warp teal
        case .iterm:     return Color(red: 0.30, green: 0.72, blue: 0.30)   // Green
        case .wezterm:   return Color(red: 0.60, green: 0.40, blue: 0.85)   // Purple
        case .alacritty: return Color(red: 0.95, green: 0.60, blue: 0.20)   // Orange
        case .ghostty:   return Color(red: 0.45, green: 0.45, blue: 0.50)   // Grey
        case .terminal:  return Color(red: 0.35, green: 0.35, blue: 0.40)   // Dark grey
        case .unknown:   return Color(red: 0.50, green: 0.50, blue: 0.55)
        }
    }
}

/// Status color — uses theme-specific accent colors
func statusColor(_ isPermission: Bool, theme: ColorTheme = .system) -> Color {
    isPermission ? theme.statusPermission : theme.statusComplete
}

// MARK: - Design System

extension Color {
    // ── Classic (Apple Native) ──
    static let inkPrimary = Color(nsColor: .labelColor)
    static let inkSecondary = Color(nsColor: .secondaryLabelColor)
    static let inkTertiary = Color(nsColor: .tertiaryLabelColor)

    // Surfaces — all system adaptive
    static let cardBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBorder = Color(nsColor: .separatorColor)
    static let controlBg = Color(nsColor: .controlColor)
    static let controlBorder = Color(nsColor: .separatorColor)
    static let trackBg = Color(nsColor: .separatorColor)

    // Note: theme-specific colors are now provided by the ColorTheme enum
}

// MARK: - Liquid Glass Background

/// Wraps NSVisualEffectView for true macOS vibrancy/blur — the "liquid glass" look.
struct VibrancyView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.layer?.cornerRadius = cornerRadius
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let color: Color
    let width: CGFloat
    let theme: ColorTheme

    init(color: Color, width: CGFloat = 4, theme: ColorTheme = .system) {
        self.color = color
        self.width = width
        self.theme = theme
    }

    var body: some View {
        Group {
            if theme.isCustom {
                // Custom theme: glowing gradient bar
                RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width)
                    .shadow(color: color.opacity(0.6), radius: theme.indicatorGlow, x: 0, y: 0)
            } else {
                RoundedRectangle(cornerRadius: width / 2, style: .continuous)
                    .fill(color)
                    .frame(width: width)
            }
        }
    }
}

// MARK: - Button Styles

/// Classic: flat system accent button
struct PrimaryButtonStyle: ButtonStyle {
    var fontSize: CGFloat = 13
    var padding: CGFloat = 7
    var radius: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.accentColor)
                    .opacity(configuration.isPressed ? 0.75 : 1.0)
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Classic: subtle bordered secondary button
struct SecondaryButtonStyle: ButtonStyle {
    var fontSize: CGFloat = 13
    var padding: CGFloat = 7
    var radius: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.controlBg)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.controlBorder.opacity(0.5), lineWidth: 0.5)
                }
                .opacity(configuration.isPressed ? 0.6 : 1.0)
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Theme-aware: gradient primary button with glow
struct ThemePrimaryButtonStyle: ButtonStyle {
    var fontSize: CGFloat = 13
    var padding: CGFloat = 7
    var radius: CGFloat = 6
    var theme: ColorTheme = .system

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: theme.buttonWeight, design: theme.fontDesign))
            .foregroundColor(theme.accentTextColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.accent, theme.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
                    .shadow(color: theme.accent.opacity(configuration.isPressed ? 0.1 : 0.35), radius: 8, x: 0, y: 2)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Theme-aware: frosted glass secondary button
struct ThemeSecondaryButtonStyle: ButtonStyle {
    var fontSize: CGFloat = 13
    var padding: CGFloat = 7
    var radius: CGFloat = 6
    var theme: ColorTheme = .system

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: theme.bodyWeight, design: theme.fontDesign))
            .foregroundColor(theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(theme.secondaryButtonBg)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(theme.secondaryButtonBorder, lineWidth: theme.borderWidth)
                }
                .opacity(configuration.isPressed ? 0.5 : 1.0)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Timer Bar

struct TimerBar: View {
    let totalDuration: Double
    var theme: ColorTheme = .system
    var barHeight: CGFloat = 2
    @State private var progress: CGFloat = 1.0

    private let laserRed = Color(red: 1.0, green: 0.10, blue: 0.10)
    private let laserSize: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule(style: .continuous)
                    .fill(theme.isCustom ? theme.trackBg : Color.trackBg.opacity(0.5))
                    .frame(height: barHeight)

                // Progress fill — bright red
                Capsule(style: .continuous)
                    .fill(laserRed)
                    .frame(width: max(geo.size.width * progress, 2), height: barHeight)

                // Laser pointer dot at the leading edge of remaining progress
                Circle()
                    .fill(laserRed)
                    .frame(width: laserSize, height: laserSize)
                    .shadow(color: laserRed.opacity(0.9), radius: 6, x: 0, y: 0)
                    .shadow(color: laserRed.opacity(0.5), radius: 12, x: 0, y: 0)
                    .offset(x: max(geo.size.width * progress - laserSize / 2, 0))
            }
            .onAppear {
                withAnimation(.linear(duration: totalDuration)) {
                    progress = 0
                }
            }
        }
        .frame(height: max(barHeight, laserSize))
    }
}

// MARK: - Traffic Light Close Button

struct TrafficLightClose: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.35, blue: 0.30),
                                Color(red: 0.95, green: 0.20, blue: 0.15),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 14, height: 14)

                Circle()
                    .strokeBorder(Color(red: 0.80, green: 0.12, blue: 0.10).opacity(0.6), lineWidth: 0.5)
                    .frame(width: 14, height: 14)

                if isHovered {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .heavy))
                        .foregroundColor(Color(red: 0.35, green: 0.05, blue: 0.02).opacity(0.85))
                } else {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.05, blue: 0.02).opacity(0.4))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.10)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Notification View

struct NotificationView: View {
    let runtime: String
    let projectName: String
    let editor: Editor
    let isPermission: Bool
    let onOpen: () -> Void
    let onDismiss: () -> Void
    let dismissTimeout: Double

    @State private var appeared = false

    private var theme: ColorTheme { Settings.shared.colorTheme }
    private var size: NotificationSize { Settings.shared.notificationSize }
    private var design: ResolvedDesign { Settings.shared.resolvedDesign }

    private var indicatorColor: Color {
        isPermission ? design.statusPermission : design.statusComplete
    }

    private var statusIcon: String {
        isPermission ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var statusLabel: String {
        let text = isPermission ? "Needs Permission" : "Complete"
        return design.uppercaseStatus ? text.uppercased() : text
    }

    private var subtitle: String {
        isPermission ? "Waiting for your approval" : "Ready for your input"
    }

    private var textPrimary: Color { design.textPrimary }
    private var textSecondary: Color { design.textSecondary }
    private var textTertiary: Color { design.textTertiary }

    @ViewBuilder
    private var notificationBackground: some View {
        let cr = CGFloat(Settings.shared.cornerRadius)
        let bgOpacity = Settings.shared.panelOpacity
        let d = design

        // For glass/vibrancy: the NSVisualEffectView is at the PANEL level
        // (as panel.contentView). The SwiftUI background only draws tint/specular/border
        // overlays on top of the real blur. No VibrancyView here.
        //
        // For opaque themes: no panel-level blur, so SwiftUI draws the full surface.
        //
        // bgOpacity is handled at the panel level (visualEffect.alphaValue) for
        // glass/vibrancy. For opaque themes it's applied here.

        if d.isGlass || d.useVibrancy {
            // ── Glass / Vibrancy: shiny 3D emboss border all around ──
            ZStack {
                // Bright highlight border — visible shine all around, strongest at top
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),   // Bright shine at top
                                Color.white.opacity(0.40),   // Visible on sides
                                Color.white.opacity(0.25),   // Still visible at bottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
                // Subtle outer shadow — just enough depth at the bottom
                RoundedRectangle(cornerRadius: cr + 0.5, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.10),
                                Color.black.opacity(0.20),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .padding(-0.5)
            }
        } else {
            // ── Opaque custom theme surface ──
            ZStack {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(d.surface)

                // Overlay gradient
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: d.overlayGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Border
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: d.borderGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: d.borderWidth
                    )
            }
            .opacity(bgOpacity)
        }
    }

    @ViewBuilder
    private var notificationButtons: some View {
        let s = size
        let d = design
        let isCustomLook = theme.isCustom || d.isGlass
        if d.isGlass || (d.useVibrancy && theme == .system) {
            // Glass buttons — 3D layered look with highlights and shadows
            let r = s.buttonRadius
            let btnPad = s.buttonPadding * 1.2  // 20% taller for glass
            HStack(spacing: s.elementSpacing * 2) {
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: s.buttonFontSize, weight: .semibold, design: d.fontDesign))
                        .foregroundColor(d.secondaryButtonText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, btnPad)
                        .background(
                            ZStack {
                                // Base fill
                                RoundedRectangle(cornerRadius: r, style: .continuous)
                                    .fill(d.secondaryButtonBg)
                                // Top highlight for 3D lift
                                RoundedRectangle(cornerRadius: r, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color.white.opacity(0.25), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    ))
                                // Bottom inner shadow
                                RoundedRectangle(cornerRadius: r, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(0.08)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    ))
                                // 3D border: light top, dark bottom
                                RoundedRectangle(cornerRadius: r, style: .continuous)
                                    .strokeBorder(LinearGradient(
                                        colors: [Color.white.opacity(0.50), d.secondaryButtonBorder, Color.black.opacity(0.10)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ), lineWidth: 0.75)
                            }
                        )
                }
                .buttonStyle(.plain)

                Button(action: onOpen) {
                    Text("Open in \(editor.displayName)")
                        .font(.system(size: s.buttonFontSize, weight: .semibold, design: d.fontDesign))
                        .foregroundColor(d.accentText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, btnPad)
                        .background(
                            ZStack {
                                // Base gradient
                                RoundedRectangle(cornerRadius: r, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: d.primaryButtonBg,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                // Top highlight for 3D lift
                                RoundedRectangle(cornerRadius: r, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color.white.opacity(0.30), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    ))
                                // Bottom darken for depth
                                RoundedRectangle(cornerRadius: r, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(0.12)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    ))
                                // 3D border
                                RoundedRectangle(cornerRadius: r, style: .continuous)
                                    .strokeBorder(LinearGradient(
                                        colors: [Color.white.opacity(0.35), Color.clear, Color.black.opacity(0.15)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ), lineWidth: 0.75)
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        } else if isCustomLook {
            HStack(spacing: s.elementSpacing * 2) {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(ThemeSecondaryButtonStyle(fontSize: s.buttonFontSize, padding: s.buttonPadding, radius: s.buttonRadius, theme: theme))
                Button("Open in \(editor.displayName)", action: onOpen)
                    .buttonStyle(ThemePrimaryButtonStyle(fontSize: s.buttonFontSize, padding: s.buttonPadding, radius: s.buttonRadius, theme: theme))
            }
        } else {
            HStack(spacing: s.elementSpacing * 2) {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(SecondaryButtonStyle(fontSize: s.buttonFontSize, padding: s.buttonPadding, radius: s.buttonRadius))
                Button("Open in \(editor.displayName)", action: onOpen)
                    .buttonStyle(PrimaryButtonStyle(fontSize: s.buttonFontSize, padding: s.buttonPadding, radius: s.buttonRadius))
            }
        }
    }

    var body: some View {
        let d = design
        let fontDesign = d.fontDesign
        let timerHeight: CGFloat = (theme.isCustom || d.isGlass) ? 3 : 2
        let isCustomLook = theme.isCustom || d.isGlass

        ZStack(alignment: .topTrailing) {
        HStack(alignment: .top, spacing: 0) {
            // Left status indicator
            StatusIndicator(color: indicatorColor, width: size.indicatorWidth, theme: theme)
                .padding(.top, size.outerPadding)
                .padding(.bottom, size.outerPadding)
                .padding(.leading, size.innerPadding)

            // Main content column
            VStack(alignment: .leading, spacing: size.elementSpacing) {
                // ── Header row: app icon + status + runtime ──
                HStack(spacing: size.elementSpacing + 2) {
                    // App icon — real .icns from installed app, or SF Symbol fallback
                    if let appIcon = AppIconResolver.shared.icon(for: editor) {
                        AppIconImage(appIcon, size: size.appIconSize)
                    } else {
                        Image(systemName: editor.iconName)
                            .font(.system(size: size.smallIconSize, weight: .medium))
                            .foregroundColor(textTertiary)
                    }

                    Image(systemName: statusIcon)
                        .font(.system(size: size.iconSize))
                        .foregroundColor(indicatorColor)

                    Text(runtime)
                        .font(.system(size: size.headerFont, weight: isCustomLook ? d.headerWeight : .semibold, design: fontDesign))
                        .tracking(isCustomLook ? d.headerTracking : 0)
                        .foregroundColor(textPrimary)

                    Text(statusLabel)
                        .font(.system(size: size.bodyFont, weight: isCustomLook ? d.bodyWeight : .regular, design: fontDesign))
                        .foregroundColor(textSecondary)

                    Spacer()
                }
                .padding(.top, size.outerPadding)
                .padding(.trailing, 26)

                // ── Project info ──
                HStack(spacing: size.elementSpacing) {
                    Text(projectName)
                        .font(.system(size: size.bodyFont, weight: .medium, design: fontDesign))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)

                    Text("in \(editor.displayName)")
                        .font(.system(size: size.captionFont, design: fontDesign))
                        .foregroundColor(textTertiary)
                }

                // Subtitle
                Text(subtitle)
                    .font(.system(size: size.captionFont, design: fontDesign))
                    .foregroundColor(textSecondary)

                Spacer(minLength: size.elementSpacing)

                // ── Buttons ──
                notificationButtons
                    .padding(.bottom, dismissTimeout > 0 ? size.elementSpacing + 2 : size.outerPadding)

                // ── Timer ──
                if dismissTimeout > 0 {
                    TimerBar(totalDuration: dismissTimeout, theme: theme, barHeight: timerHeight)
                        .padding(.bottom, size.innerPadding)
                }
            }
            .padding(.leading, size.innerPadding)
            .padding(.trailing, size.outerPadding)
        } // end HStack

            // Close button — 4pt from top-right corner
            TrafficLightClose(action: onDismiss)
                .padding(.top, 4)
                .padding(.trailing, 4)
        } // end ZStack
        .frame(width: size.contentWidth)
        .background { notificationBackground }
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(Settings.shared.cornerRadius), style: .continuous))
        .scaleEffect(appeared ? 1.0 : (Settings.shared.animationStyle == .none ? 1.0 : 0.90))
        .opacity(appeared ? 1.0 : (Settings.shared.animationStyle == .none ? 1.0 : 0))
        .offset(x: appeared ? 0 : (Settings.shared.animationStyle == .slide ? 30 : 0))
        .onAppear {
            if Settings.shared.animationStyle == .none {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - Preview Notification View

struct PreviewNotificationView: View {
    let contentWidth: CGFloat
    let cornerRadius: CGFloat
    let opacity: Double
    var theme: ColorTheme = .system
    var variant: DesignVariant = .dark
    var appearanceMode: AppearanceMode = .system

    private let previewEditor = Editor.terminal
    private var design: ResolvedDesign { theme.resolve(variant: variant, effectiveAppearance: appearanceMode) }

    private var indicatorColor: Color { design.statusComplete }
    private var textPrimary: Color { design.textPrimary }
    private var textSecondary: Color { design.textSecondary }
    private var textTertiary: Color { design.textTertiary }

    var body: some View {
        let d = design
        let fd = d.fontDesign
        let statusText = d.uppercaseStatus ? "COMPLETE" : "Complete"

        ZStack(alignment: .topTrailing) {
        HStack(alignment: .top, spacing: 0) {
            StatusIndicator(color: indicatorColor, width: 4, theme: theme)
                .padding(.top, 10).padding(.bottom, 10).padding(.leading, 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(indicatorColor)
                    Text("Claude")
                        .font(.system(size: 13, weight: d.headerWeight, design: fd))
                        .tracking(d.headerTracking)
                        .foregroundColor(textPrimary)
                    Text(statusText)
                        .font(.system(size: 12, weight: d.bodyWeight, design: fd))
                        .foregroundColor(textSecondary)
                    Spacer()
                }
                .padding(.top, 10).padding(.trailing, 26)

                HStack(spacing: 4) {
                    Image(systemName: previewEditor.iconName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(textTertiary)
                    Text("My Project")
                        .font(.system(size: 12, weight: .medium, design: fd))
                        .foregroundColor(textPrimary)
                    Text("in \(previewEditor.displayName)")
                        .font(.system(size: 11, design: fd))
                        .foregroundColor(textTertiary)
                }

                Text("Ready for your input")
                    .font(.system(size: 11, design: fd))
                    .foregroundColor(textSecondary)

                Spacer(minLength: 4)

                previewButtons
                    .padding(.bottom, 10)
            }
            .padding(.leading, 8).padding(.trailing, 10)
        }

            // Close button
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.40, blue: 0.35), Color(red: 1.0, green: 0.27, blue: 0.23)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 14, height: 14)
                Circle()
                    .strokeBorder(Color(red: 0.87, green: 0.19, blue: 0.17).opacity(0.5), lineWidth: 0.5)
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(Color(red: 0.35, green: 0.05, blue: 0.02).opacity(0.4))
                    .frame(width: 4, height: 4)
            }
            .padding(.top, 4).padding(.trailing, 4)
        }
        .frame(width: contentWidth)
        .background { previewBackground }
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(cornerRadius), style: .continuous))
        .scaleEffect(0.65)
        .frame(height: 120)
        .clipped()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var previewButtons: some View {
        let r: CGFloat = 6
        let d = design
        let fd = d.fontDesign
        let isCustomLook = theme.isCustom || d.isGlass
        if isCustomLook {
            HStack(spacing: 8) {
                Text("Dismiss")
                    .font(.system(size: 13, weight: d.bodyWeight, design: fd))
                    .foregroundColor(d.secondaryButtonText)
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(ZStack {
                        RoundedRectangle(cornerRadius: r, style: .continuous).fill(d.secondaryButtonBg)
                        RoundedRectangle(cornerRadius: r, style: .continuous).strokeBorder(d.secondaryButtonBorder, lineWidth: d.borderWidth)
                    })
                Text("Open in \(previewEditor.displayName)")
                    .font(.system(size: 13, weight: d.buttonWeight, design: fd))
                    .foregroundColor(d.accentText)
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(LinearGradient(colors: d.primaryButtonBg, startPoint: .leading, endPoint: .trailing))
                    )
            }
        } else {
            HStack(spacing: 8) {
                Text("Dismiss")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(ZStack {
                        RoundedRectangle(cornerRadius: r, style: .continuous).fill(Color.controlBg)
                        RoundedRectangle(cornerRadius: r, style: .continuous).strokeBorder(Color.controlBorder.opacity(0.5), lineWidth: 0.5)
                    })
                Text("Open in \(previewEditor.displayName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: r, style: .continuous).fill(Color.accentColor))
            }
        }
    }

    @ViewBuilder
    private var previewBackground: some View {
        let cr = CGFloat(cornerRadius)
        let d = design
        if d.isGlass {
            ZStack {
                VibrancyView(material: d.vibrancyMaterial, blendingMode: .behindWindow, cornerRadius: cr)
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(d.surface.opacity(d.surfaceOpacity * opacity))
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(d.glassTint.opacity(d.glassTintOpacity))
                // Specular highlight
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color.white.opacity(d.glassRefractionStrength),
                            Color.white.opacity(d.glassRefractionStrength * 0.35),
                            Color.white.opacity(d.glassRefractionStrength * 0.08),
                            Color.clear
                        ],
                        startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.30)
                    ))
                // Accent glow
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(RadialGradient(
                        colors: [d.accent.opacity(0.06), Color.clear],
                        center: .topLeading, startRadius: 0, endRadius: 180
                    ))
                // Inner shadow
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.clear, Color.clear, Color.black.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ))
                // Edge border
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: d.borderGradient,
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: d.borderWidth)
            }
        } else if d.useVibrancy {
            ZStack {
                VibrancyView(material: d.vibrancyMaterial, blendingMode: .behindWindow, cornerRadius: cr)
                    .opacity(1.0 - opacity * 0.7)
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(d.surface.opacity(opacity))
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.20 * (1.0 - opacity * 0.5)), Color.white.opacity(0.06), .clear],
                        startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45)
                    ))
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: d.borderGradient,
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: d.borderWidth)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(d.surface.opacity(max(opacity, 0.7)))
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(LinearGradient(
                        colors: d.overlayGradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: d.borderGradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: d.borderWidth)
            }
        }
    }
}

// MARK: - Sound List Picker (arrow-key navigable)

struct SoundListPicker: NSViewRepresentable {
    @Binding var selection: String
    let sounds: [String]

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.style = .plain
        tableView.rowHeight = 22
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.usesAlternatingRowBackgroundColors = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sound"))
        column.title = ""
        tableView.addTableColumn(column)

        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        // Select current sound
        if let idx = sounds.firstIndex(of: selection) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        context.coordinator.sounds = sounds
        context.coordinator.selection = $selection
        if let idx = sounds.firstIndex(of: selection), tableView.selectedRow != idx {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            tableView.scrollRowToVisible(idx)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sounds: sounds, selection: $selection)
    }

    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var sounds: [String]
        var selection: Binding<String>

        init(sounds: [String], selection: Binding<String>) {
            self.sounds = sounds
            self.selection = selection
        }

        func numberOfRows(in tableView: NSTableView) -> Int { sounds.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let sound = sounds[row]
            let cell = NSTextField(labelWithString: sound)
            cell.font = NSFont.systemFont(ofSize: 13)
            cell.lineBreakMode = .byTruncatingTail
            let container = NSView()
            container.addSubview(cell)
            cell.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cell.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
                cell.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            return container
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView else { return }
            let row = tableView.selectedRow
            guard row >= 0, row < sounds.count else { return }
            selection.wrappedValue = sounds[row]
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var selectedTab: String
    init(initialTab: String = "general") { _selectedTab = State(initialValue: initialTab) }

    // General
    @State private var popupEnabled: Bool = Settings.shared.popupEnabled
    @State private var focusedPopup: Bool = Settings.shared.focusedPopup
    @State private var focusedSound: Bool = Settings.shared.focusedSound
    @State private var focusedSoundVolume: Float = Settings.shared.focusedSoundVolume
    @State private var screenPosition: ScreenPosition = Settings.shared.screenPosition
    @State private var displayTarget: DisplayTarget = Settings.shared.displayTarget

    // Appearance
    @State private var notificationSize: NotificationSize = Settings.shared.notificationSize
    @State private var cornerRadius: Double = Settings.shared.cornerRadius
    @State private var panelOpacity: Double = Settings.shared.panelOpacity
    @State private var appearanceMode: AppearanceMode = Settings.shared.appearanceMode
    @State private var colorTheme: ColorTheme = Settings.shared.colorTheme
    @State private var designVariant: DesignVariant = Settings.shared.designVariant

    // Sounds
    @State private var soundEnabled: Bool = Settings.shared.soundEnabled
    @State private var completionSound: String = Settings.shared.completionSound
    @State private var permissionSound: String = Settings.shared.permissionSound
    @State private var soundVolume: Float = Settings.shared.soundVolume

    // Timing
    @State private var dismissTimeout: Double = Settings.shared.dismissTimeout
    @State private var animationStyle: AnimationStyle = Settings.shared.animationStyle

    // Do Not Disturb
    @State private var dndEnabled: Bool = Settings.shared.dndEnabled
    @State private var dndStartTime: Date = {
        var c = DateComponents()
        c.hour = Settings.shared.dndStartHour
        c.minute = Settings.shared.dndStartMinute
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var dndEndTime: Date = {
        var c = DateComponents()
        c.hour = Settings.shared.dndEndHour
        c.minute = Settings.shared.dndEndMinute
        return Calendar.current.date(from: c) ?? Date()
    }()

    private let sounds = Settings.availableSounds

    private let timeoutOptions: [(String, Double)] = [
        ("5 seconds", 5),
        ("10 seconds", 10),
        ("15 seconds", 15),
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("Never", 0),
    ]

    private func sendTestNotification() {
        let binaryPath = DevPingPaths.notificationBinary
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["--notify", "Claude", "Test Project", "/tmp", "Terminal", "/dev/ttys000", ""]
        try? proc.run()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("General", systemImage: "bell.badge") }
                .tag("general")

            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
                .tag("appearance")

            soundsTab
                .tabItem { Label("Sounds", systemImage: "speaker.wave.2") }
                .tag("sounds")

            timingTab
                .tabItem { Label("Timing", systemImage: "clock") }
                .tag("timing")

            aboutTab
                .tabItem { Label("About", systemImage: "person.circle") }
                .tag("about")
        }
        .frame(width: 540, height: 500)
        .preferredColorScheme(
            appearanceMode == .light ? .light :
            appearanceMode == .dark ? .dark :
            nil
        )
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Show popup notifications", isOn: $popupEnabled)
                    .toggleStyle(.switch)
                    .tint(.accentColor)
                    .onChange(of: popupEnabled) { _, val in
                        Settings.shared.popupEnabled = val
                    }
            } header: {
                Text("Behavior")
            }

            Section {
                Toggle("Show popup when editor is focused", isOn: $focusedPopup)
                    .toggleStyle(.switch)
                    .tint(.accentColor)
                    .onChange(of: focusedPopup) { _, val in
                        Settings.shared.focusedPopup = val
                    }

                Toggle("Play sound when editor is focused", isOn: $focusedSound)
                    .toggleStyle(.switch)
                    .tint(.accentColor)
                    .onChange(of: focusedSound) { _, val in
                        Settings.shared.focusedSound = val
                    }

                if focusedSound {
                    HStack {
                        Text("Focused volume")
                        Slider(value: $focusedSoundVolume, in: 0.0...1.0, step: 0.05)
                        Text("\(Int(focusedSoundVolume * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 38, alignment: .trailing)
                    }
                    .onChange(of: focusedSoundVolume) { _, val in
                        Settings.shared.focusedSoundVolume = val
                    }
                }
            } header: {
                Text("When Editor is Active")
            } footer: {
                Text("Controls what happens when the editor running Claude is the frontmost app. Defaults to quiet mode (sound at 50%, no popup).")
                    .foregroundStyle(.tertiary)
            }

            Section {
                Picker("Position:", selection: $screenPosition) {
                    ForEach(ScreenPosition.allCases) { pos in
                        Text(pos.label).tag(pos)
                    }
                }
                .onChange(of: screenPosition) { _, val in
                    Settings.shared.screenPosition = val
                }

                Picker("Show on:", selection: $displayTarget) {
                    ForEach(DisplayTarget.allCases) { target in
                        Text(target.label).tag(target)
                    }
                }
                .onChange(of: displayTarget) { _, val in
                    Settings.shared.displayTarget = val
                }
            } header: {
                Text("Placement")
            }

            Section {
                Toggle("Enable quiet hours", isOn: $dndEnabled)
                    .toggleStyle(.switch)
                    .tint(.accentColor)
                    .onChange(of: dndEnabled) { _, val in
                        Settings.shared.dndEnabled = val
                    }

                if dndEnabled {
                    DatePicker("Start:", selection: $dndStartTime, displayedComponents: .hourAndMinute)
                        .onChange(of: dndStartTime) { _, val in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: val)
                            Settings.shared.dndStartHour = comps.hour ?? 22
                            Settings.shared.dndStartMinute = comps.minute ?? 0
                        }

                    DatePicker("End:", selection: $dndEndTime, displayedComponents: .hourAndMinute)
                        .onChange(of: dndEndTime) { _, val in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: val)
                            Settings.shared.dndEndHour = comps.hour ?? 8
                            Settings.shared.dndEndMinute = comps.minute ?? 0
                        }
                }
            } header: {
                Text("Do Not Disturb")
            } footer: {
                Text("Suppresses both sound and popup during quiet hours.")
                    .foregroundStyle(.tertiary)
            }

            Section {
                Button("Send Test Notification", action: sendTestNotification)
                    .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        Form {
            Section {
                Picker("Color Theme:", selection: $colorTheme) {
                    ForEach(ColorTheme.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .onChange(of: colorTheme) { _, val in
                    Settings.shared.colorTheme = val
                }

                // Design variant: Light / Dark / Glass
                Picker("Variant:", selection: $designVariant) {
                    ForEach(DesignVariant.allCases) { v in
                        Label(v.label, systemImage: v.iconName).tag(v)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: designVariant) { _, val in
                    Settings.shared.designVariant = val
                }
            } header: {
                Text("Color Theme")
            }

            Section {
                PreviewNotificationView(
                    contentWidth: notificationSize.contentWidth,
                    cornerRadius: cornerRadius,
                    opacity: panelOpacity,
                    theme: colorTheme,
                    variant: designVariant,
                    appearanceMode: appearanceMode
                )
            } header: {
                Text("Preview")
            }

            Section {
                Picker("Appearance:", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appearanceMode) { _, val in
                    Settings.shared.appearanceMode = val
                }

                Picker("Size:", selection: $notificationSize) {
                    ForEach(NotificationSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: notificationSize) { _, val in
                    Settings.shared.notificationSize = val
                }
            } header: {
                Text("Style")
            }

            Section {
                HStack {
                    Text("Opacity")
                    Slider(value: $panelOpacity, in: 0.1...1.0, step: 0.05)
                    Text("\(Int(panelOpacity * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }
                .onChange(of: panelOpacity) { _, val in
                    Settings.shared.panelOpacity = val
                }

                HStack {
                    Text("Corner Radius")
                    Slider(value: $cornerRadius, in: 0...24, step: 2)
                    Text("\(Int(cornerRadius))pt")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }
                .onChange(of: cornerRadius) { _, val in
                    Settings.shared.cornerRadius = val
                }
            } header: {
                Text("Fine-Tuning")
            }

            Section {
                Button("Send Test Notification", action: sendTestNotification)
                    .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Sounds Tab

    private var soundsTab: some View {
        Form {
            Section {
                Toggle("Play sounds", isOn: $soundEnabled)
                    .toggleStyle(.switch)
                    .tint(.accentColor)
                    .onChange(of: soundEnabled) { _, val in
                        Settings.shared.soundEnabled = val
                    }

                if soundEnabled {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                        Slider(value: $soundVolume, in: 0.0...1.0, step: 0.05)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .onChange(of: soundVolume) { _, val in
                        Settings.shared.soundVolume = val
                    }
                }
            } header: {
                Text("Volume")
            }

            if soundEnabled {
                Section {
                    SoundListPicker(selection: $completionSound, sounds: sounds)
                        .frame(height: 100)
                        .onChange(of: completionSound) { _, val in
                            Settings.shared.completionSound = val
                            previewSound(val)
                        }
                } header: {
                    Text("Task Complete Sound")
                }

                Section {
                    SoundListPicker(selection: $permissionSound, sounds: sounds)
                        .frame(height: 100)
                        .onChange(of: permissionSound) { _, val in
                            Settings.shared.permissionSound = val
                            previewSound(val)
                        }
                } header: {
                    Text("Needs Input Sound")
                } footer: {
                    Text("Click a sound or use arrow keys to browse. Each selection plays a preview.")
                        .foregroundStyle(.tertiary)
                }
            }

            Section {
                Button("Send Test Notification", action: sendTestNotification)
                    .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Timing Tab

    private var timingTab: some View {
        Form {
            Section {
                Picker("Auto-dismiss:", selection: $dismissTimeout) {
                    ForEach(timeoutOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                .onChange(of: dismissTimeout) { _, val in
                    Settings.shared.dismissTimeout = val
                }
            } header: {
                Text("Duration")
            } footer: {
                Text("How long the notification stays visible before automatically closing. \"Never\" keeps it until manually dismissed.")
                    .foregroundStyle(.tertiary)
            }

            Section {
                Picker("Animation:", selection: $animationStyle) {
                    ForEach(AnimationStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: animationStyle) { _, val in
                    Settings.shared.animationStyle = val
                }
            } header: {
                Text("Entrance")
            }

            Section {
                Button("Send Test Notification", action: sendTestNotification)
                    .buttonStyle(.bordered)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset All Settings to Defaults") {
                        Settings.shared.resetToDefaults()
                        // Reload all state
                        popupEnabled = Settings.shared.popupEnabled
                        focusedPopup = Settings.shared.focusedPopup
                        focusedSound = Settings.shared.focusedSound
                        focusedSoundVolume = Settings.shared.focusedSoundVolume
                        screenPosition = Settings.shared.screenPosition
                        displayTarget = Settings.shared.displayTarget
                        notificationSize = Settings.shared.notificationSize
                        cornerRadius = Settings.shared.cornerRadius
                        panelOpacity = Settings.shared.panelOpacity
                        appearanceMode = Settings.shared.appearanceMode
                        colorTheme = Settings.shared.colorTheme
                        designVariant = Settings.shared.designVariant
                        soundEnabled = Settings.shared.soundEnabled
                        completionSound = Settings.shared.completionSound
                        permissionSound = Settings.shared.permissionSound
                        soundVolume = Settings.shared.soundVolume
                        dismissTimeout = Settings.shared.dismissTimeout
                        animationStyle = Settings.shared.animationStyle
                        dndEnabled = Settings.shared.dndEnabled
                        var sc = DateComponents()
                        sc.hour = Settings.shared.dndStartHour
                        sc.minute = Settings.shared.dndStartMinute
                        dndStartTime = Calendar.current.date(from: sc) ?? Date()
                        var ec = DateComponents()
                        ec.hour = Settings.shared.dndEndHour
                        ec.minute = Settings.shared.dndEndMinute
                        dndEndTime = Calendar.current.date(from: ec) ?? Date()
                    }
                    .foregroundStyle(.red)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 24) {

                // App identity
                VStack(spacing: 10) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 80, height: 80)
                    }
                    Text("DevPing")
                        .font(.system(size: 22, weight: .bold))
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
                    let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
                    Text("Version \(version) (Build \(build))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Copyright © 2025 Andrew Naegele. All rights reserved.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                Divider()

                // Social links grid
                VStack(spacing: 8) {
                    Text("Connect")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        AboutSocialButton(label: "X / Twitter",   systemImage: "at",                 url: "https://x.com/andrewnaegele")
                        AboutSocialButton(label: "Instagram",     systemImage: "camera",             url: "https://instagram.com/andrew.naegele")
                        AboutSocialButton(label: "Facebook",      systemImage: "person.2",           url: "https://facebook.com/andrewnaegele")
                        AboutSocialButton(label: "LinkedIn",      systemImage: "briefcase",          url: "https://linkedin.com/in/andrewnaegele")
                        AboutSocialButton(label: "AI Simple",     systemImage: "wand.and.stars",     url: "https://aisimple.co")
                        AboutSocialButton(label: "GitHub",        systemImage: "chevron.left.forwardslash.chevron.right", url: "https://github.com/Vibe-Marketer/devping")
                        AboutSocialButton(label: "Skool",         systemImage: "person.3",           url: "https://skool.com/vibe-marketing")
                        AboutSocialButton(label: "YouTube",       systemImage: "play.rectangle",     url: nil, comingSoon: true)
                        AboutSocialButton(label: "TikTok",        systemImage: "music.note",         url: nil, comingSoon: true)
                    }
                }
                .padding(.horizontal, 20)

                Divider()

                // Share button
                Button {
                    let picker = NSSharingServicePicker(items: [
                        "Check out DevPing — frosted-glass notifications for AI coding assistants! 🔔",
                        URL(string: "https://github.com/Vibe-Marketer/devping")!
                    ])
                    if let button = NSApp.keyWindow?.contentView?.subviews.first {
                        picker.show(relativeTo: .zero, of: button, preferredEdge: .minY)
                    }
                } label: {
                    Label("Share DevPing", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper view for social link buttons in About tab
private struct AboutSocialButton: View {
    let label: String
    let systemImage: String
    let url: String?
    var comingSoon: Bool = false

    var body: some View {
        Button {
            guard let urlString = url, let u = URL(string: urlString) else { return }
            NSWorkspace.shared.open(u)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(comingSoon ? .tertiary : .primary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(comingSoon ? .tertiary : .primary)
                if comingSoon {
                    Text("Soon")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .disabled(comingSoon)
    }
}

// MARK: - Hook Installer

enum AITool: String, CaseIterable, Identifiable {
    case claudeCode = "claudeCode"
    case openCode   = "openCode"
    case aider      = "aider"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .openCode:   return "OpenCode"
        case .aider:      return "Aider"
        }
    }

    var subtitle: String {
        switch self {
        case .claudeCode: return "Anthropic's official CLI"
        case .openCode:   return "Open source AI coding agent"
        case .aider:      return "AI pair programming in your terminal"
        }
    }

    var icon: String {
        switch self {
        case .claudeCode: return "c.circle.fill"
        case .openCode:   return "terminal.fill"
        case .aider:      return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Bundle identifier for real app icon lookup via NSWorkspace
    var bundleIdentifier: String? {
        switch self {
        case .claudeCode: return "com.anthropic.claudefordesktop"
        case .openCode:   return "ai.opencode.desktop"
        case .aider:      return nil
        }
    }

    /// Resolved app icon — real icon if available, nil to fall back to SF Symbol
    var appIcon: NSImage? {
        guard let bundleID = bundleIdentifier else { return nil }
        // Try bundle ID first
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        // Fallback: search /Applications by known app name
        let appNames: [String]
        switch self {
        case .claudeCode: appNames = ["Claude"]
        case .openCode:   appNames = ["OpenCode"]
        default:          appNames = []
        }
        for name in appNames {
            let path = "/Applications/\(name).app"
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        return nil
    }

    /// True if the tool appears to be installed on this machine
    var isInstalled: Bool {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        switch self {
        case .claudeCode:
            return fm.fileExists(atPath: (home as NSString).appendingPathComponent(".claude"))
                || fm.fileExists(atPath: "/opt/homebrew/bin/claude")
                || fm.fileExists(atPath: "/usr/local/bin/claude")
        case .openCode:
            return fm.fileExists(atPath: (home as NSString).appendingPathComponent(".config/opencode"))
                || fm.fileExists(atPath: "/opt/homebrew/bin/opencode")
                || fm.fileExists(atPath: "/usr/local/bin/opencode")
        case .aider:
            return fm.fileExists(atPath: "/opt/homebrew/bin/aider")
                || fm.fileExists(atPath: "/usr/local/bin/aider")
                || fm.fileExists(atPath: (home as NSString).appendingPathComponent(".local/bin/aider"))
                || fm.fileExists(atPath: (home as NSString).appendingPathComponent(".aider.conf.yml"))
        }
    }

    var settingsPath: String {
        let home = NSHomeDirectory()
        switch self {
        case .claudeCode: return "\(home)/.claude/settings.json"
        case .openCode:   return "\(home)/.config/opencode/settings.json"
        case .aider:      return "\(home)/.aider.conf.yml"
        }
    }
}

/// Editors that are auto-detected at notification time — no config needed.
/// Used to show the "already supported" info section in onboarding.
struct DetectedEditor: Identifiable {
    let id: String
    let label: String
    let icon: String
    var isInstalled: Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
    }
}

let autoDetectedEditors: [DetectedEditor] = [
    DetectedEditor(id: "com.todesktop.230313mzl4w4u92", label: "Cursor",            icon: "cursorarrow"),
    DetectedEditor(id: "com.microsoft.VSCode",           label: "VS Code",           icon: "chevron.left.forwardslash.chevron.right"),
    DetectedEditor(id: "dev.zed.Zed",                    label: "Zed",               icon: "bolt"),
    DetectedEditor(id: "com.codeium.windsurf",           label: "Windsurf",          icon: "wind"),
    DetectedEditor(id: "com.mitchellh.ghostty",          label: "Ghostty",           icon: "terminal"),
    DetectedEditor(id: "com.googlecode.iterm2",          label: "iTerm2",            icon: "terminal"),
    DetectedEditor(id: "com.apple.Terminal",             label: "Terminal",          icon: "terminal"),
    DetectedEditor(id: "dev.warp.Warp-Stable",           label: "Warp",              icon: "terminal"),
    DetectedEditor(id: "com.sublimetext.4",              label: "Sublime Text",      icon: "text.cursor"),
]

final class HookInstaller {
    static let shared = HookInstaller()

    private let hookDir: String = {
        let home = NSHomeDirectory()
        return "\(home)/.config/devping/hooks"
    }()

    private let hookScriptPath: String = {
        let home = NSHomeDirectory()
        return "\(home)/.config/devping/hooks/notify.sh"
    }()

    /// Install the devping notification hook for one or more tools.
    /// Returns a result string suitable for display.
    func install(for tools: [AITool]) -> (success: Bool, message: String) {
        do {
            try writeHookScript()
            var installed: [String] = []
            var errors: [String] = []
            for tool in tools {
                do {
                    try patchSettings(for: tool)
                    installed.append(tool.label)
                } catch {
                    errors.append("\(tool.label): \(error.localizedDescription)")
                }
            }
            if errors.isEmpty {
                return (true, "Hooks installed for: \(installed.joined(separator: ", "))")
            } else {
                return (false, "Partial install. Errors:\n\(errors.joined(separator: "\n"))")
            }
        } catch {
            return (false, "Failed to write hook script: \(error.localizedDescription)")
        }
    }

    /// Check if a tool already has devping hooks installed
    func isInstalled(for tool: AITool) -> Bool {
        guard let data = FileManager.default.contents(atPath: tool.settingsPath),
              let content = String(data: data, encoding: .utf8) else { return false }
        return content.contains("devping") || content.contains("notify.sh")
    }

    // ── Private ──

    private func writeHookScript() throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: hookDir, withIntermediateDirectories: true)

        let script = """
        #!/bin/bash
        # DevPing notification hook
        # Auto-installed by DevPing — https://github.com/Vibe-Marketer/devping

        MODE="${1:-}"  # "permission" or empty for completion

        # Read hook input from stdin
        INPUT=$(cat)
        HOOK_CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
        CWD="${HOOK_CWD:-$(pwd)}"
        PROJECT_NAME=$(basename "$CWD")

        # Detect runtime
        RUNTIME="Claude"
        if echo "$0" | grep -qi "opencode"; then
            RUNTIME="OpenCode"
        fi

        # Detect TTY
        TTY_DEVICE=""
        PARENT_TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
        if [ -n "$PARENT_TTY" ] && [ "$PARENT_TTY" != "??" ]; then
            TTY_DEVICE="/dev/$PARENT_TTY"
        fi

        # Detect editor
        EDITOR_NAME=""
        if [ -d "$HOME/.claude/ide" ]; then
            for lockfile in "$HOME/.claude/ide"/*.lock; do
                [ -f "$lockfile" ] || continue
                IDE_NAME=$(python3 -c "
        import sys, json
        try:
            data = json.load(open('$lockfile'))
            folders = data.get('workspaceFolders', [])
            ide = data.get('ideName', '')
            cwd = '$CWD'
            for f in folders:
                if cwd.startswith(f) or f.startswith(cwd):
                    print(ide)
                    sys.exit(0)
        except:
            pass
        " 2>/dev/null)
                if [ -n "$IDE_NAME" ]; then
                    EDITOR_NAME="$IDE_NAME"
                    break
                fi
            done
        fi
        if [ -z "$EDITOR_NAME" ]; then
            CURRENT_PID=$$
            for _ in 1 2 3 4 5 6 7 8; do
                PARENT_PID=$(ps -o ppid= -p "$CURRENT_PID" 2>/dev/null | tr -d ' ')
                [ -z "$PARENT_PID" ] || [ "$PARENT_PID" = "1" ] || [ "$PARENT_PID" = "0" ] && break
                PARENT_NAME=$(ps -o comm= -p "$PARENT_PID" 2>/dev/null)
                case "$PARENT_NAME" in
                    *[Zz]ed*)           EDITOR_NAME="Zed"; break ;;
                    *[Cc]ursor*)        EDITOR_NAME="Cursor"; break ;;
                    *[Cc]ode*|*VSCode*) EDITOR_NAME="VSCode"; break ;;
                    *[Ww]indsurf*)      EDITOR_NAME="Windsurf"; break ;;
                    *Terminal*)         EDITOR_NAME="Terminal"; break ;;
                esac
                CURRENT_PID="$PARENT_PID"
            done
        fi
        if [ -z "$EDITOR_NAME" ]; then
            case "${TERM_PROGRAM:-}" in
                iTerm*|iTerm.app)  EDITOR_NAME="iTerm" ;;
                Apple_Terminal)    EDITOR_NAME="Terminal" ;;
                WezTerm)           EDITOR_NAME="WezTerm" ;;
                Alacritty)         EDITOR_NAME="Alacritty" ;;
                ghostty)           EDITOR_NAME="Ghostty" ;;
                vscode)            EDITOR_NAME="VSCode" ;;
            esac
        fi
        if [ -z "$EDITOR_NAME" ]; then
            EDITOR_NAME="Terminal"
        fi

        # Find devping binary
        DEVPING_BIN=""
        if command -v devping >/dev/null 2>&1; then
            DEVPING_BIN=$(command -v devping)
        elif [ -x "/opt/homebrew/bin/devping" ]; then
            DEVPING_BIN="/opt/homebrew/bin/devping"
        elif [ -x "$HOME/.local/bin/devping" ]; then
            DEVPING_BIN="$HOME/.local/bin/devping"
        fi

        if [ -n "$DEVPING_BIN" ]; then
            "$DEVPING_BIN" --notify "$RUNTIME" "$PROJECT_NAME" "$CWD" "$EDITOR_NAME" "${TTY_DEVICE:-none}" $MODE &
        fi
        """

        try script.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        // Make executable
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptPath)
    }

    private func patchSettings(for tool: AITool) throws {
        switch tool {
        case .aider:
            try patchAider()
        default:
            try patchJSON(for: tool)
        }
    }

    /// Patch Claude Code / OpenCode JSON settings
    private func patchJSON(for tool: AITool) throws {
        let fm = FileManager.default
        let path = tool.settingsPath

        let dir = (path as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        var root: [String: Any] = [:]
        if fm.fileExists(atPath: path),
           let data = fm.contents(atPath: path),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = parsed
        }

        let stopHook: [String: Any] = [
            "type": "command",
            "command": "bash \"\(hookScriptPath)\"",
            "timeout": 60
        ]
        let permissionHook: [String: Any] = [
            "type": "command",
            "command": "bash \"\(hookScriptPath)\" permission",
            "timeout": 60
        ]

        var hooks = root["hooks"] as? [String: Any] ?? [:]

        var stopArray = hooks["Stop"] as? [[String: Any]] ?? []
        let alreadyHasStop = stopArray.contains {
            ($0["command"] as? String)?.contains("devping") == true ||
            ($0["command"] as? String)?.contains("notify.sh") == true
        }
        if !alreadyHasStop {
            stopArray.append(["hooks": [stopHook]])
        }
        hooks["Stop"] = stopArray

        var notifArray = hooks["Notification"] as? [[String: Any]] ?? []
        let alreadyHasNotif = notifArray.contains { entry in
            if let innerHooks = entry["hooks"] as? [[String: Any]] {
                return innerHooks.contains {
                    ($0["command"] as? String)?.contains("devping") == true ||
                    ($0["command"] as? String)?.contains("notify.sh") == true
                }
            }
            return false
        }
        if !alreadyHasNotif {
            notifArray.append([
                "matcher": "permission_prompt",
                "hooks": [permissionHook]
            ])
        }
        hooks["Notification"] = notifArray
        root["hooks"] = hooks

        let output = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try output.write(to: URL(fileURLWithPath: tool.settingsPath))
    }

    /// Patch Aider's YAML config (~/.aider.conf.yml)
    private func patchAider() throws {
        let fm = FileManager.default
        let path = AITool.aider.settingsPath

        // Read existing YAML as plain text (avoid full YAML parser dependency)
        var lines: [String] = []
        if fm.fileExists(atPath: path),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            lines = content.components(separatedBy: "\n")
        }

        // Check if already configured
        let alreadyDone = lines.contains { $0.contains("notify.sh") || $0.contains("devping") }
        if alreadyDone { return }

        // Remove any existing notifications lines to avoid duplicates
        lines = lines.filter { !$0.hasPrefix("notifications:") && !$0.hasPrefix("notifications-command:") }

        // Append DevPing config
        if !lines.isEmpty && lines.last != "" { lines.append("") }
        lines.append("# DevPing notifications (auto-installed)")
        lines.append("notifications: true")
        lines.append("notifications-command: bash \"\(hookScriptPath)\"")
        lines.append("")

        let output = lines.joined(separator: "\n")
        try output.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

// MARK: - FlowLayout

/// Simple wrapping layout for badge pills (used in onboarding editor section)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Onboarding

/// Multi-step welcome window shown once on first launch.
struct WelcomeView: View {
    @State private var step: Int = 0
    @State private var testFired: Bool = false
    @State private var setupDone: Bool = false
    @State private var setupMessage: String = ""
    @State private var selectedTools: Set<AITool> = {
        // Pre-select whichever tools are detected as installed
        Set(AITool.allCases.filter { $0.isInstalled })
    }()
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: i == step ? 8 : 6, height: i == step ? 8 : 6)
                        .animation(.spring(response: 0.3), value: step)
                }
            }
            .padding(.top, 24)

            Spacer()

            // Step content
            switch step {
            case 0: stepWelcome
            case 1: stepMenuBar
            case 2: stepSetup
            case 3: stepFinish
            default: stepWelcome
            }

            Spacer()

            Divider()

            // Navigation bar
            HStack {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if step < totalSteps - 1 {
                    Button("Continue") { withAnimation { step += 1 } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                } else {
                    Button("Get Started") {
                        Settings.shared.hasCompletedOnboarding = true
                        onDismiss?()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(!testFired)
                    .help(testFired ? "" : "Send a test notification first")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 540, height: 580)
    }

    // ── Step 0: Welcome ──
    private var stepWelcome: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 4)
            Text("Welcome to DevPing")
                .font(.system(size: 22, weight: .bold))
            Text("DevPing lives in your menu bar and fires native macOS notifications whenever Claude Code, OpenCode, or any AI assistant finishes a task or needs your attention.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)
        }
    }

    // ── Step 1: Menu bar location ──
    private var stepMenuBar: some View {
        VStack(spacing: 12) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 4)
            Text("It's up there ↑")
                .font(.system(size: 22, weight: .bold))
            Text("Look for the ⚡ bolt icon in your menu bar at the top of your screen. Click it anytime to send a test notification, open Settings, or toggle launch-at-login.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)
        }
    }

    // ── Step 2: Interactive hook setup ──
    private var stepSetup: some View {
        VStack(spacing: 12) {
                Image(systemName: setupDone ? "checkmark.circle.fill" : "hook.sparkles")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(setupDone ? Color.green : Color.accentColor)

                Text("Connect to your AI tools")
                    .font(.system(size: 20, weight: .bold))

                Text("Select the AI agents you use and DevPing will install the hooks automatically — no terminal needed.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)

                // ── AI Agents (need hook install) ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI AGENTS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)

                    ForEach(AITool.allCases) { tool in
                        toolRow(tool)
                    }
                }
                .padding(.horizontal, 32)

                if setupDone {
                    Label(setupMessage, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                } else {
                    Button(action: runSetup) {
                        Label("Install Hooks", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(minWidth: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(selectedTools.isEmpty)
                }

                // ── Editors (auto-detected, no install needed) ──
                let installedEditors = autoDetectedEditors.filter { $0.isInstalled }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("EDITORS — AUTO-DETECTED")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 4)

                    if installedEditors.isEmpty {
                        Text("No supported editors detected. DevPing works with Cursor, VS Code, Zed, Windsurf, and more — the right logo and name will appear automatically in your notifications.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .padding(.horizontal, 4)
                    } else {
                        // Show detected editors as pill badges
                        FlowLayout(spacing: 6) {
                            ForEach(installedEditors) { editor in
                                HStack(spacing: 4) {
                                    Image(systemName: editor.icon)
                                        .font(.system(size: 10))
                                    Text(editor.label)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.12))
                                .foregroundStyle(Color.green)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 4)

                        Text("These are already supported — DevPing auto-detects which editor fired the notification and shows the correct name and icon. Nothing to configure.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .padding(.horizontal, 4)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
    }

    private func toolRow(_ tool: AITool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selectedTools.contains(tool) ? "checkmark.square.fill" : "square")
                .foregroundStyle(selectedTools.contains(tool) ? Color.accentColor : Color.secondary)
                .font(.system(size: 18))
                .onTapGesture {
                    if selectedTools.contains(tool) {
                        selectedTools.remove(tool)
                    } else {
                        selectedTools.insert(tool)
                    }
                }

            if let nsImage = tool.appIcon {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: tool.icon)
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(tool.label)
                    .font(.system(size: 13, weight: .medium))
                if HookInstaller.shared.isInstalled(for: tool) && !setupDone {
                    Text("Already configured")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if setupDone && selectedTools.contains(tool) {
                    Text("Installed")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                } else {
                    Text(tool.isInstalled ? tool.subtitle : "Not detected on this machine")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func runSetup() {
        let tools = Array(selectedTools)
        let result = HookInstaller.shared.install(for: tools)
        withAnimation {
            setupDone = result.success
            setupMessage = result.success
                ? "Hooks installed for \(tools.map(\.label).joined(separator: " & "))"
                : result.message
        }
    }

    // ── Step 3: Finish ──
    @State private var starPulse: Bool = false

    private var stepFinish: some View {
        VStack(spacing: 14) {
            Image(systemName: "party.popper")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(Color.accentColor)

            Text("You're all set!")
                .font(.system(size: 22, weight: .bold))

            Text("Fire a test notification to confirm everything is working. Open Settings to customize the look, sound, and position.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            HStack(spacing: 12) {
                Button(action: fireTestNotification) {
                    Label(testFired ? "Sent!" : "Test Notification",
                          systemImage: testFired ? "checkmark.circle.fill" : "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(minWidth: 148)
                }
                .buttonStyle(.borderedProminent)
                .tint(testFired ? .green : .accentColor)
                .controlSize(.large)

                Button(action: { onOpenSettings?() }) {
                    Label("Open Settings", systemImage: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(minWidth: 138)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Divider()
                .padding(.horizontal, 40)

            // ── Star on GitHub ──
            VStack(spacing: 6) {
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "https://github.com/Vibe-Marketer/devping")!)
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.0))
                        Text("Star us on GitHub")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 14))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 1.0, green: 0.78, blue: 0.0).opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color(red: 1.0, green: 0.78, blue: 0.0).opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(starPulse ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: starPulse)
                .onAppear { starPulse = true }

                Text("Stars help more developers discover DevPing — it only takes one second and makes a huge difference. Thank you! 🙏")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 48)
            }

            // ── Community ──
            Button(action: {
                NSWorkspace.shared.open(URL(string: "https://skool.com/vibe-marketing")!)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Join the Vibe Marketing Community")
                        .foregroundStyle(Color.accentColor)
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }

    private func fireTestNotification() {
        let binaryPath = DevPingPaths.notificationBinary
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["--notify", "Claude", "DevPing Demo", "/tmp", "Terminal", "/dev/ttys000", ""]
        try? proc.run()
        withAnimation { testFired = true }
    }
}

/// Arrow popover anchored to the menu bar button — shown once after onboarding is complete,
/// pointing at the bolt icon with a brief "click here for settings" nudge.
final class OnboardingPopover: NSObject {
    private var popover: NSPopover?

    func show(relativeTo button: NSButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: OnboardingPopoverView {
            popover.close()
        })
        popover.contentSize = NSSize(width: 280, height: 130)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover
    }
}

struct OnboardingPopoverView: View {
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 15, weight: .semibold))
                Text("DevPing is running!")
                    .font(.system(size: 13, weight: .semibold))
            }
            Text("Click this ⚡ icon anytime to:\n• Send a test notification\n• Open Settings\n• Toggle launch at login")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
            HStack {
                Spacer()
                Button("Got it") { onDismiss?() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(16)
    }
}

// MARK: - Menu Bar Controller

final class MenuBarController: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var onboardingPopover: OnboardingPopover?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use a bolt icon — matches the "ping" / notification concept
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let img = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "DevPing") {
                let sized = img.withSymbolConfiguration(config) ?? img
                button.image = sized
            }
            button.toolTip = "DevPing — Notification utility for AI coding assistants"
        }

        buildMenu()

        // Show onboarding on first launch
        if !Settings.shared.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showWelcome()
            }
        }
    }

    func showWelcome() {
        if let window = welcomeWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to DevPing"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.contentView = NSHostingView(rootView: WelcomeView(
            onDismiss: { [weak self, weak window] in
                window?.close()
                self?.welcomeWindow = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self?.showOnboardingPopover()
                }
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        ))
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.delegate = self
        welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboardingPopover() {
        guard let button = statusItem.button else { return }
        let popoverController = OnboardingPopover()
        onboardingPopover = popoverController
        popoverController.show(relativeTo: button)
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Header
        let headerItem = NSMenuItem()
        headerItem.attributedTitle = NSAttributedString(
            string: "DevPing",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let versionItem = NSMenuItem()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        versionItem.attributedTitle = NSAttributedString(
            string: "v\(version)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(.separator())

        // Send Test Notification
        let testItem = NSMenuItem(title: "Send Test Notification", action: #selector(sendTest), keyEquivalent: "t")
        testItem.keyEquivalentModifierMask = [.command]
        testItem.target = self
        menu.addItem(testItem)

        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        if #available(macOS 13.0, *) {
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // Star on GitHub
        let starItem = NSMenuItem(title: "⭐ Star on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        starItem.target = self
        menu.addItem(starItem)

        // Community
        let communityItem = NSMenuItem(title: "👥 Join the Community", action: #selector(openCommunity), keyEquivalent: "")
        communityItem.target = self
        menu.addItem(communityItem)

        // Connect (opens About tab in Settings)
        let connectItem = NSMenuItem(title: "🔗 Connect", action: #selector(openConnect), keyEquivalent: "")
        connectItem.target = self
        menu.addItem(connectItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit DevPing", action: #selector(quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func sendTest() {
        let binaryPath = DevPingPaths.notificationBinary
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            let alert = NSAlert()
            alert.messageText = "DevPing binary not found"
            alert.informativeText = "Could not find the devping binary at: \(binaryPath)\n\nInstall via Homebrew or copy to ~/.local/bin/"
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = ["--notify", "Claude", "Test Project", "/tmp", "Terminal", "/dev/ttys000", ""]
        try? proc.run()
    }

    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DevPing Settings"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.delegate = self
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    sender.state = .off
                } else {
                    try SMAppService.mainApp.register()
                    sender.state = .on
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Could not update login item"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/Vibe-Marketer/devping")!)
    }

    @objc private func openCommunity() {
        NSWorkspace.shared.open(URL(string: "https://skool.com/vibe-marketing")!)
    }

    @objc private func openConnect() {
        // Open Settings window focused on the About tab
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DevPing Settings"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(initialTab: "about"))
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        window.delegate = self
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // NSWindowDelegate — settings window closed
    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}

// MARK: - App Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if isMenuBarMode {
    // ── Menu Bar Agent Mode ──
    // Persistent process: shows status bar icon, provides access to settings + test notification
    let menuBarController = MenuBarController()
    menuBarController.setup()
    app.run()

} else if isSettingsMode {
    // ── Settings Mode (standalone) ──
    app.setActivationPolicy(.regular)

    let settingsWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    settingsWindow.title = "DevPing Settings"
    settingsWindow.titleVisibility = .visible
    settingsWindow.titlebarAppearsTransparent = false
    settingsWindow.center()
    settingsWindow.contentView = NSHostingView(rootView: SettingsView())
    settingsWindow.makeKeyAndOrderFront(nil)
    settingsWindow.isReleasedWhenClosed = false

    // Terminate when window closes
    class WindowDelegate: NSObject, NSWindowDelegate {
        func windowWillClose(_ notification: Notification) {
            NSApp.terminate(nil)
        }
    }
    let windowDelegate = WindowDelegate()
    settingsWindow.delegate = windowDelegate

    app.activate(ignoringOtherApps: true)
    app.run()

} else {
    // ── Notification Mode ──
    let settings = Settings.shared

    // Check Do Not Disturb
    if settings.dndEnabled {
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: Date())
        let currentMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let startMinutes = settings.dndStartHour * 60 + settings.dndStartMinute
        let endMinutes = settings.dndEndHour * 60 + settings.dndEndMinute

        let isDND: Bool
        if startMinutes <= endMinutes {
            isDND = currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            // Wraps midnight (e.g., 22:00 - 08:00)
            isDND = currentMinutes >= startMinutes || currentMinutes < endMinutes
        }

        if isDND { exit(0) }
    }

    // Step 1: Check if the editor is focused
    let editorIsFocused = isEditorFocused(editor)

    // Step 2: Determine whether to show popup
    let shouldShowPopup: Bool = {
        guard settings.popupEnabled else { return false }
        if editorIsFocused && !settings.focusedPopup { return false }
        return true
    }()

    // Step 3: Play sound
    // When editor is focused: play at reduced volume (focusedSoundVolume multiplier)
    // When editor is NOT focused: play at full volume
    if editorIsFocused {
        if settings.focusedSound && settings.soundEnabled {
            let focusedVol = settings.soundVolume * settings.focusedSoundVolume
            let soundName = isPermission ? settings.permissionSound : settings.completionSound
            playSoundByName(soundName, volume: focusedVol)
        }
    } else {
        playNotificationSound(isPermission: isPermission)
    }

    // Step 4: If no popup needed, exit immediately
    guard shouldShowPopup else {
        exit(0)
    }

    // Step 5: Show notification popup (existing behavior)
    var notificationSlot = claimSlot()
    let dismissTimeout = settings.dismissTimeout

    let size = settings.notificationSize
    let panelWidth: CGFloat = size.panelWidth
    let panelHeight: CGFloat = size.panelHeight

    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
        styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
        backing: .buffered,
        defer: false
    )

    panel.isMovableByWindowBackground = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    // Note: opacity is applied to the notification background only, not the entire panel,
    // so text and buttons remain fully visible at all opacity levels.

    // Apply appearance mode
    // Glass adapts to the effective appearance — it doesn't force dark.
    switch settings.appearanceMode {
    case .light:
        panel.appearance = NSAppearance(named: .aqua)
    case .dark:
        panel.appearance = NSAppearance(named: .darkAqua)
    case .system:
        // When system, let the design variant hint (light variant → light, dark → dark)
        // Glass inherits from system so the blur material matches the desktop.
        switch settings.designVariant {
        case .light:
            panel.appearance = NSAppearance(named: .aqua)
        case .dark:
            panel.appearance = NSAppearance(named: .darkAqua)
        case .glass:
            panel.appearance = nil  // Inherit system — glass adapts to whatever the OS is
        }
    }

    var dismissTimer: Timer?
    var slotWatcherSource: DispatchSourceTimer?

    func dismiss() {
        dismissTimer?.invalidate()
        slotWatcherSource?.cancel()
        releaseSlot(notificationSlot)

        // Animate out
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.close()
            NSApp.terminate(nil)
        }
    }

    func openProject() {
        dismissTimer?.invalidate()
        slotWatcherSource?.cancel()
        releaseSlot(notificationSlot)
        panel.close()

        if editor.isTerminal && hasTTY {
            var focused = false
            switch editor {
            case .terminal: focused = focusTerminalWindowByTTY(ttyDevice)
            case .iterm: focused = focusiTermWindowByTTY(ttyDevice)
            default: break
            }
            if !focused {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                p.arguments = ["-e", "tell application \"\(editor.appName)\" to activate"]
                try? p.run()
                p.waitUntilExit()
            }
            NSApp.terminate(nil)
        } else {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", "tell application \"\(editor.appName)\" to activate"]
            try? p.run()
            p.waitUntilExit()

            if !projectPath.isEmpty, let cmd = editor.openCommand {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let o = Process()
                    o.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    o.arguments = [cmd, projectPath]
                    try? o.run()
                    o.waitUntilExit()
                    NSApp.terminate(nil)
                }
            } else {
                NSApp.terminate(nil)
            }
        }
    }

    let notificationContent = NotificationView(
        runtime: runtime,
        projectName: projectName,
        editor: editor,
        isPermission: isPermission,
        onOpen: openProject,
        onDismiss: dismiss,
        dismissTimeout: dismissTimeout
    )

    // For glass/vibrancy: no outer padding — SwiftUI content fills the NSVisualEffectView
    // exactly, so the .clipShape border aligns with the panel-level blur.
    // For opaque themes: keep outer padding for visual breathing room.
    let resolvedDesign = settings.resolvedDesign
    let needsBlur = resolvedDesign.useVibrancy || resolvedDesign.isGlass

    let hostingView: NSHostingView<AnyView>
    if needsBlur {
        hostingView = NSHostingView(rootView: AnyView(notificationContent))
    } else {
        hostingView = NSHostingView(rootView: AnyView(
            notificationContent
                .padding(EdgeInsets(top: 4, leading: 12, bottom: 14, trailing: 12))
        ))
    }

    let cr = CGFloat(settings.cornerRadius)
    let bgOpacity = settings.panelOpacity

    if needsBlur {
        // ── Frosted glass: blur + content as SIBLINGS in a container ──
        // Critical: hosting view must NOT be a subview of NSVisualEffectView,
        // otherwise the vibrancy effect makes all content translucent.
        // Instead, both are siblings in a plain container view.
        //
        //   NSView (container = contentView)
        //     ├── NSVisualEffectView (behind — does blur)
        //     └── NSHostingView (on top — fully opaque content)

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = cr
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        // Blur layer (behind)
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = resolvedDesign.vibrancyMaterial
        visualEffect.state = .active  // Force active — panel is never key window
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        // Opacity slider controls the blur layer's transparency
        visualEffect.alphaValue = CGFloat(bgOpacity)
        // Stack extra gaussian blur on the layer for that thick frosted look
        visualEffect.wantsLayer = true
        if let layer = visualEffect.layer {
            let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 15])
            layer.backgroundFilters = [blurFilter as Any]
        }
        container.addSubview(visualEffect)

        // SwiftUI content (on top — fully opaque, no vibrancy bleed)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        container.addSubview(hostingView)

        NSLayoutConstraint.activate([
            // Blur fills container
            visualEffect.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            // Hosting view fills container (on top of blur)
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        panel.contentView = container
    } else {
        // ── Opaque theme: no blur needed, SwiftUI handles everything ──
        panel.contentView = hostingView
    }

    // Pick target screen
    let targetScreen: NSScreen? = {
        switch settings.displayTarget {
        case .main:
            return NSScreen.main
        case .withCursor:
            let mouseLocation = NSEvent.mouseLocation
            return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        }
    }()

    // Position the panel based on its current slot
    func positionPanel(slot: Int, animated: Bool = false) {
        guard let screen = targetScreen else { return }
        let frame = screen.visibleFrame
        let position = settings.screenPosition
        let margin: CGFloat = 16
        let spacing = CGFloat(slot) * (panelHeight + 10)

        let x: CGFloat
        let y: CGFloat

        switch position {
        case .topRight:
            x = frame.maxX - panelWidth - margin
            y = frame.maxY - panelHeight - margin - spacing
        case .topLeft:
            x = frame.minX + margin
            y = frame.maxY - panelHeight - margin - spacing
        case .bottomRight:
            x = frame.maxX - panelWidth - margin
            y = frame.minY + margin + spacing
        case .bottomLeft:
            x = frame.minX + margin
            y = frame.minY + margin + spacing
        }

        let newOrigin = NSPoint(x: x, y: y)
        if animated {
            let newFrame = NSRect(origin: newOrigin, size: panel.frame.size)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrameOrigin(newOrigin)
        }
    }

    positionPanel(slot: notificationSlot)
    panel.orderFrontRegardless()

    // Watch for freed lower slots — slide up to fill gaps
    // Uses DispatchSourceTimer on main queue for reliable firing within NSApp.run()
    let watcherSource = DispatchSource.makeTimerSource(queue: .main)
    watcherSource.schedule(deadline: .now() + 0.5, repeating: 0.5)
    watcherSource.setEventHandler {
        guard notificationSlot > 0 else { return }
        // Check if a lower slot is available
        for lowerSlot in 0..<notificationSlot {
            let lockFile = stackDir.appendingPathComponent("slot-\(lowerSlot).lock")
            var available = false
            if !FileManager.default.fileExists(atPath: lockFile.path) {
                available = true
            } else if let pidStr = try? String(contentsOf: lockFile, encoding: .utf8),
                      let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if kill(pid, 0) != 0 {
                    available = true
                }
            }
            if available {
                // Claim the lower slot
                let myPid = "\(ProcessInfo.processInfo.processIdentifier)"
                try? myPid.write(to: lockFile, atomically: true, encoding: .utf8)
                // Release old slot
                releaseSlot(notificationSlot)
                notificationSlot = lowerSlot
                positionPanel(slot: lowerSlot, animated: true)
                break
            }
        }
    }
    watcherSource.resume()
    slotWatcherSource = watcherSource

    if dismissTimeout > 0 {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissTimeout, repeats: false) { _ in
            slotWatcherSource?.cancel()
            dismiss()
        }
    }

    app.run()
}
