//
//  BeerStatsTextField.swift
//  BeerStats
//
//  Wiederverwendbares Eingabefeld, damit jedes Formular in der App
//  (Login, Registrierung, später z. B. Profil bearbeiten) exakt gleich
//  aussieht, statt dass jede View ihr eigenes TextField-Styling erfindet.
//

import SwiftUI

struct BeerStatsTextField: View {

    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: placeholderText)
            } else {
                TextField("", text: $text, prompt: placeholderText)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(keyboardType == .emailAddress)
            }
        }
        .font(BeerStatsFont.body)
        .foregroundStyle(BeerStatsColor.textPrimary)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(BeerStatsColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var placeholderText: Text {
        Text(placeholder).foregroundColor(BeerStatsColor.textSecondary)
    }
}

#Preview {
    VStack(spacing: 12) {
        BeerStatsTextField(placeholder: "E-Mail", text: .constant(""))
        BeerStatsTextField(placeholder: "Passwort", text: .constant(""), isSecure: true)
    }
    .padding()
    .background(BeerStatsColor.backgroundPrimary)
}
