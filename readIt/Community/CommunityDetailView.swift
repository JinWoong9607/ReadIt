//
//  CommunityDetailView.swift
//  readIt
//
//  Created by 진웅홍 on 7/29/24.
//

import SwiftUI

struct CommunityDetailView: View {
    let comment: ReadItComment
    
    @State private var relatedComments: [ReadItComment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var replyText = ""
    @State private var isReplying = false
    @State private var replyingToId: Int?
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 상위 댓글의 본문만 표시
                    Text(comment.commentBody)
                        .font(.body)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2)
                    
                    // 전체 댓글 내용 표시
                    commentView(comment: comment, isMainComment: true)
                        .padding(.bottom)
                    
                    if isLoading {
                        ProgressView()
                    } else if !relatedComments.isEmpty {
                        ForEach(organizeComments(relatedComments), id: \.id) { commentData in
                            commentView(comment: commentData.comment, isMainComment: false)
                                .padding(.leading, CGFloat(commentData.depth * 20))  // 대댓글 효과를 위한 들여쓰기
                        }
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    } else {
                        Text("관련 댓글이 없습니다.")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            // 댓글 입력 버튼
            Button(action: {
                isReplying = true
                replyingToId = nil  // 메인 댓글에 대한 답글
            }) {
                Text("댓글 작성")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .navigationBarTitle("댓글 상세", displayMode: .inline)
        .onAppear(perform: loadRelatedComments)
        .sheet(isPresented: $isReplying) {
            replyView
        }
    }
    
    private func commentView(comment: ReadItComment, isMainComment: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comment.author)
                    .font(.headline)
                Spacer()
                Text(TimeFormatUtil().readItTimeUtil(fromTimeInterval: Double(comment.time) ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(comment.body)
                .font(.body)
            
            HStack {
                Spacer()
                
                Button(action: {
                    isReplying = true
                    replyingToId = comment.commentId
                }) {
                    Image(systemName: "arrowshape.turn.up.left")
                    Text(isMainComment ? "댓글" : "답글")
                }
                .foregroundColor(.blue)
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .padding()
        .background(isMainComment ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private var replyView: some View {
        VStack {
            Text(replyingToId == nil ? "댓글 작성" : "답글 작성")
                .font(.headline)
                .padding()
            
            TextEditor(text: $replyText)
                .frame(height: 150)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            
            Button(action: submitReply) {
                Text("게시")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .padding()
    }
    
    private func loadRelatedComments() {
        isLoading = true
        ReadItCommentService.shared.getCommentsByBody(comment.commentBody) { result in
            isLoading = false
            switch result {
            case .success(let loadedComments):
                self.relatedComments = loadedComments.filter { $0.commentId != comment.commentId }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func submitReply() {
        let parentDepth = replyingToId == nil ? 0 : (relatedComments.first(where: { $0.commentId == replyingToId })?.depth ?? 0)
        let newComment = ReadItComment(
            commentId: 0,
            userId: ReadItLoginUtil.shared.getSavedUsername(),
            parentCommentId: replyingToId,
            commentBody: comment.commentBody,
            author: ReadItLoginUtil.shared.getSavedUsername(),
            score: 0,
            time: String(Date().timeIntervalSince1970),
            body: replyText,
            depth: parentDepth + 1,
            stickied: false,
            directURL: comment.directURL,
            isCollapsed: false,
            isRootCollapsed: false
        )
        
        ReadItCommentService.shared.sendComment(comment: newComment) { result in
            switch result {
            case .success(let postedComment):
                print("Posted comment: \(postedComment)")
                DispatchQueue.main.async {
                    self.relatedComments.append(postedComment)
                }
            case .failure(let error):
                print("Failed to post comment: \(error.localizedDescription)")
                self.errorMessage = "댓글 게시에 실패했습니다: \(error.localizedDescription)"
            }
        }
        
        replyText = ""
        isReplying = false
    }
    
    // 댓글을 계층 구조로 정리하는 함수
    private func organizeComments(_ comments: [ReadItComment]) -> [CommentData] {
            var organized: [CommentData] = []
            var commentDict: [Int: CommentData] = [:]
            
            for comment in comments {
                let commentData = CommentData(comment: comment)
                commentDict[comment.commentId] = commentData
                
                if let parentId = comment.parentCommentId, let parent = commentDict[parentId] {
                    parent.children.append(commentData)
                } else {
                    organized.append(commentData)
                }
            }
            
            return flattenComments(organized)
        }
    
    // 계층 구조의 댓글을 평탄화하는 함수
    private func flattenComments(_ comments: [CommentData]) -> [CommentData] {
            var flattened: [CommentData] = []
            
            for comment in comments {
                flattened.append(comment)
                flattened.append(contentsOf: flattenComments(comment.children))
            }
            
            return flattened
        }
    }

// 댓글 데이터를 저장하는 구조체
class CommentData: Identifiable {
    let id: Int
    let comment: ReadItComment
    var depth: Int
    var children: [CommentData] = []

    init(comment: ReadItComment) {
        self.id = comment.commentId
        self.comment = comment
        self.depth = comment.depth
    }
}
