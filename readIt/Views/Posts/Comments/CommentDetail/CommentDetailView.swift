//
//  CommentTranslator.swift
//  readIt
//
//  Created by 진웅홍 on 7/15/24.
//

import SwiftUI
import UIKit
import Combine

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
        textView.textColor = UIColor.label
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
    let appTheme: AppThemeSettings
    let textSizePreference: TextSizePreference
    @State private var replies: [ReadItComment] = []
    @State private var selectedComment = ""
    @State private var showSearchResult = false
    @State private var isReplying = false
    @State private var replyText = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var replyingToCommentId: Int? = nil
    

    init(comment: Comment, appTheme: AppThemeSettings, textSizePreference: TextSizePreference) {
        self.comment = comment
        self.appTheme = appTheme
        self.textSizePreference = textSizePreference
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                instructionText
                commentContent
                if !selectedComment.isEmpty {
                    searchButton
                }
                
                if isLoading {
                    ProgressView()
                } else {
                    commentSection
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("댓글 상세")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchComments()
        }
    }
    
    private var instructionText: some View {
        Text("텍스트를 드래그하여 검색할 수 있습니다")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 5)
    }
    
    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(comment.author)
                .font(.headline)
                .foregroundColor(.primary)
            
            
            DetailTagView(icon: "clock", data: TimeFormatUtil().formatTimeAgo(fromUTCString: comment.time), appTheme: appTheme, textSizePreference: textSizePreference)
            
            SelectableTextView(text: comment.body, selectedText: $selectedComment)
                .frame(minHeight: 150)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 1)
        }
    }
    
    private var searchButton: some View {
        Button(action: {
            coordinator.path.append(CommentTranslatorResponse(selectedText: selectedComment))
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("선택한 텍스트 검색")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("댓글")
                .font(.headline)
            
            replyButton(for: nil)
            
            ForEach(replies, id: \.commentId) { reply in
                replyView(for: reply)
            }
        }
    }
    
    private func replyView(for reply: ReadItComment) -> some View {
            HStack(alignment: .top, spacing: 0) {
                if reply.depth > 0 {
                    replyIndicator(depth: reply.depth)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(reply.author)
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Spacer()
                        Text(TimeFormatUtil().readItTimeUtil(fromTimeInterval: Double(reply.time) ?? 0))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(reply.body)
                        .font(.body)
                    
                    replyButton(for: reply.commentId)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.leading, CGFloat(reply.depth) * 10)
            .animation(.default, value: 0)
        }
    
    private func replyIndicator(depth: Int) -> some View {
            VStack {
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                }
            }
            .padding(.leading, 10)
        }

    
    private func replyButton(for commentId: Int?) -> some View {
        Button(action: {
            replyingToCommentId = commentId
            isReplying = true
        }) {
            Text(commentId == nil ? "댓글 작성" : "답글 작성")
                .font(.footnote)
                .foregroundColor(.blue)
        }
        .sheet(isPresented: $isReplying) {
            replySheet()
        }
    }
    
    private func replySheet() -> some View {
        VStack(spacing: 20) {
            Text(replyingToCommentId == nil ? "댓글 작성" : "답글 작성")
                .font(.headline)
            
            TextEditor(text: $replyText)
                .frame(height: 150)
                .border(Color.gray, width: 1)
            
            Button(action: {
                submitReply(to: replyingToCommentId)
                isReplying = false
            }) {
                Text("게시")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(replyText.isEmpty || isSubmitting ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(replyText.isEmpty || isSubmitting)
        }
        .padding()
        .onDisappear {
            replyingToCommentId = nil
        }
    }
    
    private func submitReply(to commentId: Int?) {
        isSubmitting = true
        let parentId = commentId
        let depth: Int
        print(commentId ?? 0)
        
        if let commentId = commentId {
            if let parentComment = replies.first(where: { $0.commentId == commentId }) {
                depth = parentComment.depth + 1
            } else {
                depth = 1
            }
        } else {
            depth = 0
        }
        
        let newComment = ReadItComment(
            commentId: 0,
            userId: ReadItLoginUtil.shared.getSavedUsername(),
            parentCommentId: parentId,
            commentBody: comment.body,
            author: ReadItLoginUtil.shared.getSavedUsername(),
            score: 0,
            time: String(Date().timeIntervalSince1970),
            body: replyText,
            depth: depth,
            stickied: false,
            directURL: comment.directURL,
            isCollapsed: false,
            isRootCollapsed: false
        )
        
        print("Submitting comment with parndId: \(String(describing: parentId))")

        ReadItCommentService.shared.sendComment(comment: newComment) { result in
            isSubmitting = false
            switch result {
            case .success(let postedComment):
                print("Posted comment: \(postedComment)")
                alertMessage = "댓글이 성공적으로 게시되었습니다."
                replyText = ""
                isReplying = false
                // 새 댓글을 즉시 목록에 추가
                DispatchQueue.main.async {
                    self.replies.append(postedComment)
                    self.sortReplies()
                }
            case .failure(let error):
                alertMessage = "댓글 게시에 실패했습니다: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
    
    private func sortReplies() {
        // 댓글을 트리 구조로 정렬
        var commentDict = [Int?: [ReadItComment]]()
        for comment in replies {
            commentDict[comment.parentCommentId, default: []].append(comment)
        }
        
        func flattenComments(_ comments: [ReadItComment], parentId: Int?, depth: Int) -> [ReadItComment] {
            return comments.flatMap { comment -> [ReadItComment] in
                var comment = comment
                comment.depth = depth
                let children = commentDict[comment.commentId] ?? []
                return [comment] + flattenComments(children, parentId: comment.commentId, depth: depth + 1)
            }
        }
        
        self.replies = flattenComments(commentDict[nil] ?? [], parentId: nil, depth: 0)
    }
    
    private func fetchComments() {
        isLoading = true
        ReadItCommentService.shared.getComments(for: comment.directURL) { result in
            isLoading = false
            switch result {
            case .success(let fetchedComments):
                self.replies = fetchedComments
                self.sortReplies()
            case .failure(let error):
                alertMessage = "댓글을 불러오는데 실패했습니다: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}


