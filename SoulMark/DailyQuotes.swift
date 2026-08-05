import Foundation

struct DailySoulQuote: Codable, Equatable {
    let id: Int
    let chinese: String
    let english: String
    let source: String

    var text: String {
        localizedText(chinese, english)
    }

    var shareText: String {
        "\(text)\n\n— \(source)\nSoulMark"
    }
}

enum DailyQuoteCatalog {
    static let guestUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private static let quotes: [DailySoulQuote] = (try? load()) ?? fallbackQuotes

    static func load(bundle: Bundle = .main) throws -> [DailySoulQuote] {
        guard let url = bundle.url(forResource: "DailyQuotes", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([DailySoulQuote].self, from: data)
        guard decoded.count == 500 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return decoded
    }

    static func quote(
        userID: UUID,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> DailySoulQuote {
        quotes[index(userID: userID, date: date, calendar: calendar, count: quotes.count)]
    }

    static func index(
        userID: UUID,
        date: Date,
        calendar: Calendar,
        count: Int
    ) -> Int {
        guard count > 0 else { return 0 }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let key = String(
            format: "%@|%04d-%02d-%02d",
            userID.uuidString,
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )

        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    private static let fallbackQuotes: [DailySoulQuote] = [
        DailySoulQuote(
            id: 1,
            chinese: "千里之行，始于足下。",
            english: "A journey of a thousand miles begins with a single step.",
            source: "Laozi, Tao Te Ching"
        ),
        DailySoulQuote(
            id: 2,
            chinese: "这一切终将过去。",
            english: "This too shall pass.",
            source: "Persian saying"
        )
    ]
}
