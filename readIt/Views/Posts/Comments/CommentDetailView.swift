//
//  CommentTranslator.swift
//  readIt
//
//  Created by 진웅홍 on 7/15/24.
//

import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {
    var text: String
    @Binding var selectedText: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .all
        textView.delegate = context.coordinator
        
        textView.text = text
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textColor = UIColor.blue
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        textView.text = text
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView
        
        init(_ parent: SelectableTextView) {
            self.parent = parent
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            if let range = textView.selectedTextRange, let text = textView.text(in: range), !text.isEmpty {
                parent.selectedText = text
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

struct CommentTranslatorResponse: Hashable {
    let selectedText: String
}

struct CommentDetail: View {
    @EnvironmentObject var coordinator: NavCoordinator
    let comment: Comment
    @State private var selectedComment = ""
    @State private var showSearchResult = false
    @State private var isReplying = false
    @State private var replyText = ""

    init(comment: Comment) {
        self.comment = comment
    }

    var body: some View {
        VStack(spacing: 20) {
            commentContent
            searchButton
            replySection
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("댓글 상세")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(comment.author)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(TimeFormatUtil().formatTimeAgo(fromUTCString: comment.time))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            SelectableTextView(text: comment.body, selectedText: $selectedComment)
                .frame(height: UIScreen.main.bounds.height * 0.4)
                .onChange(of: selectedComment) { _, newValue in
                    print("선택된 텍스트가 변경되었습니다: \(newValue)")
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var searchButton: some View {
        Button(action: {
            coordinator.path.append(CommentTranslatorResponse(selectedText: selectedComment))
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("검색하기")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedComment.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .disabled(selectedComment.isEmpty)
    }
    
    private var replySection: some View {
        VStack(spacing: 10) {
            Button(action: {
                withAnimation(.spring()) {
                    isReplying.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isReplying ? "chevron.up" : "arrowshape.turn.up.left")
                    Text(isReplying ? "접기" : "질문하기")
                }
                .foregroundColor(.blue)
                .padding(.vertical, 8)
            }
            
            if isReplying {
                VStack(spacing: 10) {
                    TextField("질문을 입력하세요...", text: $replyText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal, 4)
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            // TODO: Implement reply submission
                            replyText = ""
                            isReplying = false
                        }
                    }) {
                        Text("질문 게시")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(replyText.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(replyText.isEmpty)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
