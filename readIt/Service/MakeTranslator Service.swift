//
//  MakeTranslator Utils.swift
//  readIt
//
//  Created by 진웅홍 on 7/22/24.
//

import Foundation
import Alamofire
import Combine

struct DictionaryLog : Codable {
    let userId : String
    let word : String
    let meaning : String
}

struct DictionaryRequest : Codable {
    let success : Bool
    let message : String
}

class DictionaryMaker {
    static let shared = DictionaryMaker()
    
    func makelog(_ dictionary: DictionaryLog) -> AnyPublisher<DictionaryRequest, AFError> {
        let url = "http://localhost:3000/Dictionary/log"
        guard let token = LoginService.shared.getToken() else {
            return Fail(error: AFError.explicitlyCancelled)
                .eraseToAnyPublisher()
        }
        
        let headers:HTTPHeaders = ["Authorization" : "Bearer \(token)"]
        print("Sending request to \(url) with data: \(dictionary)")
        
        return AF.request(url, method: .post, parameters: dictionary, encoder: JSONParameterEncoder.default, headers: headers)
            .publishDecodable(type: DictionaryRequest.self)
            .value()
            .map { response in
                            print("Received response: \(response)")
                            return response
                        }
                        .mapError { error in
                            print("Error occurred: \(error)")
                            return error as AFError
                        }
                        .eraseToAnyPublisher()
    }
}
