//
//  CommentView.swift
//  OpenArtemis
//
//  Created by Ethan Bills on 12/3/23.
//
import SwiftUI
import MarkdownUI
import Defaults

struct CommentView: View {
    @EnvironmentObject var coordinator: NavCoordinator
    
    let comment: Comment
    let numberOfChildren: Int
    let postAuthor: String?
    let appTheme: AppThemeSettings
    let textSizePreference: TextSizePreference
    
    let onCommentSelected: (Comment) -> Void
    @State private var isSelected: Bool = false
    
    init(comment: Comment,
         numberOfChildren: Int,
         postAuthor: String? = nil,
         appTheme: AppThemeSettings,
         textSizePreference: TextSizePreference,
         onCommentSelected: @escaping (Comment) -> Void) {
        
        self.comment = comment
        self.numberOfChildren = numberOfChildren
        self.postAuthor = postAuthor
        self.appTheme = appTheme
        self.textSizePreference = textSizePreference
        self.onCommentSelected = onCommentSelected
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            commentContent
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .themedBackground(appTheme: appTheme)
    }
    
    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                if comment.depth > 0 {
                    Rectangle()
                        .fill(CommentUtils.shared.commentIndentationColor(forDepth: comment.depth))
                        .frame(width: 2)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    commentHeader
                    commentBody
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring()) {
                isSelected = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSelected = false
                onCommentSelected(comment)
            }
        }
    }
    
    private var commentHeader: some View {
        HStack(spacing: 4) {
            DetailTagView(icon: "person", data: comment.author.isEmpty ? "[deleted]" : comment.author, appTheme: appTheme, textSizePreference: textSizePreference) {
                coordinator.path.append(ProfileResponse(username: comment.author))
            }
            .foregroundColor(commentAuthorColor)
            
            DetailTagView(icon: "timer", data: TimeFormatUtil().formatTimeAgo(fromUTCString: comment.time), appTheme: appTheme, textSizePreference: textSizePreference)
            
            Spacer()
            DetailTagView(icon: "arrow.up", data: Int(comment.score)?.roundedWithAbbreviations ?? "[score hidden]", appTheme: appTheme, textSizePreference: textSizePreference)
        }
        .foregroundStyle(appTheme.tagBackground ? .primary : .secondary)
    }
    
    private var commentBody: some View {
        Markdown(comment.body.isEmpty ? "[deleted]" : comment.body)
            .markdownTheme(.readItMarkdown(fontSize: textSizePreference.bodyFontSize))
    }
    
    private var commentAuthorColor: Color {
        if let author = postAuthor, comment.author == author {
            return Color.accentColor
        } else {
            return appTheme.tagBackground ? .primary : .secondary
        }
    }
}
