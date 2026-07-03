import Foundation

/// Result of categorizing a video against the user's existing archives.
enum CategorizationResult: Sendable {
    /// Assign to an existing archive; `newKeywords` should be merged into it.
    case existing(archiveID: UUID, newKeywords: [String])
    /// No good fit — create a new archive with this name and seed keywords.
    case newArchive(name: String, keywords: [String])
}

/// On-device keyword-rule categorizer.
///
/// Extracts candidate keywords from a video's title/hashtags, scores each of
/// the user's archives by overlap with the archive's stored `keywords` and
/// name tokens, and either assigns to the best match or proposes a new folder
/// named after the strongest keyword.
struct Categorizer {
    /// Minimum overlap score required to file into an existing archive.
    var matchThreshold = 2

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "of", "in", "on", "at", "to",
        "for", "with", "by", "from", "this", "that", "is", "are", "was",
        "were", "be", "been", "it", "its", "as", "so", "if", "then", "than",
        "my", "your", "his", "her", "our", "their", "you", "i", "we", "they",
        "how", "what", "when", "where", "why", "who", "not", "no", "yes",
        "just", "very", "really", "will", "can", "cant", "dont", "im", "me",
        "video", "watch", "new", "official", "full", "part", "episode", "ep",
        "shorts", "short", "reel", "reels", "tiktok", "youtube", "instagram",
        "snapchat", "viral", "trending", "fyp", "foryou", "foryoupage",
    ]

    // MARK: - Keyword extraction

    /// Extract lowercase candidate keywords from title/author, hashtags first.
    func extractKeywords(title: String?, authorName: String?) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()

        func add(_ raw: String) {
            let word = raw.lowercased().trimmingCharacters(in: .punctuationCharacters)
            guard word.count >= 3, !Self.stopWords.contains(word), !seen.contains(word) else { return }
            seen.insert(word)
            ordered.append(word)
        }

        let text = title ?? ""

        // Hashtags carry the strongest signal — collect them first.
        for fragment in text.split(separator: "#").dropFirst() {
            let tag = fragment.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })
            if !tag.isEmpty { add(String(tag)) }
        }
        // Then plain words from the title.
        for word in text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "#" }) {
            add(String(word).replacingOccurrences(of: "#", with: ""))
        }
        // Creator name is a weak but useful grouping signal.
        if let author = authorName {
            add(author.replacingOccurrences(of: " ", with: ""))
        }
        return Array(ordered.prefix(12))
    }

    // MARK: - Categorization

    func categorize(
        title: String?,
        authorName: String?,
        platform: Platform,
        archives: [ArchiveFolder]
    ) -> CategorizationResult {
        let candidates = extractKeywords(title: title, authorName: authorName)
        let candidateSet = Set(candidates)

        var best: (archive: ArchiveFolder, score: Int)? = nil
        for archive in archives {
            let nameTokens = archive.name
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
            let archiveTokens = Set(archive.keywords.map { $0.lowercased() }).union(nameTokens)
            let score = archiveTokens.intersection(candidateSet).count
            if score > (best?.score ?? 0) {
                best = (archive, score)
            }
        }

        if let best, best.score >= matchThreshold {
            let merged = candidateSet.subtracting(best.archive.keywords.map { $0.lowercased() })
            return .existing(archiveID: best.archive.id, newKeywords: Array(merged.prefix(8)))
        }

        // No fit — new folder named after the strongest signal.
        let name = candidates.first.map { $0.prefix(1).uppercased() + $0.dropFirst() }
            ?? "\(platform.displayName) Saves"
        return .newArchive(name: name, keywords: Array(candidates.prefix(8)))
    }
}
