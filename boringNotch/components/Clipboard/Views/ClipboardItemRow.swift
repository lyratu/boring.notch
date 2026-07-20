//
//  ClipboardItemRow.swift
//  boringNotch
//
//  剪切板历史记录单条行视图
//

import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // 左侧：类型图标或缩略图
            itemIcon
                .frame(width: 32, height: 32)

            // 中间：预览文字
            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(relativeTimestamp)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.gray)
            }

            Spacer()

            // 右侧：操作按钮（hover 时显示）
            if isHovering {
                HStack(spacing: 6) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(.caption))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(.caption))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onCopy)
        .contextMenu {
            Button("复制") { onCopy() }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }

    // MARK: - 类型图标

    @ViewBuilder
    private var itemIcon: some View {
        switch item.kind {
        case .image(let filename):
            if let data = ClipboardPersistenceService.shared.loadImage(filename: filename),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                fallbackIcon("photo")
            }
        case .text:
            fallbackIcon(item.kind.iconSymbolName)
        case .file:
            fallbackIcon(item.kind.iconSymbolName)
        }
    }

    private func fallbackIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(.body))
            .foregroundColor(.gray)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
            )
    }

    // MARK: - 相对时间

    private var relativeTimestamp: String {
        let interval = Date().timeIntervalSince(item.timestamp)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
