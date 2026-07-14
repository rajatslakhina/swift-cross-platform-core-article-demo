/// Pure, synchronous, platform-free flag evaluation.
///
/// This is the piece worth sharing across iOS and Android: the *decision
/// logic* two codebases silently implement differently today. There is no
/// networking, no storage, no UI in this module — the host app supplies a
/// context and a flag definition, and gets back a decision plus the reason.
public enum FlagEvaluator {
    /// Evaluates one flag. First-match-wins over `flag.rules`:
    /// a rule whose version and region constraints accept the context
    /// decides the flag via the deterministic bucket comparison
    /// (`bucket < rolloutBasisPoints`). If no rule applies, the flag's
    /// default is returned.
    ///
    /// A malformed `appVersion` never crashes and never matches a
    /// version-gated rule — those rules are skipped (fail-safe), while
    /// rules without version constraints still apply normally.
    public static func evaluate(_ flag: FeatureFlag, in context: EvaluationContext) -> EvaluationResult {
        let bucket = DeterministicBucketer.bucket(flagKey: flag.key, subjectID: context.subjectID)
        let contextVersion = SemanticVersion(context.appVersion)

        for (index, rule) in flag.rules.enumerated() {
            guard regionMatches(rule: rule, context: context) else { continue }
            guard versionMatches(rule: rule, contextVersion: contextVersion) else { continue }

            let rolledIn = bucket < rule.rolloutBasisPoints
            return EvaluationResult(
                flagKey: flag.key,
                isEnabled: rolledIn,
                bucket: bucket,
                reason: .ruleDecided(
                    ruleIndex: index,
                    thresholdBasisPoints: rule.rolloutBasisPoints,
                    rolledIn: rolledIn
                )
            )
        }

        return EvaluationResult(
            flagKey: flag.key,
            isEnabled: flag.defaultEnabled,
            bucket: bucket,
            reason: .noApplicableRule(defaultEnabled: flag.defaultEnabled)
        )
    }

    /// Evaluates a whole flag set, preserving input order.
    public static func evaluateAll(_ flags: [FeatureFlag], in context: EvaluationContext) -> [EvaluationResult] {
        flags.map { evaluate($0, in: context) }
    }

    private static func regionMatches(rule: FlagRule, context: EvaluationContext) -> Bool {
        rule.regions.isEmpty || rule.regions.contains(context.region)
    }

    private static func versionMatches(rule: FlagRule, contextVersion: SemanticVersion?) -> Bool {
        // No version constraints: applies regardless of context version.
        if rule.minVersion == nil && rule.maxVersionExclusive == nil { return true }
        // Version-gated rule + unparseable context version: fail safe, skip.
        guard let version = contextVersion else { return false }
        if let minimum = rule.minVersion, version < minimum { return false }
        if let maximum = rule.maxVersionExclusive, !(version < maximum) { return false }
        return true
    }
}
