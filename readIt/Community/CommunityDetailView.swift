//
//  CommunityDetailView.swift
//  readIt
//
//  Created by 진웅홍 on 7/29/24.
//

import SwiftUI
import os

struct CommunityDetailView: View {
    let comment: ReadItComment
    let appTheme: AppThemeSettings
    let textSizePreference: TextSizePreference
    
    @State private var relatedComments: [ReadItComment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var replyText = ""
    @State private var isReplying = false
    @State private var replyingToId: Int?
    @State private var selectedLink: String?
    @State private var loadedPost: Post?
    @State private var isPostPagePresented = false
    
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CommunityDetailView")
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView()
                    } else if !relatedComments.isEmpty {
                        ForEach(organizeComments(relatedComments), id: \.id) { commentData in
                            commentView(comment: commentData.comment, isMainComment: false)
                                .padding(.leading, CGFloat(commentData.depth * 20))
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
            
            if isReplying {
                replyView
            } else {
                Button(action: {
                    isReplying = true
                    replyingToId = nil
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
        }
        .navigationBarTitle("관련 댓글", displayMode: .inline)
        .onAppear(perform: loadRelatedComments)
        .sheet(isPresented: $isPostPagePresented) {
            if let post = loadedPost {
                PostPageView(post: post, appTheme: appTheme, textSizePreference: textSizePreference)
            }
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
                .onTapGesture {
                    handleBodyTap(comment: comment)
                }
            
            HStack {
                Spacer()
                Button(action: {
                    isReplying = true
                    replyingToId = isMainComment ? comment.commentId : comment.parentCommentId ?? comment.commentId
                }) {
                    Image(systemName: "arrowshape.turn.up.left")
                    Text("답글")
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
            Button(action: { isReplying = false }) {
                Text("취소")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray)
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
                // 원본 댓글을 제외하고, 중복된 댓글도 제거합니다.
                self.relatedComments = loadedComments
                    .filter { $0.commentId != self.comment.commentId }
                    .reduce(into: [ReadItComment]()) { result, comment in
                        if !result.contains(where: { $0.commentId == comment.commentId }) {
                            result.append(comment)
                        }
                    }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func submitReply() {
        let isTopLevelComment = replyingToId == nil
        let parentComment = isTopLevelComment ? nil : (relatedComments.first(where: { $0.commentId == replyingToId }))
        
        let newComment = ReadItComment(
            commentId: 0,
            userId: ReadItLoginUtil.shared.getSavedUsername(),
            parentCommentId: isTopLevelComment ? nil : replyingToId,
            commentBody: comment.commentBody,
            author: ReadItLoginUtil.shared.getSavedUsername(),
            score: 0,
            time: String(Date().timeIntervalSince1970),
            body: replyText,
            depth: isTopLevelComment ? 0 : (parentComment?.depth ?? 0) + 1,
            stickied: false,
            directURL: comment.directURL,
            isCollapsed: false,
            isRootCollapsed: false
        )
        
        ReadItCommentService.shared.sendComment(comment: newComment) { result in
            switch result {
            case .success(let postedComment):
                logger.info("댓글 게시 성공: commentId=\(postedComment.commentId), isTopLevelComment=\(isTopLevelComment)")
                
                DispatchQueue.main.async {
                    self.relatedComments.append(postedComment)
                    self.sortAndUpdateComments()
                    self.replyingToId = nil
                }
            case .failure(let error):
                logger.error("댓글 게시 실패: error=\(error.localizedDescription)")
                self.errorMessage = "댓글 게시에 실패했습니다: \(error.localizedDescription)"
            }
        }
        
        replyText = ""
        isReplying = false
        replyingToId = nil
    }
    
    private func sortAndUpdateComments() {
        relatedComments.sort { (comment1, comment2) -> Bool in
            if comment1.depth == comment2.depth {
                return (Double(comment1.time) ?? 0) < (Double(comment2.time) ?? 0)
            }
            return comment1.depth < comment2.depth
        }
    }
    
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
    
    private func flattenComments(_ comments: [CommentData]) -> [CommentData] {
        var flattened: [CommentData] = []
        
        for comment in comments {
            flattened.append(comment)
            flattened.append(contentsOf: flattenComments(comment.children))
        }
        
        return flattened
    }
    
    private func handleBodyTap(comment: ReadItComment) {
        let originalLink = comment.directURL
        logger.info("댓글 탭됨: commentId=\(comment.commentId), link=\(originalLink)")
        loadPostFromURL(url: originalLink)
    }
    
    private func loadPostFromURL(url: String) {
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let validURL = URL(string: encodedURL) else {
            logger.error("유효하지 않은 URL: \(url)")
            self.errorMessage = "유효하지 않은 URL입니다."
            return
        }
        
        isLoading = true
        logger.info("포스트 로딩 시작: url=\(validURL.absoluteString)")
        
        RedditScraper.scrapePostFromURL(url: validURL.absoluteString) { result in
            isLoading = false
            switch result {
            case .success(let post):
                self.loadedPost = post
                self.isPostPagePresented = true
                logger.info("포스트 로딩 성공: postId=\(post.id)")
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                logger.error("포스트 로딩 실패: error=\(error.localizedDescription)")
            }
        }
    }
}

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
