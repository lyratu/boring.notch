//
//  ClipboardHistoryView.swift
//  boringNotch
//
//  剪切板历史记录页面（填充内容区，与 ShelfView 同级）
//

import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject private var manager = ClipboardHistoryManager.shared

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10]))
            .overlay {
                VStack(spacing: 0) {
                    // 顶部栏
                    header
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                    Divider()
                        .foregroundColor(.white.opacity(0.1))

                    // 列表内容
                    if manager.items.isEmpty {
                        emptyState
                    } else {
                        itemList
                    }
                }
                .padding()
            }
    }

    // MARK: - 顶部栏

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text("Clipboard History")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            if !manager.items.isEmpty {
                Button(action: { manager.clearAll() }) {
                    Text("Clear All")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.5))
            Text("No clipboard history")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.gray.opacity(0.6))
            Text("Copy something to get started")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.gray.opacity(0.4))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 条目列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(manager.items) { item in
                    ClipboardItemRow(
                        item: item,
                        onCopy: { manager.copyToPasteboard(item) },
                        onDelete: { manager.deleteItem(item) }
                    )
                }
            }
            .padding(.vertical, 6)
        }
    }
}
