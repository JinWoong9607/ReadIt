//
//  PostDetailView.swift
//  readIt
//
//  Created by 진웅홍 on 7/17/24.
//

import SwiftUI
import MarkdownUI

struct SelectableMarkdownView: UIViewRepresentable {
    let markdownContent: String
    @Binding var selectedBody: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .all
        textView.delegate = context.coordinator
        
        // Markdown 설정
        _ = MarkdownUI.Markdown(markdownContent)
        let attributedString = try? AttributedString(markdown: markdownContent, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        textView.attributedText = NSAttributedString(attributedString ?? AttributedString(markdownContent))
        
        textView.textColor = UIColor.label
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        _ = MarkdownUI.Markdown(markdownContent)
        let attributedString = try? AttributedString(markdown: markdownContent, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        textView.attributedText = NSAttributedString(attributedString ?? AttributedString(markdownContent))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableMarkdownView

        init(_ parent: SelectableMarkdownView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let range = textView.selectedTextRange,
               let selectedText = textView.text(in: range),
               !selectedText.isEmpty {
                parent.selectedBody = selectedText
            }
        }
    }
}

struct PostTranslatorResponse: Hashable {
    let selectedBody: String
}

struct PostBodyView: View {
    let postBody: PostBodyResponse
    @State private var selectedBody: String = ""
    @State private var showSearchResult = false
    
    var body: some View {
        VStack {
            ScrollView {
                SelectableMarkdownView(markdownContent: postBody.content, selectedBody: $selectedBody)
                    .frame(height: UIScreen.main.bounds.height * 0.4)
                    .onChange(of: selectedBody) { _, newValue in
                        print("선택된 텍스트가 변경되었습니다 : \(newValue)")
                }
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
            
            Spacer()
            
            NavigationLink(destination: PostTranslatorView(selectedBody: selectedBody)) {
                Text("검색하기")
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(Color.white)
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding()
        .navigationTitle("body View")
    }
}
