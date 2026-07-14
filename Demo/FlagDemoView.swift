import SwiftUI
import SharedFlagCore

/// Interactive playground for the shared core: edit the evaluation
/// context and watch every flag re-evaluate live, with the bucket and
/// audit reason the core reports. The point of the demo is that *none*
/// of the decision logic lives in this file — it all comes from
/// `SharedFlagCore`, the module that also builds and tests on Linux.
struct FlagDemoView: View {
    @State private var subjectID = "user-42"
    @State private var region = "US"
    @State private var appVersion = "2.0.0"

    private let regions = ["US", "EU", "IN", "BR"]
    private let versions = ["1.9.9", "2.0.0", "2.1.0", "not-a-version"]

    private let flags: [FeatureFlag] = [
        FeatureFlag(
            key: "new-checkout",
            defaultEnabled: false,
            rules: [FlagRule(rolloutBasisPoints: 5_000,
                             minVersion: SemanticVersion(major: 2, minor: 0, patch: 0))]
        ),
        FeatureFlag(
            key: "dark-mode",
            defaultEnabled: true,
            rules: []
        ),
        FeatureFlag(
            key: "eu-consent-banner",
            defaultEnabled: false,
            rules: [FlagRule(rolloutBasisPoints: 10_000, regions: ["EU"])]
        ),
        FeatureFlag(
            key: "risky-canary",
            defaultEnabled: false,
            rules: [FlagRule(rolloutBasisPoints: 250)] // 2.5%
        )
    ]

    private var context: EvaluationContext {
        EvaluationContext(subjectID: subjectID, appVersion: appVersion, region: region)
    }

    private var results: [EvaluationResult] {
        FlagEvaluator.evaluateAll(flags, in: context)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Evaluation context") {
                    HStack {
                        TextField("Subject ID", text: $subjectID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Random") {
                            subjectID = "user-\(Int.random(in: 1...99_999))"
                        }
                        .buttonStyle(.bordered)
                    }
                    Picker("Region", selection: $region) {
                        ForEach(regions, id: \.self, content: Text.init)
                    }
                    Picker("App version", selection: $appVersion) {
                        ForEach(versions, id: \.self, content: Text.init)
                    }
                }

                Section("Flags — evaluated by SharedFlagCore") {
                    ForEach(Array(zip(flags, results)), id: \.0.key) { flag, result in
                        FlagRow(flag: flag, result: result)
                    }
                }

                Section {
                    Text("Same subject ID, same buckets, same decisions — on this simulator, on an Android build, and in the Linux CI job that tests this module.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("SharedFlagCore")
        }
    }
}

private struct FlagRow: View {
    let flag: FeatureFlag
    let result: EvaluationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(flag.key)
                    .font(.headline.monospaced())
                Spacer()
                Text(result.isEnabled ? "ON" : "OFF")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(result.isEnabled ? Color.green.opacity(0.2) : Color.red.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text("bucket \(result.bucket) · \(result.reason.description)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    FlagDemoView()
}
