//
//  ClipboardPersistenceService.swift
//  boringNotch
//
//  剪切板历史记录持久化服务，遵循 ShelfPersistenceService 模式
//

import Foundation

final class ClipboardPersistenceService {
    static let shared = ClipboardPersistenceService()

    private let fileURL: URL
    private let imagesDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (support ?? fm.temporaryDirectory)
            .appendingPathComponent("boringNotch", isDirectory: true)
            .appendingPathComponent("Clipboard", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        fileURL = dir.appendingPathComponent("items.json")

        imagesDirectory = dir.appendingPathComponent("images", isDirectory: true)
        try? fm.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        encoder.outputFormatting = [.prettyPrinted]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - 条目持久化

    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        if let items = try? decoder.decode([ClipboardItem].self, from: data) {
            return items
        }
        // 逐条解码容错：单条损坏不影响其余
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        var items: [ClipboardItem] = []
        for dict in jsonArray {
            if let itemData = try? JSONSerialization.data(withJSONObject: dict),
               let item = try? decoder.decode(ClipboardItem.self, from: itemData) {
                items.append(item)
            }
        }
        return items
    }

    func save(_ items: [ClipboardItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save clipboard items: \(error.localizedDescription)")
        }
    }

    // MARK: - 图片存储

    func saveImage(data: Data, filename: String) -> Bool {
        let url = imagesDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            print("Failed to save clipboard image: \(error.localizedDescription)")
            return false
        }
    }

    func loadImage(filename: String) -> Data? {
        let url = imagesDirectory.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    func deleteImage(filename: String) {
        let url = imagesDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAllImages() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
