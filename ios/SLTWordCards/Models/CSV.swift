import Foundation

/// Minimal RFC 4180 reader: quoted fields, escaped quotes, embedded newlines.
/// The web app uses PapaParse for the same job.
enum CSV {
    static func parse(_ text: String) -> [[String: String]] {
        var rows = parseRows(text)
        guard let header = rows.first else { return [] }
        rows.removeFirst()

        return rows.compactMap { fields in
            // Skip blank lines, the way PapaParse's `skipEmptyLines` does.
            guard fields.contains(where: { !$0.trimmed.isEmpty }) else { return nil }

            var row: [String: String] = [:]
            for (index, key) in header.enumerated() {
                row[key.trimmed] = index < fields.count ? fields[index] : ""
            }
            return row
        }
    }

    private static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            var next = text.index(after: index)

            if inQuotes {
                if character == "\"" {
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")            // "" is an escaped quote
                        next = text.index(after: next)
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
                index = next
                continue
            }

            switch character {
            case "\"":
                inQuotes = true
            case ",":
                fields.append(field)
                field = ""
            case "\n":
                fields.append(field)
                rows.append(fields)
                fields = []
                field = ""
            case "\r":
                break   // CRLF: the \n closes the row
            default:
                field.append(character)
            }
            index = next
        }

        if !field.isEmpty || !fields.isEmpty {
            fields.append(field)
            rows.append(fields)
        }
        return rows
    }
}
