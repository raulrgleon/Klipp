import Foundation

enum FuzzySearch {
    /// Higher is better. `nil` means no match.
    static func score(query: String, in text: String) -> Int? {
        let q = normalize(query)
        let t = normalize(text)
        if q.isEmpty { return 0 }
        if t.isEmpty { return nil }

        if let range = t.range(of: q) {
            var value = 400
            if range.lowerBound == t.startIndex { value += 180 }
            value += max(0, 80 - t.count / 8)
            return value
        }

        var score = 0
        var consecutive = 0
        var index = t.startIndex
        for character in q {
            var found = false
            while index < t.endIndex {
                if t[index] == character {
                    consecutive += 1
                    score += 8 + consecutive * 6
                    index = t.index(after: index)
                    found = true
                    break
                }
                consecutive = 0
                index = t.index(after: index)
            }
            if !found { return nil }
        }
        return score
    }

    static func filter(_ items: [ClipboardItem], query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return items.sorted(by: displayOrder)
        }

        let scored: [(ClipboardItem, Int)] = items.compactMap { item in
            guard let value = score(query: trimmed, in: item.searchableText) else { return nil }
            let pinBoost = item.isPinned ? 40 : 0
            return (item, value + pinBoost)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.lastCopiedAt > rhs.0.lastCopiedAt
            }
            .map(\.0)
    }

    static func displayOrder(lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
        return lhs.lastCopiedAt > rhs.lastCopiedAt
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
