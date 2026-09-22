import Foundation
import SwiftUI
import SwiftData

struct RecipeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var ingredients = ""
    @State private var instructions = ""
    @State private var memo = ""
    @State private var sourceURL = ""
    @State private var isShowingSaveError = false

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("レシピ名") {
                    TextField("レシピ名", text: $title)
                }
                Section("材料") {
                    TextField("材料", text: $ingredients, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("作り方") {
                    TextField("作り方", text: $instructions, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("メモ") {
                    TextField("メモ", text: $memo, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("参考リンク") {
                    TextField("URL（任意）", text: $sourceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("新規レシピ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: saveRecipe)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .alert("保存できませんでした", isPresented: $isShowingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("入力内容を保持しています。もう一度保存してください。")
            }
        }
    }

    private func saveRecipe() {
        guard !trimmedTitle.isEmpty else { return }

        let now = Date()
        let link = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipe = Recipe(
            title: trimmedTitle,
            ingredients: ingredients,
            instructions: instructions,
            memo: memo,
            sourceURL: link.isEmpty ? nil : link,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(recipe)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(recipe)
            isShowingSaveError = true
        }
    }
}

#Preview {
    RecipeEditorView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
