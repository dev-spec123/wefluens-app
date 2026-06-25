//
//  PasswordPolicy.swift
//  WeConnect
//
//  Shared password-strength policy — used at every password entry point
//  (sign-up, forced change, voluntary change, recovery). Keeps the rule in one
//  place so all the screens stay in lock-step. Mirrors the RN
//  src/lib/passwordPolicy.ts (`passwordStrengthError`).
//
//  Rule: at least 8 characters AND an uppercase letter AND a lowercase letter
//  AND a digit AND a special character (any non-alphanumeric).
//

import Foundation

enum PasswordPolicy {
    /// Minimum password length, shared across all entry points.
    static let minLength = 8

    /// Returns an L10n KEY describing why `pw` is too weak, or nil when it passes.
    /// A single message (`authErrPasswordWeak`) covers the whole rule so the UI
    /// never leaks which specific class is missing. Callers render it with l10n.t(...).
    static func error(_ pw: String) -> L10n? {
        let longEnough = pw.count >= minLength
        let hasUpper = pw.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLower = pw.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigit = pw.rangeOfCharacter(from: .decimalDigits) != nil
        // "Special" = any character that is NOT a letter or a digit (mirrors the
        // RN regex /[^A-Za-z0-9]/). We invert the alphanumeric set so anything
        // outside [A-Za-z0-9] — punctuation, symbols, whitespace — counts.
        let alphanumeric = CharacterSet.alphanumerics
        let hasSpecial = pw.unicodeScalars.contains { !alphanumeric.contains($0) }
        if longEnough && hasUpper && hasLower && hasDigit && hasSpecial { return nil }
        return .authErrPasswordWeak
    }
}
