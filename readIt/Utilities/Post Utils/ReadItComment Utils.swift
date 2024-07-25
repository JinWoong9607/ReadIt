//
//  ReadItComment Utils.swift
//  readIt
//
//  Created by 진웅홍 on 7/22/24.
//

import Foundation
import Alamofire
import Combine

struct ReadItComment: Equatable, Codable, Hashable {
    let id: String
    let parentID: String?
    let userId: String
    let author: String
    let score: Int
    let time: String
    let body: String
    let depth: Int
    let stickied: Bool
    let directURL: String
    var isCollapsed: Bool
    var isRootCollapsed: Bool

    enum CodingKeys: String, CodingKey {
        case id = "commentId"
        case parentID = "parentCommentId"
        case userId = "userId"
        case author = "author"
        case score = "score"
        case time = "time"
        case body = "body"
        case depth = "depth"
        case stickied = "stickied"
        case directURL = "directURL"
        case isCollapsed = "isCollapsed"
        case isRootCollapsed = "isRootCollapsed"
    }
}

struct CommentResponse: Decodable {
    let success: Bool
    let message: String
    let comment: ReadItComment
}

class ReadItCommentService {
    static let shared = ReadItCommentService()
    private let baseURL = "http://localhost:3000"
    
    private init() {}
    
    func sendComment(comment: ReadItComment, completion: @escaping (Result<ReadItComment, Error>) -> Void) {
        let endpoint = "\(baseURL)/dictionary/create"
        
        AF.request(endpoint, method: .post, parameters: comment, encoder: JSONParameterEncoder.default)
            .validate()
            .responseDecodable(of: CommentResponse.self) { response in
                switch response.result {
                case .success(let commentResponse):
                    if commentResponse.success {
                        completion(.success(commentResponse.comment))
                    } else {
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: commentResponse.message])))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
}
