/// The subject a flag is evaluated for. Pure data, trivially Sendable.
public struct EvaluationContext: Equatable, Sendable {
    public let subjectID: String
    /// Raw version string as reported by the host app. Parsed lazily at
    /// evaluation time; malformed values fail *safe* (version-gated
    /// rules skip, they never match).
    public let appVersion: String
    public let region: String

    public init(subjectID: String, appVersion: String, region: String) {
        self.subjectID = subjectID
        self.appVersion = appVersion
        self.region = region
    }
}

/// One targeting rule. Rules are evaluated in order; the first rule
/// whose constraints match the context decides the flag (first-match-wins).
public struct FlagRule: Equatable, Sendable {
    /// Rollout threshold in basis points (0...10_000). 250 = 2.5%.
    /// Out-of-range values are clamped at construction so a bad remote
    /// config can never produce an out-of-range comparison.
    public let rolloutBasisPoints: Int
    /// Inclusive minimum app version, if any.
    public let minVersion: SemanticVersion?
    /// Exclusive maximum app version, if any.
    public let maxVersionExclusive: SemanticVersion?
    /// Region allowlist. Empty means "all regions".
    public let regions: Set<String>

    public init(
        rolloutBasisPoints: Int,
        minVersion: SemanticVersion? = nil,
        maxVersionExclusive: SemanticVersion? = nil,
        regions: Set<String> = []
    ) {
        self.rolloutBasisPoints = min(max(rolloutBasisPoints, 0), 10_000)
        self.minVersion = minVersion
        self.maxVersionExclusive = maxVersionExclusive
        self.regions = regions
    }
}

/// A feature flag: a key, an ordered rule list, and a default for when
/// no rule applies.
public struct FeatureFlag: Equatable, Sendable, Identifiable {
    public let key: String
    public let defaultEnabled: Bool
    public let rules: [FlagRule]

    public var id: String { key }

    public init(key: String, defaultEnabled: Bool, rules: [FlagRule] = []) {
        self.key = key
        self.defaultEnabled = defaultEnabled
        self.rules = rules
    }
}

/// The outcome of one evaluation, with an audit-friendly reason.
/// The reason is part of the public contract on purpose: "why did this
/// user get this variant" is the first question support asks, and it
/// must have the same answer on iOS and Android.
public struct EvaluationResult: Equatable, Sendable {
    public enum Reason: Equatable, Sendable, CustomStringConvertible {
        /// A rule's constraints matched; the bucket comparison decided.
        case ruleDecided(ruleIndex: Int, thresholdBasisPoints: Int, rolledIn: Bool)
        /// No rule's constraints matched; the flag default was used.
        case noApplicableRule(defaultEnabled: Bool)

        public var description: String {
            switch self {
            case let .ruleDecided(index, threshold, rolledIn):
                let verdict = rolledIn ? "inside" : "outside"
                return "rule #\(index) matched; bucket \(verdict) \(threshold) bp rollout"
            case let .noApplicableRule(defaultEnabled):
                return "no rule matched; default (\(defaultEnabled ? "on" : "off"))"
            }
        }
    }

    public let flagKey: String
    public let isEnabled: Bool
    /// The subject's stable bucket for this flag, always reported so
    /// dashboards and bug reports can show it even when a default applied.
    public let bucket: Int
    public let reason: Reason
}
