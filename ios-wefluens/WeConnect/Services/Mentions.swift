//
//  Mentions.swift
//  WeConnect
//
//  Group @-mention helpers (ports the RN app's mentions.ts). Mentions are stored
//  literally in the message body as `@<displayName>` or an "@everyone" token; we
//  detect whether a message targets the current user to drive the "@me" indicator.
//

import Foundation

enum Mentions {
    /// "@everyone" tokens across the app's languages — any of these targets every member.
    static let allTokens = ["@全体成员", "@Everyone", "@Todos"]

    static func isAllMention(_ body: String) -> Bool {
        !body.isEmpty && allTokens.contains { body.contains($0) }
    }

    /// True when `body` @-mentions me by name, or @-mentions everyone.
    static func messageMentionsMe(_ body: String, myName: String?) -> Bool {
        if body.isEmpty { return false }
        if isAllMention(body) { return true }
        guard let myName, !myName.isEmpty else { return false }
        return body.contains("@\(myName)")
    }
}
