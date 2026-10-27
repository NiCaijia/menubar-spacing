import Foundation

private struct CheckFailure: Error, CustomStringConvertible { let description: String }

private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(description: message) }
}

/// Exercise persistence in a throwaway domain, never in the user's global preferences.
func runSelfCheck() throws {
    let domain = "local.ncj.MenuBarSpacing.SelfTest." + UUID().uuidString
    let store = SpacingPreferences(domain: domain as CFString)
    defer { _ = try? store.write(.systemDefault) }
    let empty = try store.read()
    try check(empty == .systemDefault, "fresh domain must have no overrides")
    let before = try store.write(.init(spacing: 8, padding: 12))
    try check(before == .systemDefault, "write must return prior state for undo")
    let persisted = try store.read()
    try check(persisted == .init(spacing: 8, padding: 12), "independent values must persist")

    for (key, expected) in [(SpacingPreferences.spacingKey, "8"), (SpacingPreferences.paddingKey, "12")] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["-currentHost", "read", domain, key]
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try check(process.terminationStatus == 0, "defaults must find the host-specific preference")
        try check(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) == expected,
                  "separate process must see the persisted value")
    }

    _ = try store.write(.init(spacing: nil, padding: 20))
    let partial = try store.read()
    try check(partial == .init(spacing: nil, padding: 20), "one override can be absent independently")
    _ = try store.write(.systemDefault)
    _ = try store.write(.systemDefault)
    let restored = try store.read()
    try check(restored == .systemDefault, "restore must remove keys and be idempotent")
}

@MainActor
func runModelChecks() throws {
    let store = SpacingPreferences(domain: ("local.ncj.MenuBarSpacing.ModelTest." + UUID().uuidString) as CFString)
    defer { _ = try? store.write(.systemDefault) }
    _ = try store.write(.init(spacing: 4, padding: 6))
    let model = SpacingModel(preferences: store, majorVersion: 27)
    try check(model.supported && model.limitedCompatibility, "27 must expose limited compatibility")
    try check(!model.canApply && model.spacing == 4 && model.padding == 6, "opening must retain current values")
    model.preset(12)
    let beforeApply = try store.read()
    try check(beforeApply == .init(spacing: 4, padding: 6), "preview must not save preferences")
    try check(model.canApply, "a changed preset must be applicable on 27")
    model.apply()
    let applied = try store.read()
    try check(applied == .init(spacing: 12, padding: 12), "Apply must persist on 27")
    model.undo()
    let undone = try store.read()
    try check(undone == .init(spacing: 4, padding: 6), "undo must preserve original independent values")
    model.restore()
    let reset = try store.read()
    try check(reset == .systemDefault, "reset must remove overrides on 27")
    for major in [14, 26, 27] { try check(SpacingModel.supportsAdjustment(on: major), "known version must be enabled") }
    for major in [13, 28] { try check(!SpacingModel.supportsAdjustment(on: major), "untested version must not be advertised as supported") }
    let future = SpacingModel(preferences: store, majorVersion: 28)
    future.preset(8); future.apply()
    let rejected = try store.read()
    try check(future.isError && rejected == .systemDefault, "unknown system must reject new writes")
}
