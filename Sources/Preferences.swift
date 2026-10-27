import Foundation
import CoreFoundation

struct SpacingValues: Equatable {
    var spacing: Int?
    var padding: Int?
    static let systemDefault = SpacingValues(spacing: nil, padding: nil)

    var description: String {
        if self == .systemDefault { return "系统默认" }
        return "间距 \(spacing.map(String.init) ?? "默认") · 留白 \(padding.map(String.init) ?? "默认")"
    }
}

enum SpacingError: LocalizedError {
    case unexpectedValue(String)
    case cannotSync
    case writeFailed(rollbackOK: Bool)
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unexpectedValue(let key): return "已有设置 \(key) 不是整数。为保留原设置，本次未修改。"
        case .cannotSync: return "无法读取最新设置，请稍后再试。"
        case .writeFailed(let rollbackOK):
            return rollbackOK ? "设置未能保存，已恢复操作前的值。" : "设置未能完整保存，回退也未通过验证。请点击重新读取，检查当前值。"
        case .unsupported: return "尚未验证此系统的间距调整功能。可恢复此前的自定义设置，暂不提供新设置的应用。"
        }
    }
}

/// Use the current user's host-specific global domain, matching defaults -currentHost.
final class SpacingPreferences {
    static let spacingKey = "NSStatusItemSpacing"
    static let paddingKey = "NSStatusItemSelectionPadding"
    private let domain: CFString

    init(domain: CFString = kCFPreferencesAnyApplication) { self.domain = domain }

    private func sync() -> Bool {
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    private func integer(_ key: String) throws -> Int? {
        guard let value = CFPreferencesCopyValue(key as CFString, domain,
                                                kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) else { return nil }
        guard let number = value as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite,
              number.doubleValue >= Double(Int32.min),
              number.doubleValue <= Double(Int32.max),
              number.doubleValue.rounded() == number.doubleValue else {
            throw SpacingError.unexpectedValue(key)
        }
        return number.intValue
    }

    func read() throws -> SpacingValues {
        guard sync() else { throw SpacingError.cannotSync }
        return try SpacingValues(spacing: integer(Self.spacingKey), padding: integer(Self.paddingKey))
    }

    private func set(_ values: SpacingValues) {
        CFPreferencesSetValue(Self.spacingKey as CFString, values.spacing.map { NSNumber(value: $0) },
                              domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue(Self.paddingKey as CFString, values.padding.map { NSNumber(value: $0) },
                              domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    /// Remove overrides for defaults; never substitute a guessed numeric default.
    @discardableResult func write(_ values: SpacingValues) throws -> SpacingValues {
        let before = try read()
        set(values)
        guard sync(), let confirmed = try? read(), confirmed == values else {
            set(before)
            let rollbackOK = sync() && (try? read()) == before
            throw SpacingError.writeFailed(rollbackOK: rollbackOK)
        }
        return before
    }
}
