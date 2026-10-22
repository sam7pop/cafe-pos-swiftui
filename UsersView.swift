import SwiftUI

/// إدارة المستخدمين: بتظهر لحساب المدير بس
struct UsersView: View {
    @Environment(POSStore.self) private var store
    @State private var name = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var isManager = false
    @State private var message: (text: String, ok: Bool)?
    @State private var userToRemove: AppUser?

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                addCard
                listCard
            }
            .padding()
            .frame(maxWidth: 950)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(tr("المستخدمين", "Users"))
    }

    // MARK: - إضافة مستخدم
    private var addCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("إضافة مستخدم جديد", "Add a New User")).font(.title3.bold())
            Text(tr("المدير بس هو اللي يقدر يعمل اسم المستخدم والباسورد.", "Only a manager can create user names and passwords.")).font(.caption).foregroundStyle(.secondary)

            TextField(tr("اسم المستخدم", "User name"), text: $name).textFieldStyle(.roundedBorder)
            SecureField(tr("الباسورد (4 حروف أو أرقام على الأقل)", "Password (at least 4 characters)"), text: $password).textFieldStyle(.roundedBorder)
            SecureField(tr("تأكيد الباسورد", "Confirm password"), text: $confirm).textFieldStyle(.roundedBorder)
            Toggle(tr("صلاحية مدير", "Manager access"), isOn: $isManager)

            if let message {
                Label(message.text, systemImage: message.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(message.ok ? .green : .red)
            }

            Button {
                if let error = store.addUser(name: name, password: password, confirm: confirm, isManager: isManager) {
                    message = (error, false)
                } else {
                    message = (tr("اتضاف \(name.trimmingCharacters(in: .whitespaces)) بنجاح.", "\(name.trimmingCharacters(in: .whitespaces)) was added."), true)
                    name = ""; password = ""; confirm = ""; isManager = false
                }
            } label: {
                Label(tr("إضافة", "Add"), systemImage: "person.badge.plus").frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - قايمة المستخدمين
    private var listCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("المستخدمين الحاليين (\(store.users.count))", "Current Users (\(store.users.count))")).font(.title3.bold())

            if let user = userToRemove {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("متأكد إنك عايز تمسح \(user.name)؟", "Remove \(user.name)?")).font(.headline)
                    Text(tr("مش هيقدر يدخل على التطبيق تاني، والعملية هتتسجل في سجل الرقابة.", "They will not be able to sign in again, and this will be recorded in the audit log."))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(tr("رجوع", "Back")) { userToRemove = nil }
                        Button(tr("مسح", "Remove")) { store.removeUser(user); userToRemove = nil }
                            .buttonStyle(.borderedProminent).tint(.red)
                    }
                }
                .padding(12)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            ForEach(store.users) { user in
                HStack(spacing: 10) {
                    Image(systemName: user.isManager ? "person.badge.key.fill" : "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(user.isManager ? .orange : .blue)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(user.name).font(.body.weight(.medium))
                        Text(user.roleName).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if user.id == store.currentUser?.id {
                        Text(tr("إنت", "You")).font(.caption.bold()).foregroundStyle(.secondary)
                    } else {
                        Button(tr("مسح", "Remove")) { userToRemove = user }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                }
                Divider()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}
