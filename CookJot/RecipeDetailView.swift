import Foundation
import SwiftUI
import UIKit

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        List {
            recipeSection("材料", content: recipe.ingredients)
            recipeSection("作り方", content: recipe.instructions)
            recipeSection("メモ", content: recipe.memo)

            if let source = recipe.sourceURL,
               !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("参考リンク") {
                    if let url = URL(string: source.trimmingCharacters(in: .whitespacesAndNewlines)),
                       url.scheme != nil {
                        Link("参考リンク", destination: url)
                    } else {
                        Text(source)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isVisible = true
            UIApplication.shared.isIdleTimerDisabled = scenePhase == .active
        }
        .onDisappear {
            isVisible = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            if isVisible {
                UIApplication.shared.isIdleTimerDisabled = phase == .active
            }
        }
    }

    @ViewBuilder
    private func recipeSection(_ title: String, content: String) -> some View {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section(title) {
                Text(content)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}
