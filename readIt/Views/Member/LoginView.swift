//
//  LoginView.swift
//  readIt
//
//  Created by 진웅홍 on 7/18/24.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var utils: ReadItLoginUtil
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @Binding var isAuthenticated: Bool
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("ReadIt")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(.bottom, 30)
                    
                    VStack(spacing: 20) {
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: performLogin) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Log In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .disabled(isLoading)
                        
                        NavigationLink(destination: SignUpView()) {
                            Text("Don't have an account? Sign up")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func performLogin() {
        isLoading = true
        errorMessage = nil
        
        if !InputValidator.isValidUsername(self.username) {
            errorMessage = "유효한 사용자 이름을 입력해주세요. (최소 3자)"
            isLoading = false
        } else if !InputValidator.isValidPassword(self.password) {
            errorMessage = "유효한 비밀번호를 입력해주세요. (최소 6자)"
            isLoading = false
        } else {
            utils.username = username
            utils.password = password
            utils.login { success in
                DispatchQueueHelper.executeOnMainThread {
                    isLoading = false
                    if success {
                        isAuthenticated = true
                    } else {
                        isAuthenticated = false
                        errorMessage = "로그인에 실패했습니다"
                    }
                }
            }
        }
    }
}
