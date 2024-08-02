//
//  MakeTranslator Utils.swift
//  readIt
//
//  Created by 진웅홍 on 7/18/24.
//

import Foundation
import Combine

struct loginRequest: Codable {
    let username : String
    let password : String
}

struct LoginResponse: Codable {
    let success : Bool
    let token : String
    let message : String
}

struct RegisterResponse : Codable {
    let success : Bool
    let message : String
}

struct InputValidator {
    static func isValidUsername(_ username: String) -> Bool {
        return !username.isEmpty && username.count >= 3
    }
    
    static func isValidPassword(_ password: String) -> Bool {
        return !password.isEmpty && password.count >= 6
    }
}

struct ErrorMessageFormatter {
    static func message(for error: Error) -> String {
        let error = error as NSError
        switch error.code {
        case NSURLErrorNotConnectedToInternet:
            return "Internet connection appears to be offline."
        case 401:
            return "Invalid credentials provided."
        default:
            return "An unexpected error occurred. Please try again."
        }
    }
}


class ReadItLoginUtil : ObservableObject {
    
    static let shared = ReadItLoginUtil()
    
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var formErrorMessage: String?
    @Published var isLoggedIn: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        isLoggedIn = LoginService.shared.isLoggedIn()
    }
    func login(completion: @escaping (Bool) -> Void) {
        LoginService.shared.login(username: username, password: password)
            .sink { completion in
                switch completion {
                case .finished :
                    break;
                case .failure(let error):
                    print(error)
                }
            } receiveValue: { response in
                completion(response.success)
                if response.success {
                    LoginService.shared.saveToken(response.token)
                    self.saveUsername(self.username)
                }
            }.store(in: &cancellables)

    }
    func logout() {
        let auth = LoginService.shared
        auth.logout()
        isLoggedIn = auth.isLoggedIn()
        clearSavedUsername()
    }
    
    func isFormValid() -> Bool {
        return !(username.isEmpty || password.isEmpty || confirmPassword.isEmpty || password != confirmPassword)
    }
    
    
    func performSignUp() {
        if isFormValid() {
            LoginService.shared.register(username: username, password: password)
                .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self?.formErrorMessage = "회원가입 실패: \(error.localizedDescription)"
                        }
                    }
                }, receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        if response.success {
                            self?.isLoggedIn = true
                            self?.formErrorMessage = nil
                        } else {
                            self?.formErrorMessage = "회원가입 실패: \(response.message) "
                        }
                    }
                })
                .store(in: &cancellables)
        } else {
            formErrorMessage = "입력 폼이 유효하지 않습니다"
        }
    }
    
    private func saveUsername(_ username: String) {
        UserDefaults.standard.set(username, forKey: "savedUsername")
    }
    
    func getSavedUsername() -> String {
        return UserDefaults.standard.string(forKey: "savedUsername") ?? ""
    }
    
    private func clearSavedUsername() {
        UserDefaults.standard.removeObject(forKey: "savedUsername")
    }
}

struct DispatchQueueHelper {
    static func executeOnMainThread(_ work: @escaping () -> Void) {
        DispatchQueue.main.async {
            work()
        }
    }
}
