//
//  ReadItComment Utils.swift
//  readIt
//
//  Created by 진웅홍 on 7/22/24.
//

import Foundation
import Alamofire
import Combine

struct ReadItComment: Equatable, Codable, Hashable, Identifiable {
    let commentId: Int
    let userId: String
    let parentCommentId: Int?
    let commentBody: String
    let author: String
    let score: Int
    let time: String
    let body: String
    var depth: Int
    let stickied: Bool
    let directURL: String
    var isCollapsed: Bool
    var isRootCollapsed: Bool
    
    var id: Int { commentId }

    enum CodingKeys: String, CodingKey {
        case commentId, userId, parentCommentId, commentBody, author, score, time, body, depth, stickied, directURL, isCollapsed, isRootCollapsed
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
        
        guard let token = LoginService.shared.getToken() else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authentication token found"])))
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let endpoint = "\(baseURL)/comment/create"
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        print("Sending comment: \(comment)")
        
        AF.request(endpoint, method: .post, parameters: comment, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseDecodable(of: CommentResponse.self, decoder: decoder) { response in
                print("Response: \(response)")
                switch response.result {
                case .success(let commentResponse):
                    if commentResponse.success {
                        completion(.success(commentResponse.comment))
                    } else {
                        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: commentResponse.message])))
                    }
                case .failure(let error):
                    print(error)
                    completion(.failure(error))
                }
            }
    }
    
    func sendReply(parentComment: ReadItComment, reply: ReadItComment, completion: @escaping (Result<ReadItComment, Error>) -> Void) {
        guard let token = LoginService.shared.getToken() else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authentication token found"])))
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let endpoint = "\(baseURL)/comment/create"
        
        let headers: HTTPHeaders = [
            "Authorization" : "Bearer \(token)",
            "Content-Type" : "application/json"
        ]
        
        var replyWithUpdatedDepth = reply
        replyWithUpdatedDepth.depth = parentComment.depth + 1
        
        AF.request(endpoint, method: .post, parameters: replyWithUpdatedDepth, encoder: JSONParameterEncoder.default, headers: headers)
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
                    print(error)
                    completion(.failure(error))
                }
            }
    }
    
    func getComments(for directURL: String, completion: @escaping (Result<[ReadItComment], Error>) -> Void) {
        guard let token = LoginService.shared.getToken() else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authentication token found"])))
            return
        }
        
        let endpoint = "\(baseURL)/comment/read/\(directURL)"
        
        let headers: HTTPHeaders = [
            "Authorization" : "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        AF.request(endpoint, method: .get, headers: headers)
            .validate()
            .responseDecodable(of: [ReadItComment].self) { response in
                switch response.result {
                case .success(let comments):
                    completion(.success(comments))
                case .failure(let error):
                    if let data = response.data, let str = String(data: data, encoding: .utf8) {
                        print("Server Error Response: \(str)")
                    }
                    if let statusCode = response.response?.statusCode, statusCode == 404 {
                        completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "댓글이 없습니다. 첫 댓글을 작성해보세요."])))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
    }
    
    func getUserComments(for userId: String, completion: @escaping (Result<[ReadItComment], Error>) -> Void) {
        guard let token = LoginService.shared.getToken() else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authentication token found"])))
            return
        }
        
        let endpoint = "\(baseURL)/comment/user/\(userId)"
        
        let headers: HTTPHeaders = [
            "Authorization" : "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        AF.request(endpoint, method: .get, headers: headers)
            .validate()
            .responseDecodable(of: [ReadItComment].self) { response in
                switch response.result {
                case .success(let comments):
                    completion(.success(comments))
                case .failure(let error):
                    if let data = response.data, let str = String(data: data, encoding: .utf8) {
                        print("Server Error Response: \(str)")
                    }
                    if let statusCode = response.response?.statusCode, statusCode == 404 {
                        completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "댓글이 없습니다. 첫 댓글을 작성해보세요."])))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        
    }
    
    func getCommentsByBody(_ commentBody: String, completion: @escaping (Result<[ReadItComment], Error>) -> Void) {
        guard let token = LoginService.shared.getToken() else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authentication token found"])))
            return
        }
        
        guard let encodedCommentBody = commentBody.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode comment body"])))
            return
        }
        
        let endpoint = "\(baseURL)/comment/comment/\(encodedCommentBody)"
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        AF.request(endpoint, method: .get, headers: headers)
            .validate()
            .responseDecodable(of: [ReadItComment].self) { response in
                switch response.result {
                case .success(let comments):
                    completion(.success(comments))
                case .failure(let error):
                    if let data = response.data, let str = String(data: data, encoding: .utf8) {
                        print("Server Error Response: \(str)")
                    }
                    if let statusCode = response.response?.statusCode, statusCode == 404 {
                        completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "댓글이 없습니다. 첫 댓글을 작성해보세요."])))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
    }
}

extension ReadItComment {
    init(from comment: Comment) {
        self.init(
            commentId: Int(comment.id) ?? 0,
            userId: comment.author,
            parentCommentId: comment.parentID != nil ? Int(comment.parentID!) : nil,
            commentBody: comment.body,
            author: comment.author,
            score: Int(comment.score) ?? 0,
            time: String(Date().timeIntervalSince1970),
            body: comment.body,
            depth: comment.depth,
            stickied: false,
            directURL: comment.directURL,
            isCollapsed: false,
            isRootCollapsed: false
        )
    }
}
