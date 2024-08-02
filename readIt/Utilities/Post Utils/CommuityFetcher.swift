//
//  CommuityFetcher.swift
//  readIt
//
//  Created by 진웅홍 on 8/1/24.
//

import Foundation
import SwiftUI

class PostInfoFetcher: ObservableObject {
    @Published private(set) var postCards: [PostCard] = []
    
    private var cache: [String: (title: String, author: String)] = [:]
    private let queue = DispatchQueue(label: "com.yourapp.postInfoFetcher", attributes: .concurrent)
    private let semaphore = DispatchSemaphore(value: 1) // 동시에 최대 1개의 요청만 허용

    func fetchPostInfo(for comments: [ReadItComment]) {
        var newPostCards: [PostCard] = []
        let group = DispatchGroup()

        for comment in comments {
            group.enter()
            fetchPostInfoWithRetry(comment: comment, retryCount: 3, delay: 1) { result in
                defer { group.leave() }
                switch result {
                case .success(let info):
                    let card = PostCard(id: comment.commentId, title: info.title, author: info.author, comment: comment)
                    self.queue.async(flags: .barrier) {
                        newPostCards.append(card)
                    }
                case .failure(let error):
                    print("Failed to fetch post info for comment \(comment.commentId): \(error)")
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.postCards = newPostCards.sorted { $0.comment.time > $1.comment.time }
        }
    }

    private func fetchPostInfoWithRetry(comment: ReadItComment, retryCount: Int, delay: TimeInterval, completion: @escaping (Result<(title: String, author: String), Error>) -> Void) {
        semaphore.wait()
        
        if let cachedInfo = cache[comment.directURL] {
            semaphore.signal()
            completion(.success(cachedInfo))
            return
        }

        let timeoutWorkItem = DispatchWorkItem {
            print("Timeout occurred for comment \(comment.commentId)")
            self.semaphore.signal()
            let error = NSError(domain: "fetchPostInfoWithRetry", code: -2, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])
            completion(.failure(error))
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 30.0, execute: timeoutWorkItem)

        RedditScraper.scrapePostTitleAndAuthorFromURL(url: comment.directURL) { [weak self] result in
            timeoutWorkItem.cancel()
            self?.semaphore.signal()

            switch result {
            case .success(let info):
                print("Successfully scraped post title and author from URL: \(comment.directURL)")
                self?.cache[comment.directURL] = info
                completion(.success(info))
            case .failure(let error):
                print("Error fetching post info for comment \(comment.commentId): \(error)")
                if retryCount > 1 {
                    let newDelay = min(delay * 2, 10) // 최대 10초까지 지수 백오프
                    DispatchQueue.global().asyncAfter(deadline: .now() + newDelay) {
                        self?.fetchPostInfoWithRetry(comment: comment, retryCount: retryCount - 1, delay: newDelay, completion: completion)
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
}
