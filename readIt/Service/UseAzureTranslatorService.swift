//
//  UseAzureTranslator.swift
//  readIt
//
//  Created by 진웅홍 on 7/31/24.
//

import Foundation
import Alamofire

struct TranslationRequest: Encodable {
    let message: String
}

struct ApiResponse: Decodable {
    let choices: [Choice]
    let created: Int
    let id: String
    let model: String
    let object: String
    let systemFingerprint: String
    let usage: Usage
    
    enum CodingKeys: String, CodingKey {
        case choices, created, id, model, object
        case systemFingerprint = "system_fingerprint"
        case usage
    }
}

struct Choice: Decodable {
    let contentFilterResults: ContentFilterResults
    let finishReason: String
    let index: Int
    let message: Message
    
    enum CodingKeys: String, CodingKey {
        case contentFilterResults = "content_filter_results"
        case finishReason = "finish_reason"
        case index, message
    }
}

struct ContentFilterResults: Decodable {
    let hate, selfHarm, sexual, violence: FilterDetail
    
    enum CodingKeys: String, CodingKey {
        case hate
        case selfHarm = "self_harm"
        case sexual, violence
    }
}

struct FilterDetail: Decodable {
    let filtered: Bool
    let severity: String
}

struct Message: Decodable {
    let content: String
    let role: String
}

struct Usage: Decodable {
    let completionTokens: Int
    let promptTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case completionTokens = "completion_tokens"
        case promptTokens = "prompt_tokens"
        case totalTokens = "total_tokens"
    }
}

class TranslationService {
    static func sendTranslationRequest(message: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = "http://localhost:3000/translate/"
        let parameters = TranslationRequest(message: message)

        print("Sending request to URL: \(url)")
        print("Request parameters: \(parameters)")

        AF.request(url, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default)
            .responseDecodable(of: ApiResponse.self) { response in
                print("Response status code: \(response.response?.statusCode ?? -1)")
                
                if let data = response.data, let str = String(data: data, encoding: .utf8) {
                    print("Raw response data: \(str)")
                }
                
                switch response.result {
                case .success(let apiResponse):
                    print("API Response: \(apiResponse)")
                    if let firstChoice = apiResponse.choices.first {
                        let content = firstChoice.message.content
                        print("Translated content: \(content)")
                        completion(.success(content))
                    } else {
                        let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data available"])
                        print("Error: No data available in API response")
                        completion(.failure(error))
                    }
                case .failure(let error):
                    print("Alamofire error: \(error.localizedDescription)")
                    if let underlyingError = error.underlyingError {
                        print("Underlying error: \(underlyingError)")
                    }
                    completion(.failure(error))
                }
            }
    }
    
    static func translateComment(comment: String, completion: @escaping (String, String, Bool) -> Void) {
        print("Translating comment: \(comment)")
        sendTranslationRequest(message: comment) { result in
            switch result {
            case .success(let translation):
                print("Translation successful: \(translation)")
                completion(translation, "", true)
            case .failure(let error):
                print("Translation failed: \(error.localizedDescription)")
                completion("", "번역 실패: 민감하거나 유해한 내용이 감지되었습니다.", true)
            }
        }
    }
}
