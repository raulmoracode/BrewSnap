import Foundation

extension JSONEncoder {
    static var brewsnap: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }
}

extension JSONDecoder {
    static var brewsnap: JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }
}

extension BrewSnapshot {
    func toPrettyJSON() throws -> String {
        let data = try JSONEncoder.brewsnap.encode(self)
        guard let str = String(data: data, encoding: .utf8) else {
            throw ShellError.outputDecodingFailed
        }
        return str
    }

    static func from(jsonString: String) throws -> BrewSnapshot {
        guard let data = jsonString.data(using: .utf8) else {
            throw ShellError.outputDecodingFailed
        }
        return try JSONDecoder.brewsnap.decode(BrewSnapshot.self, from: data)
    }

    static func from(data: Data) throws -> BrewSnapshot {
        try JSONDecoder.brewsnap.decode(BrewSnapshot.self, from: data)
    }
}
