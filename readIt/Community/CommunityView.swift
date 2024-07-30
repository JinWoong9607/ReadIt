//
//  CommunityView.swift
//  readIt
//
//  Created by 진웅홍 on 7/26/24.
//

import SwiftUI
import Defaults

struct CommunityView: View {
    @EnvironmentObject var coordinator: NavCoordinator
    @Default(.over18) var over18
    
    let appTheme: AppThemeSettings
    let textSizePreference: TextSizePreference
    @State private var comments: [ReadItComment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let userId: String
    
    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if comments.isEmpty {
                Text("아직 댓글이 없습니다.")
                    .font(.system(size: 16))
            } else {
                List {
                    ForEach(comments, id: \.commentId) { comment in
                        commentView(for: comment)
                            .onTapGesture {
                                coordinator.path.append(CommunityResponse(comment: comment))
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationBarTitle("내 상위 댓글", displayMode: .inline)
        .onAppear(perform: loadComments)
        .alert(item: Binding(
            get: { errorMessage.map { ErrorWrapper(error: $0) } },
            set: { errorMessage = $0?.error }
        )) { wrapper in
            Alert(title: Text("오류"), message: Text(wrapper.error), dismissButton: .default(Text("확인")))
        }
    }
    
    private func commentView(for comment: ReadItComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(comment.author)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(TimeFormatUtil().readItTimeUtil(fromTimeInterval: Double(comment.time) ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(comment.body)
                .font(.body)
                .padding(.top, 4)
                .lineLimit(3)  // 미리보기에서는 3줄로 제한
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func loadComments() {
        isLoading = true
        ReadItCommentService.shared.getUserComments(for: userId) { result in
            isLoading = false
            switch result {
            case .success(let loadedComments):
                comments = loadedComments
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: String
}

struct CommunityResponse: Hashable {
    let comment: ReadItComment

    func hash(into hasher: inout Hasher) {
        hasher.combine(comment.commentId)
    }

    static func == (lhs: CommunityResponse, rhs: CommunityResponse) -> Bool {
        return lhs.comment.commentId == rhs.comment.commentId
    }
}
