//
//  ClipboardHistoryManager.swift
//  boringNotch
//
//  剪切板历史记录核心管理器，监听系统剪切板变化并维护历史列表
//

import AppKit
import Combine
import Defaults

@MainActor
final class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    /// 历史记录列表（最新在前）
    @Published private(set) var items: [ClipboardItem] = [] {
        didSet { ClipboardPersistenceService.shared.save(items) }
    }

    /// 是否正在监听剪切板
    @Published var isMonitoring: Bool = false

    /// 剪切板历史面板是否打开（供 UI 绑定）
    @Published var isPanelOpen: Bool = false

    /// 从历史记录恢复剪切板时为 true，防止重复录入
    private var isRestoringFromHistory: Bool = false

    /// 上次检测时的 pasteboard changeCount
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    /// 监听定时器
    private var monitorTimer: Timer?

    private init() {
        items = ClipboardPersistenceService.shared.load()
    }

    // MARK: - 监听控制

    /// 开始监听剪切板变化
    func startMonitoring() {
        guard !isMonitoring, Defaults[.clipboardHistoryEnabled] else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
        isMonitoring = true
    }

    /// 停止监听
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }

    /// 切换面板显示状态
    func togglePanel() {
        isPanelOpen.toggle()
    }

    // MARK: - 剪切板检测

    private func checkPasteboard() {
        // 从历史记录复制时跳过本次检测
        guard !isRestoringFromHistory else { return }

        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        processPasteboardContent()
    }

    /// 提取剪切板内容并添加到历史记录
    private func processPasteboardContent() {
        let pasteboard = NSPasteboard.general

        // 优先级：图片 > 文件 > 文字
        if let item = extractImage(from: pasteboard) {
            addItem(item)
        } else if let item = extractFile(from: pasteboard) {
            addItem(item)
        } else if let item = extractText(from: pasteboard) {
            addItem(item)
        }
    }

    /// 从剪切板提取图片
    private func extractImage(from pasteboard: NSPasteboard) -> ClipboardItem? {
        // 优先 PNG，其次 TIFF
        guard let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
              let nsImage = NSImage(data: data) else {
            return nil
        }

        // 缩放到最大宽度 512px 以节省空间
        let resizedData = resizeImage(nsImage, maxWidth: 512)
        let filename = "\(UUID().uuidString).png"

        guard ClipboardPersistenceService.shared.saveImage(data: resizedData, filename: filename) else {
            return nil
        }

        let preview: String
        if let rep = nsImage.representations.first {
            preview = "Image (\(Int(rep.pixelsWide))×\(Int(rep.pixelsHigh)))"
        } else {
            preview = "Image"
        }

        return ClipboardItem(kind: .image(filename: filename), previewText: preview)
    }

    /// 从剪切板提取文件
    private func extractFile(from pasteboard: NSPasteboard) -> ClipboardItem? {
        guard let urlString = pasteboard.string(forType: .fileURL),
              let url = URL(string: urlString) else {
            return nil
        }

        // 需要是本地文件 URL
        guard url.isFileURL else { return nil }

        guard let bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return nil
        }

        let preview = url.lastPathComponent
        return ClipboardItem(kind: .file(bookmark: bookmarkData), previewText: preview)
    }

    /// 从剪切板提取文字
    private func extractText(from pasteboard: NSPasteboard) -> ClipboardItem? {
        guard let string = pasteboard.string(forType: .string), !string.isEmpty else {
            return nil
        }

        // 截取前 100 字符作为预览（去除首尾空白和换行）
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String(trimmed.prefix(100))
        return ClipboardItem(kind: .text(string: string), previewText: preview)
    }

    // MARK: - 条目管理

    /// 添加新条目（去重 + 上限控制）
    private func addItem(_ item: ClipboardItem) {
        // 与最近一条去重
        if let first = items.first, first.identityKey == item.identityKey {
            return
        }

        items.insert(item, at: 0)

        // 超出上限时清理末尾
        let maxItems = Defaults[.clipboardHistoryMaxItems]
        while items.count > maxItems {
            if let removed = items.popLast(), case .image(let filename) = removed.kind {
                ClipboardPersistenceService.shared.deleteImage(filename: filename)
            }
        }
    }

    /// 将历史条目复制回系统剪切板
    func copyToPasteboard(_ item: ClipboardItem) {
        isRestoringFromHistory = true
        defer {
            // 延迟重置标志，确保定时器不会在下一轮检测到刚写入的变化
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                lastChangeCount = NSPasteboard.general.changeCount
                isRestoringFromHistory = false
            }
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text(let string):
            pasteboard.setString(string, forType: .string)

        case .image(let filename):
            if let data = ClipboardPersistenceService.shared.loadImage(filename: filename),
               let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }

        case .file(let bookmark):
            let bookmark = Bookmark(data: bookmark)
            if let url = bookmark.resolveURL() {
                url.accessSecurityScopedResource { accessibleURL in
                    pasteboard.writeObjects([accessibleURL as NSURL])
                }
            }
        }
    }

    /// 删除单条记录
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        if case .image(let filename) = item.kind {
            ClipboardPersistenceService.shared.deleteImage(filename: filename)
        }
    }

    /// 清空所有历史记录
    func clearAll() {
        items = []
        ClipboardPersistenceService.shared.deleteAllImages()
    }
}

// MARK: - 图片缩放辅助
private func resizeImage(_ image: NSImage, maxWidth: CGFloat) -> Data {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return image.tiffRepresentation ?? Data()
    }

    let originalWidth = CGFloat(bitmap.pixelsWide)
    let originalHeight = CGFloat(bitmap.pixelsHigh)

    guard originalWidth > maxWidth else {
        return bitmap.representation(using: .png, properties: [:]) ?? Data()
    }

    let scaleFactor = maxWidth / originalWidth
    let newHeight = originalHeight * scaleFactor
    let newSize = NSSize(width: maxWidth, height: newHeight)

    let newImage = NSImage(size: newSize)
    newImage.lockFocus()
    defer { newImage.unlockFocus() }

    image.draw(in: NSRect(origin: .zero, size: newSize),
               from: .zero,
               operation: .sourceOver,
               fraction: 1.0)

    if let newBitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                        pixelsWide: Int(maxWidth),
                                        pixelsHigh: Int(newHeight),
                                        bitsPerSample: 8,
                                        samplesPerPixel: 4,
                                        hasAlpha: true,
                                        isPlanar: false,
                                        colorSpaceName: .deviceRGB,
                                        bytesPerRow: 0,
                                        bitsPerPixel: 0) {
        newBitmap.size = newSize
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newBitmap)
        newImage.draw(in: NSRect(origin: .zero, size: newSize),
                      from: .zero,
                      operation: .sourceOver,
                      fraction: 1.0)
        NSGraphicsContext.current = nil
        return newBitmap.representation(using: .png, properties: [:]) ?? Data()
    }

    return bitmap.representation(using: .png, properties: [:]) ?? Data()
}
