/// Assigns a subject (user, device, session) to one of 10,000 stable
/// buckets for percentage rollouts, using FNV-1a 64-bit.
///
/// Why hand-rolled FNV-1a instead of `Hasher` or `hashValue`:
/// Swift's built-in hashing is *deliberately* randomized per process —
/// two runs of the same app disagree, and iOS and Android builds of a
/// shared core certainly would. Rollout bucketing must be a pure
/// function of (flag, subject) or the same user flips in and out of a
/// feature between launches and between platforms. FNV-1a is tiny,
/// fully specified, and produces identical results on every platform
/// that can multiply two 64-bit integers.
///
/// The bucket space is 10,000 (basis points), not 100, so a 0.25%
/// canary rollout is expressible without floating point.
public enum DeterministicBucketer {
    public static let bucketCount: UInt64 = 10_000

    /// Stable bucket in `0..<10_000` for a (flagKey, subjectID) pair.
    ///
    /// The flag key salts the hash so one subject lands in *different*
    /// buckets for different flags — otherwise the same unlucky 1% of
    /// users would receive every risky canary at once.
    public static func bucket(flagKey: String, subjectID: String) -> Int {
        let hash = fnv1a("\(flagKey):\(subjectID)")
        return Int(hash % bucketCount)
    }

    /// FNV-1a 64-bit over the string's UTF-8 bytes.
    /// Overflow multiplication (`&*`) is the algorithm, not an accident:
    /// FNV is defined as wrapping arithmetic mod 2^64.
    static func fnv1a(_ input: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }
}
