import SwiftUI

/// شاشة الدخول: اختار اسمك من القايمة واكتب الباسورد
struct LoginView: View {
    @Environment(POSStore.self) private var store
    @State private var name = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 46))
                .foregroundStyle(.tint)
            Text(tr("كافيه النخيل", "Palm Café")).font(.largeTitle.bold())
            Text(tr("سجّل دخولك عشان تبدأ الشيفت", "Sign in to start your shift")).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text(tr("المستخدم", "User")).font(.caption).foregroundStyle(.secondary)
                Picker(tr("المستخدم", "User"), selection: $name) {
                    ForEach(store.users) { user in
                        Text("\(user.name) · \(user.roleName)").tag(user.name)
                    }
                }
                .labelsHidden()

                Text(tr("الباسورد", "Password")).font(.caption).foregroundStyle(.secondary)
                SecureField(tr("اكتب الباسورد", "Enter password"), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(signIn)

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button(action: signIn) {
                    Text(tr("دخول", "Sign in")).frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || password.isEmpty)
            }
            .padding(20)
            .frame(width: 340)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))

            Text(tr("حسابات تجريبية: المدير 1234 · أحمد 1111 · سارة 2222 · كريم 3333",
                    "Demo accounts: المدير 1234 · أحمد 1111 · سارة 2222 · كريم 3333"))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            LanguageSwitcher().frame(width: 260)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if name.isEmpty { name = store.users.first(where: { !$0.isManager })?.name ?? store.users.first?.name ?? "" }
        }
    }

    private func signIn() {
        if store.login(name: name, password: password) {
            error = nil
        } else {
            error = tr("الباسورد غلط. جرّب تاني.", "Wrong password. Try again.")
            password = ""
        }
    }
}
