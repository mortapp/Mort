import SwiftUI

struct MortTextField: View {
    let title: String
    @Binding var text: String
    var prompt: String = ""
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            Text(title).font(MortTypography.label).foregroundStyle(MortColors.textSoft)
            TextField(prompt, text: $text, axis: axis)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboardType == .emailAddress)
                .padding(MortSpacing.md)
                .background(MortColors.cardAlternate)
                .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
                .overlay(RoundedRectangle(cornerRadius: MortRadius.medium).stroke(MortColors.line))
        }
    }
}

struct MortSecureField: View {
    let title: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            Text(title).font(MortTypography.label).foregroundStyle(MortColors.textSoft)
            HStack {
                Group {
                    if isVisible { TextField("Password", text: $text) }
                    else { SecureField("Password", text: $text) }
                }
                .textContentType(.password)
                Button(isVisible ? "Hide" : "Show") { isVisible.toggle() }
                    .font(MortTypography.caption)
                    .foregroundStyle(MortColors.safetyBlue)
            }
            .padding(MortSpacing.md)
            .background(MortColors.cardAlternate)
            .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
            .overlay(RoundedRectangle(cornerRadius: MortRadius.medium).stroke(MortColors.line))
        }
    }
}

struct MortDateField: View {
    let title: String
    @Binding var text: String
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            MortTextField(title: title, text: Binding(
                get: { text },
                set: { text = DateOfBirthRules.formattedInput($0) }
            ), prompt: "MM/DD/YYYY", keyboardType: .numberPad, textContentType: .birthdate)
            DatePicker("Choose date", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .onChange(of: date) { _, value in
                    let formatter = DateFormatter()
                    formatter.calendar = Calendar(identifier: .gregorian)
                    formatter.dateFormat = "MM/dd/yyyy"
                    text = formatter.string(from: value)
                }
        }
    }
}
