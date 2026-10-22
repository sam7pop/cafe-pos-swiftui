import SwiftUI

@main
struct CafePOSApp: App {
    @State private var store = POSStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, AppLanguage.current.locale)
                #if os(iOS)
                .environment(\.layoutDirection, AppLanguage.current.layoutDirection)
                #endif
                #if os(macOS)
                .frame(minWidth: 1000, minHeight: 650)
                #endif
        }
    }
}

enum Screen: String, CaseIterable, Identifiable {
    case sale, shift, reports, menu, users
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sale: return tr("البيع", "Sale")
        case .shift: return tr("تقفيل الشيفت", "Close Shift")
        case .reports: return tr("التقارير والرقابة", "Reports & Audit")
        case .menu: return tr("المنيو والأصناف", "Menu & Items")
        case .users: return tr("المستخدمين", "Users")
        }
    }
    var symbol: String {
        switch self {
        case .sale: return "cart.fill"
        case .shift: return "tray.full.fill"
        case .reports: return "chart.bar.xaxis"
        case .menu: return "menucard.fill"
        case .users: return "person.2.fill"
        }
    }
    var managerOnly: Bool { self == .users || self == .menu }
}

struct RootView: View {
    @Environment(POSStore.self) private var store

    var body: some View {
        if store.currentUser == nil {
            LoginView()
        } else {
            MainView()
        }
    }
}

struct MainView: View {
    @Environment(POSStore.self) private var store
    @State private var screen: Screen? = .sale

    private var screens: [Screen] {
        Screen.allCases.filter { !$0.managerOnly || store.isManagerLoggedIn }
    }

    var body: some View {
        NavigationSplitView {
            List(screens, selection: $screen) { s in
                Label(s.title, systemImage: s.symbol).tag(s)
            }
            .navigationTitle(tr("كافيه النخيل", "Palm Café"))
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: store.isManagerLoggedIn ? "person.badge.key.fill" : "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(store.isManagerLoggedIn ? .orange : .blue)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(store.currentCashier).font(.headline)
                            Text(store.currentUser?.roleName ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        store.logout()
                    } label: {
                        Label(tr("تسجيل خروج", "Sign out"), systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    LanguageSwitcher()
                    Text(tr("نسخة تجريبية ببيانات وهمية", "Demo version with sample data")).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding()
            }
        } detail: {
            switch screen ?? .sale {
            case .sale: SaleView()
            case .shift: ShiftCloseView()
            case .reports: ReportsView()
            case .menu: store.isManagerLoggedIn ? AnyView(MenuEditorView()) : AnyView(SaleView())
            case .users: store.isManagerLoggedIn ? AnyView(UsersView()) : AnyView(SaleView())
            }
        }
    }
}
