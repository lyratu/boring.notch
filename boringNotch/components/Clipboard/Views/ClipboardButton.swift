//
//  ClipboardButton.swift
//  boringNotch
//
//  Shelf 中的剪切板历史按钮，点击切换到剪切板历史页面
//

import Defaults
import SwiftUI

struct ClipboardButton: View {
    @ObservedObject private var coordinator = BoringViewCoordinator.shared

    private var isSelected: Bool {
        coordinator.currentView == .clipboard
    }

    var body: some View {
        ZStack {
            // 背景卡片（与 FileShareView 风格一致）
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.35), Color.black.opacity(0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected
                                ? Color.accentColor.opacity(0.9)
                                : Color.white.opacity(0.1),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
                        )
                )
                .shadow(color: Color.black.opacity(0.6), radius: 6, x: 0, y: 2)

            // 内容
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isSelected ? 0.11 : 0.09))
                        .frame(width: 55, height: 55)

                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            isSelected ? Color.accentColor : Color.gray
                        )
                        .scaleEffect(isSelected ? 1.06 : 1.0)
                        .animation(.spring(response: 0.36, dampingFraction: 0.7), value: isSelected)
                }

                Text("Clipboard")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(18)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            withAnimation(.smooth) {
                coordinator.currentView = .clipboard
            }
        }
    }
}
