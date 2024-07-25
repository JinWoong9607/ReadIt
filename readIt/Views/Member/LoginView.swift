//
//  LoginView.swift
//  readIt
//
//  Created by 진웅홍 on 7/18/24.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var utils : ReadItLoginUtil
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
                Button("Log In") {
                    performLogin()
                }
                NavigationLink(destination: SignUpView()) {
                    Text("Sign up")
                }
            }
        }
    }
    
    private func performLogin() {
        if !InputValidator.isValidUsername(self.username) {
                errorMessage = "유효한 사용자 이름을 입력해주세요. (최소 3자)"
            } else if !InputValidator.isValidPassword(self.password) {
                errorMessage = "유효한 비밀번호를 입력해주세요. (최소 6자)"
            } else {
                errorMessage = nil
                
                utils.username = username
                utils.password = password
                utils.login { success in
                    DispatchQueueHelper.executeOnMainThread {
                        if success {
                            isAuthenticated = true
                            errorMessage = nil
                        } else {
                            isAuthenticated = false
                            errorMessage = "로그인에 실패했습니다"
                        }
                    }
                }
        }
    }
}
