import SwiftUI

struct RecipeImportView: View {
    let onImport: (ImportedRecipe) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("レシピ全文")
                        .font(.headline)
                    Spacer()
                    PasteButton(payloadType: String.self) { strings in
                        guard let pastedText = strings.first else { return }
                        text = pastedText
                    }
                    .labelStyle(.titleOnly)
                    .disabled(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .accessibilityLabel("レシピ全文")
                    if text.isEmpty {
                        Text("ここにレシピ全文を貼り付け")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.secondary.opacity(0.4), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
                .padding()
                .navigationTitle("かんたん取込")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("取り込む") {
                            onImport(RecipeTextParser.parse(text))
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}
