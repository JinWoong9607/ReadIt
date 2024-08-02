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
    @Environment(\.managedObjectContext) var managedObjectContext
    
    let appTheme: AppThemeSettings
    let textSizePreference: TextSizePreference
    @State private var comments: [ReadItComment] = []
    @State private var postCards: [PostCard] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCardLoading = false
    @State private var selectedCardId: Int?
    
    let userId: String
    
    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            
            VStack {
                headerView
                
                if isLoading {
                    loadingView
                } else if !postCards.isEmpty {
                    postCardListView
                } else {
                    emptyStateView
                }
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
    
    private var headerView: some View {
        Text("@\(userId)의 댓글")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .padding()
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("댓글을 불러오는 중...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
            Text("아직 댓글이 없습니다.")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var postCardListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(postCards, id: \.id) { card in
                    PostCardView(
                        card: card,
                        appTheme: appTheme,
                        textSizePreference: textSizePreference,
                        isLoading: isCardLoading && card.id == selectedCardId,
                        onTap: {
                            self.selectedCardId = card.id
                            self.isCardLoading = true
                            print("Card tapped: \(card.id)")
                            let modifiedURL = modifyURL(card.comment.directURL)
                            print("Modified URL: \(modifiedURL)")
                            fetchPostAndNavigate(for: card)
                        }
                    )
                }
            }
            .padding()
        }
    }

    private func modifyURL(_ url: String) -> String {
        let components = url.components(separatedBy: "/")
        guard components.count >= 7 else {
            print("Invalid URL format")
            return url
        }
        
        // subreddit과 post ID를 포함한 URL 생성
        let modifiedComponents = components.prefix(7)
        let modifiedURL = modifiedComponents.joined(separator: "/")
        print("Original URL: \(url)")
        print("Modified URL: \(modifiedURL)")
        return modifiedURL
    }

    private func fetchPostAndNavigate(for card: PostCard) {
            let modifiedURL = modifyURL(card.comment.directURL)
            print("Fetching post info for URL: \(modifiedURL)")
            
            RedditScraper.scrapePostFromURL(url: modifiedURL) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let post):
                        print("Successfully fetched post: title='\(post.title)', author='\(post.author)'")
                        coordinator.path.append(PostResponse(post: post))
                    case .failure(let error):
                        print("Error fetching post: \(error)")
                        self.errorMessage = "포스트 정보를 가져오는 데 실패했습니다: \(error.localizedDescription)"
                    }
                }
            }
        }
    
    private func loadComments() {
        isLoading = true
        ReadItCommentService.shared.getUserComments(for: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loadedComments):
                    self.comments = loadedComments
                    self.fetchPostInfo(for: loadedComments)
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func fetchPostInfo(for comments: [ReadItComment]) {
            print("Starting to fetch post info for \(comments.count) comments")
            let group = DispatchGroup()
            var cards: [PostCard] = []
            var _: [String: ReadItComment] = [:]
            let queue = DispatchQueue(label: "com.fetchPostInfo", attributes: .concurrent)
            let semaphore = DispatchSemaphore(value: 10) // 동시에 최대 10개의 요청 처리

            for comment in comments {
                group.enter()
                queue.async {
                    semaphore.wait()
                    self.fetchPostInfoWithRetry(comment: comment, retryCount: 3) { result in
                        defer {
                            semaphore.signal()
                            group.leave()
                        }
                        
                        let baseURL = comment.directURL.components(separatedBy: "/")[0..<6].joined(separator: "/")
                        
                        switch result {
                        case .success(let info):
                            let card = PostCard(id: comment.commentId, title: info.title, author: info.author, comment: comment)
                            DispatchQueue.main.async {
                                if let existingIndex = cards.firstIndex(where: { $0.comment.directURL.hasPrefix(baseURL) }) {
                                    if Double(comment.time) ?? 0 > Double(cards[existingIndex].comment.time) ?? 0 {
                                        cards[existingIndex] = card
                                    }
                                } else {
                                    cards.append(card)
                                }
                            }
                            print("Successfully created/updated card for comment \(comment.commentId)")
                        case .failure(let error):
                            print("Error fetching post info for comment \(comment.commentId): \(error)")
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.postCards = cards.sorted(by: { $0.comment.time > $1.comment.time })
                self.isLoading = false
                print("Finished fetching post info. Retrieved \(cards.count) cards out of \(comments.count) comments. isLoading set to false.")
            }
        }
    private func fetchPostInfoWithRetry(comment: ReadItComment, retryCount: Int, completion: @escaping (Result<(title: String, author: String), Error>) -> Void) {
        guard retryCount > 0 else {
            print("Maximum retry attempts reached for comment \(comment.commentId)")
            completion(.failure(NSError(domain: "fetchPostInfoWithRetry", code: -1, userInfo: [NSLocalizedDescriptionKey: "Maximum retry attempts reached"])))
            return
        }
        
        print("Attempting to scrape post title and author from URL: \(comment.directURL) with \(retryCount) retries left")
        RedditScraper.scrapePostTitleAndAuthorFromURL(url: comment.directURL) { result in
            switch result {
            case .success(let info):
                print("Successfully scraped post title and author from URL: \(comment.directURL)")
                completion(.success(info))
            case .failure(let error):
                if retryCount - 1 > 0 {
                    print("Error fetching post info for comment \(comment.commentId): \(error). Retries left: \(retryCount - 1)")
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self.fetchPostInfoWithRetry(comment: comment, retryCount: retryCount - 1, completion: completion)
                    }
                } else {
                    print("Final attempt failed for comment \(comment.commentId): \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
}

struct PostCard: Identifiable {
    let id: Int
    let title: String
    let author: String
    let comment: ReadItComment
}

struct PostCardView: View {
    let card: PostCard
    let appTheme: AppThemeSettings
    let textSizePreference: TextSizePreference
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title)
                    .font(.system(size: textSizePreference.titleFontSize, weight: .bold))
                    .lineLimit(2)
                    .padding(.bottom, 4)
                
                Text(card.comment.body)
                    .font(.system(size: textSizePreference.bodyFontSize))
                    .lineLimit(3)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(card.author)
                        .font(.system(size: textSizePreference.captionFontSize, weight: .semibold))
                    Spacer()
                    Text(TimeFormatUtil().readItTimeUtil(fromTimeInterval: Double(card.comment.time) ?? 0))
                        .font(.system(size: textSizePreference.captionFontSize))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .opacity(isLoading ? 0.5 : 1)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .onTapGesture {
            onTap()
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

class PostInfoCache {
    static let shared = PostInfoCache()
    private var cache: [String: (title: String, author: String)] = [:]
    
    private init() {}
    
    func getInfo(for url: String) -> (title: String, author: String)? {
        return cache[url]
    }
    
    func setInfo(for url: String, info: (title: String, author: String)) {
        cache[url] = info
    }
}

struct CommentViewResponse: Hashable {
    let comment: Comment
    let numberOfChildren: Int
    let postAuthor: String
    let postTitle: String
}
