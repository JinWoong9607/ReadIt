//
//  UrbanDictionaryService.swift
//  readIt
//
//  Created by 진웅홍 on 7/17/24.
//

import Foundation
import Alamofire

class UrbanDictionaryService {
    func fetchDefinition(for term: String, completion: @escaping (Result<UrbanDictionaryResponse, Error>) -> Void) {
        let url = "https://urban-dictionary7.p.rapidapi.com/v0/define"
        let parameters: [String: String] = ["term": term]
        let headers: HTTPHeaders = [
            "x-rapidapi-key": "0e10d28b61mshdcbb5c6a5244c1bp11bb9fjsn0ec461d9e8da",
            "x-rapidapi-host": "urban-dictionary7.p.rapidapi.com"
        ]

        AF.request(url, method: .get, parameters: parameters, headers: headers)
            .validate()
            .responseDecodable(of: UrbanDictionaryResponse.self) { response in
                switch response.result {
                case .success(let responseData):
                    completion(.success(responseData))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
}
