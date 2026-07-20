//
//  ClipboardItem.swift
//  boringNotch
//
//  剪切板历史记录数据模型
//

import Foundation

/// 剪切板条目类型
enum ClipboardItemKind: Codable, Equatable, Sendable {
    case text(string: String)
    case image(filename: String)
    case file(bookmark: Data)

    enum CodingKeys: String, CodingKey { case type, value }
    enum KindTag: String, Codable { case text, image, file }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(KindTag.self, forKey: .type)
        switch type {
        case .text:
            self = .text(string: try container.decode(String.self, forKey: .value))
        case .image:
            self = .image(filename: try container.decode(String.self, forKey: .value))
        case .file:
            self = .file(bookmark: try container.decode(Data.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let string):
            try container.encode(KindTag.text, forKey: .type)
            try container.encode(string, forKey: .value)
        case .image(let filename):
            try container.encode(KindTag.image, forKey: .type)
            try container.encode(filename, forKey: .value)
        case .file(let bookmark):
            try container.encode(KindTag.file, forKey: .type)
            try container.encode(bookmark, forKey: .value)
        }
    }
}

/// 剪切板历史记录条目
struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: ClipboardItemKind
    let timestamp: Date
    let previewText: String

    init(id: UUID = UUID(), kind: ClipboardItemKind, timestamp: Date = Date(), previewText: String) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.previewText = previewText
    }
}

// MARK: - 用于去重的身份标识
extension ClipboardItem {
    var identityKey: String {
        switch kind {
        case .text(let s):
            return "text://" + s
        case .image(let filename):
            return "image://" + filename
        case .file(let bookmark):
            let bookmark = Bookmark(data: bookmark)
            if let url = bookmark.resolveURL() {
                return "file://" + url.standardizedFileURL.path
            }
            return "file://missing/" + bookmark.data.base64EncodedString()
        }
    }
}

// MARK: - 类型图标
extension ClipboardItemKind {
    var iconSymbolName: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}
