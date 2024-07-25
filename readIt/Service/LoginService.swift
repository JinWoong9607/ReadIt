//
//  MakeTranslatorService.swift
//  readIt
//
//  Created by 진웅홍 on 7/18/24.
//

import Foundation
import Alamofire
import Combine
import SwiftSoup

protocol LoginProtocol {
    func login(username: String, password: String, completion: @escaping (Result<String, Error>) -> Void)
}

class LoginService {
    static let shared = LoginService()
    let tokenKey = "token"
    
    func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    func getToken()->String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }
    
    func isLoggedIn() -> Bool {
        getToken() != nil
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    func login(username: String, password: String) -> AnyPublisher<LoginResponse, AFError> {
        let url = "http://localhost:3000/user/sign-in"
        let parameters = loginRequest(username: username, password: password)
        
        return Future<LoginResponse, AFError> { promise in
            AF.request(url, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default).responseDecodable(of:LoginResponse.self) { response in
                switch response.result {
                case.success(let result):
                    promise(.success(result))
                case.failure(let error):
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    func register(username: String, password: String) -> AnyPublisher<RegisterResponse, AFError> {
        let url = "http://localhost:3000/user/signup"
        let parameters = ["username": username, "password": password]
        let headers = HTTPHeaders(["Content-Type": "application/json"])
        
        return AF.request(url, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default, headers: headers)
            .publishDecodable(type: RegisterResponse.self)
            .value()
            .eraseToAnyPublisher()
    }}

struct Token: Codable {
    let jwt: String
}
