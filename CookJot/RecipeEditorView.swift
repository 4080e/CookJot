import Foundation
import SwiftUI
import SwiftData

struct RecipeEditorView: View {
    private let recipe: Recipe?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var ingredients = ""
    @State private var instructions = ""
    @State private var memo = ""
    @State private var sourceURL = ""
    @State private var isShowingSaveError = false
    @State private var isShowingImport = false

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? "")
        _ingredients = State(initialValue: recipe?.ingredients ?? "")
        _instructions = State(initialValue: recipe?.instructions ?? "")
        _memo = State(initialValue: recipe?.memo ?? "")
        _sourceURL = State(initialValue: recipe?.sourceURL ?? "")
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                if recipe == nil {
                    Section {
                        Button("かんたん取込") {
                            isShowingImport = true
                        }
                    }
                }
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
            .navigationTitle(recipe == nil ? "新規レシピ" : "レシピを編集")
            .sheet(isPresented: $isShowingImport) {
                RecipeImportView { imported in
                    title = imported.title
                    ingredients = imported.ingredients
                    instructions = imported.instructions
                    memo = imported.memo
                    sourceURL = imported.sourceURL
                }
            }
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
        let target: Recipe
        if let recipe {
            target = recipe
        } else {
            target = Recipe(title: trimmedTitle, createdAt: now, updatedAt: now)
            modelContext.insert(target)
        }
        target.title = trimmedTitle
        target.ingredients = ingredients
        target.instructions = instructions
        target.memo = memo
        target.sourceURL = link.isEmpty ? nil : link
        target.updatedAt = now

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            isShowingSaveError = true
        }
    }
}

#Preview {
    RecipeEditorView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
