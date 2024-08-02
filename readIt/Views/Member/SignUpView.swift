//
//  SignUpView.swift
//  readIt
//
//  Created by 진웅홍 on 7/19/24.
//

import SwiftUI

struct SignUpView: View {
    @ObservedObject var signUp = ReadItLoginUtil()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 20)
                    VStack(spacing: 16) {
                        customTextField("ID", text: $signUp.username, icon: "person.fill")
                        customSecureField("비밀번호", text: $signUp.password, icon: "lock.fill")
                        customSecureField("비밀번호 확인", text: $signUp.confirmPassword, icon: "lock.rotation")
                    }
                    .padding(.horizontal, 30)

                    if let formErrorMessage = signUp.formErrorMessage {
                        Text(formErrorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                    }

                    Button(action: {
                        signUp.performSignUp()
                        if signUp.isFormValid() {
                            dismiss()
                        }
                    }) {
                        Text("회원가입 완료")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(signUp.isFormValid() ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .padding(.horizontal, 30)
                    }
                    .disabled(!signUp.isFormValid())
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("회원가입")
            .padding(.horizontal, 10)
        }
    }
    
    @ViewBuilder
    private func customTextField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            TextField(placeholder, text: text)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func customSecureField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            SecureField(placeholder, text: text)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}
