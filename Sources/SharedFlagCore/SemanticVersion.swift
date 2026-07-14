/// A minimal, dependency-free semantic version: `major.minor.patch`.
///
/// Deliberately imports nothing — not even Foundation — so it compiles
/// identically on iOS, macOS, Linux, and Android. Parsing is strict:
/// each component must be a non-negative integer. Missing minor/patch
/// components default to zero ("1.2" == "1.2.0"), but anything
/// non-numeric (including pre-release suffixes like "1.2.0-beta") is
/// rejected by returning `nil` rather than guessing.
public struct SemanticVersion: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses "1", "1.2", or "1.2.3". Returns `nil` for anything else.
    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let number = Int(part), number >= 0 else { return nil }
            numbers.append(number)
        }
        while numbers.count < 3 { numbers.append(0) }
        // Bounds are guaranteed: the loop above pads `numbers` to exactly 3.
        self.major = numbers[0]
        self.minor = numbers[1]
        self.patch = numbers[2]
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public var description: String { "\(major).\(minor).\(patch)" }
}
