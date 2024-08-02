//
//  CommentView.swift
//  OpenArtemis
//
//  Created by Ethan Bills on 12/3/23.
//
import SwiftUI
import MarkdownUI
import Defaults
import Combine

struct CommentView: View {
    @EnvironmentObject var coordinator: NavCoordinator
    
    let comment: Comment
    let numberOfChildren: Int
    let postAuthor: String?
    let appTheme: AppThemeSettings
    let textSizePreference: TextSizePreference
    let isHighlighted: Bool
    
    let onCommentSelected: (Comment) -> Void
    @State private var isSelected: Bool = false
    @State private var showTranslation = false
    @State private var translatedText: String = ""
    @State private var translationError: String = ""
    @State private var readItCommentCount: Int = 0
    
    @State private var showCommentTranslator = false
    @State private var selectedText = ""
    
    @State private var showCommunityDetail = false
    
    init(comment: Comment,
         numberOfChildren: Int,
         postAuthor: String? = nil,
         appTheme: AppThemeSettings,
         textSizePreference: TextSizePreference,
         onCommentSelected: @escaping (Comment) -> Void,
         isHighlighted: Bool = false) {
        
        self.comment = comment
        self.numberOfChildren = numberOfChildren
        self.postAuthor = postAuthor
        self.appTheme = appTheme
        self.textSizePreference = textSizePreference
        self.onCommentSelected = onCommentSelected
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                commentContent
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(isHighlighted ? Color.yellow.opacity(0.3) : Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color(.systemGray4), radius: 5, x: 0, y: 2)
            .sheet(isPresented: $showCommentTranslator) {
                CommentTranslator(selectedComment: $selectedText)
            }
            
            if showCommunityDetail {
                CommunityDetailView(comment: ReadItComment(from: comment), appTheme: appTheme, textSizePreference: textSizePreference)
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: showCommunityDetail)
        
    }
        
    private var commentContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                if comment.depth > 0 {
                    Rectangle()
                        .fill(CommentUtils.shared.commentIndentationColor(forDepth: comment.depth))
                        .frame(width: 3)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    commentHeader
                    commentBody
                    commentActions
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
        HStack {
            authorView
            Spacer()
            scoreView
        }
    }
    
    private var authorView: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.circle.fill")
                .foregroundColor(commentAuthorColor)
            Text(comment.author.isEmpty ? "[deleted]" : comment.author)
                .font(.subheadline)
                .foregroundColor(commentAuthorColor)
            Text("•")
                .foregroundColor(.secondary)
            Text(TimeFormatUtil().formatTimeAgo(fromUTCString: comment.time))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onTapGesture {
            coordinator.path.append(ProfileResponse(username: comment.author))
        }
    }
    
    private var scoreView: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up")
            Text(Int(comment.score)?.roundedWithAbbreviations ?? "[hidden]")
        }
        .font(.footnote)
        .foregroundColor(.secondary)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var commentBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Markdown(comment.body.isEmpty ? "[deleted]" : comment.body)
                .markdownTheme(.gitHub)
            
            HStack {
                Text("\(readItCommentCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
                Spacer()
            }
            
            if showTranslation {
                translationView
            }
        }
        .onAppear {
            fetchReadItCommentCount()
        }
    }
    
    private var commentActions: some View {
        HStack {
            Spacer()

            Button(action: {
                withAnimation {
                    showCommunityDetail.toggle()
                }
            }) {
                Image(systemName: "bubble.left.and.bubble.right")
                Text("댓글 보기")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Toggle(isOn: $showTranslation) {
                Label("Translate", systemImage: "globe")
            }
            .toggleStyle(.button)
            .controlSize(.small)
        }
    }
    
    private var translationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !translatedText.isEmpty {
                Text(translatedText)
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else if !translationError.isEmpty {
                Text(translationError)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .animation(.easeInOut, value: showTranslation)
        .transition(.opacity)
        .onAppear {
            if translatedText.isEmpty && translationError.isEmpty {
                translateComment()
            }
        }
    }
    
    private func translateComment() {
        TranslationService.translateComment(comment: comment.body) { translated, error, show in
            self.translatedText = translated
            self.translationError = error
            self.showTranslation = show
        }
    }
    
    private func fetchReadItCommentCount() {
        print("Fetching ReadItComments for body: \(comment.body)")
        ReadItCommentService.shared.getCommentsByBody(comment.body) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let readItComments):
                    self.readItCommentCount = readItComments.count
                    print("Number of ReadItComments: \(self.readItCommentCount)")
                case .failure(let error):
                    print("Failed to fetch ReadItComments: \(error.localizedDescription)")
                    self.readItCommentCount = 0
                }
            }
        }
    }
    
    private var commentAuthorColor: Color {
        if let author = postAuthor, comment.author == author {
            return .blue
        } else {
            return .primary
        }
    }
}
