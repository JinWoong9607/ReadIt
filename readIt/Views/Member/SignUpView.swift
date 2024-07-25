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
        Form {
            Section(header: Text("Id 설정")) {
                TextField("id", text: $signUp.username)
            }
            Section(header: Text("비밀번호 설정")) {
                SecureField("비밀번호", text: $signUp.password)
                SecureField("비밀번호 확인", text: $signUp.confirmPassword)
            }
            
            if let formErrorMessage = signUp.formErrorMessage {
                Text(formErrorMessage).foregroundStyle(Color.red)
            }
            
            Button("회원가입") {
                signUp.performSignUp()
                dismiss() // 현재 뷰 닫기
            }
            .disabled(!signUp.isFormValid())
        }
        .navigationBarTitle("회원가입", displayMode: .inline)
    }
}
