import Foundation
import CryptoKit

// MARK: - طرق الدفع
enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash
    case card
    var id: String { rawValue }
    var title: String { self == .cash ? tr("كاش", "Cash") : tr("فيزا", "Card") }
    var symbol: String { self == .cash ? "banknote" : "creditcard" }
}

// MARK: - صنف في المنيو
struct MenuItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String        // الاسم بالعربي
    var nameEn: String      // الاسم بالإنجليزي
    var price: Double
    var category: String
    var categoryEn: String
    var symbol: String      // اسم أيقونة من SF Symbols

    var displayName: String { tr(name, nameEn) }
    var displayCategory: String { tr(category, categoryEn) }
}

// MARK: - سطر في الفاتورة
struct OrderLine: Identifiable, Hashable, Codable {
    var id = UUID()
    var item: MenuItem
    var quantity: Int
    var total: Double { item.price * Double(quantity) }
}

// MARK: - الفاتورة
struct Order: Identifiable, Codable {
    var id = UUID()
    var number: Int
    var date: Date
    var cashier: String
    var lines: [OrderLine]
    var discountPercent: Int
    var payment: PaymentMethod
    var isVoided = false
    var voidReason: String?

    var subtotal: Double { lines.reduce(0) { $0 + $1.total } }
    var discountAmount: Double { subtotal * Double(discountPercent) / 100 }
    var total: Double { subtotal - discountAmount }
    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }
}

// MARK: - سجل الرقابة (كل حركة حساسة بتتسجل ومينفعش تتمسح)
struct AuditEvent: Identifiable, Codable {
    enum Kind: String, Codable {
        case voidOrder = "إلغاء فاتورة"
        case bigDiscount = "خصم كبير"
        case removeLine = "حذف صنف من الطلب"
        case shiftClosed = "تقفيل شيفت"
        case login = "تسجيل دخول"
        case logout = "تسجيل خروج"
        case userAdded = "إضافة مستخدم"
        case userRemoved = "حذف مستخدم"
        case itemAdded = "إضافة صنف"
        case itemRemoved = "حذف صنف"
        case priceChanged = "تغيير سعر"
        case reprint = "إعادة طباعة"

        var symbol: String {
            switch self {
            case .voidOrder: return "xmark.octagon.fill"
            case .bigDiscount: return "percent"
            case .removeLine: return "minus.circle.fill"
            case .shiftClosed: return "lock.fill"
            case .login: return "person.crop.circle.badge.checkmark"
            case .logout: return "rectangle.portrait.and.arrow.right"
            case .userAdded: return "person.badge.plus"
            case .userRemoved: return "person.badge.minus"
            case .itemAdded: return "plus.square.fill"
            case .itemRemoved: return "minus.square.fill"
            case .priceChanged: return "tag.fill"
            case .reprint: return "printer.fill"
            }
        }
        var isCritical: Bool { self == .voidOrder || self == .priceChanged }
        var title: String {
            switch self {
            case .voidOrder: return tr("إلغاء فاتورة", "Voided bill")
            case .bigDiscount: return tr("خصم كبير", "Large discount")
            case .removeLine: return tr("حذف صنف من الطلب", "Item removed")
            case .shiftClosed: return tr("تقفيل شيفت", "Shift closed")
            case .login: return tr("تسجيل دخول", "Signed in")
            case .logout: return tr("تسجيل خروج", "Signed out")
            case .userAdded: return tr("إضافة مستخدم", "User added")
            case .userRemoved: return tr("حذف مستخدم", "User removed")
            case .itemAdded: return tr("إضافة صنف", "Item added")
            case .itemRemoved: return tr("حذف صنف", "Item removed from menu")
            case .priceChanged: return tr("تغيير سعر", "Price changed")
            case .reprint: return tr("إعادة طباعة فاتورة", "Bill reprinted")
            }
        }
    }

    var id = UUID()
    var date: Date
    var cashier: String
    var kind: Kind
    var detail: String
    var amount: Double
}

// MARK: - مستخدم (كاشير أو مدير)
struct AppUser: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var passwordHash: String
    var isManager: Bool

    init(name: String, password: String, isManager: Bool) {
        self.name = name
        self.passwordHash = hashPassword(password)
        self.isManager = isManager
    }

    func check(_ password: String) -> Bool { passwordHash == hashPassword(password) }
    var roleName: String { isManager ? tr("مدير", "Manager") : tr("كاشير", "Cashier") }
}

/// الباسورد مش بيتحفظ زي ما هو، بيتحفظ مشفّر (SHA-256)
func hashPassword(_ password: String) -> String {
    let data = Data(normalizeDigits(password).utf8)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// بيحوّل الأرقام العربي (١٢٣٤) لإنجليزي (1234) عشان الباسورد يتقبل بأي كيبورد
func normalizeDigits(_ text: String) -> String {
    let arabic = Array("٠١٢٣٤٥٦٧٨٩"), persian = Array("۰۱۲۳۴۵۶۷۸۹")
    return String(text.map { ch -> Character in
        if let i = arabic.firstIndex(of: ch) { return Character(String(i)) }
        if let i = persian.firstIndex(of: ch) { return Character(String(i)) }
        return ch
    }).trimmingCharacters(in: .whitespaces)
}

// MARK: - مبيعات ساعة (للرسم البياني)
struct HourSales: Identifiable {
    var hour: Int
    var total: Double
    var id: Int { hour }
    var label: String {
        let h = hour > 12 ? hour - 12 : hour
        return "\(h)" + (hour >= 12 ? tr("م", "pm") : tr("ص", "am"))
    }
}

// MARK: - أكثر الأصناف مبيعاً
struct ItemSales: Identifiable {
    var name: String
    var quantity: Int
    var id: String { name }
}

// MARK: - المنيو التجريبي
extension MenuItem {
    static let sampleMenu: [MenuItem] = [
        MenuItem(name: "قهوة تركي", nameEn: "Turkish Coffee", price: 35, category: "مشروبات ساخنة", categoryEn: "Hot Drinks", symbol: "cup.and.saucer.fill"),
        MenuItem(name: "إسبريسو", nameEn: "Espresso", price: 40, category: "مشروبات ساخنة", categoryEn: "Hot Drinks", symbol: "cup.and.saucer.fill"),
        MenuItem(name: "لاتيه", nameEn: "Latte", price: 55, category: "مشروبات ساخنة", categoryEn: "Hot Drinks", symbol: "mug.fill"),
        MenuItem(name: "كابتشينو", nameEn: "Cappuccino", price: 55, category: "مشروبات ساخنة", categoryEn: "Hot Drinks", symbol: "mug.fill"),
        MenuItem(name: "شاي بالنعناع", nameEn: "Mint Tea", price: 25, category: "مشروبات ساخنة", categoryEn: "Hot Drinks", symbol: "leaf.fill"),
        MenuItem(name: "آيس لاتيه", nameEn: "Iced Latte", price: 65, category: "مشروبات باردة", categoryEn: "Cold Drinks", symbol: "takeoutbag.and.cup.and.straw.fill"),
        MenuItem(name: "عصير مانجو", nameEn: "Mango Juice", price: 50, category: "مشروبات باردة", categoryEn: "Cold Drinks", symbol: "takeoutbag.and.cup.and.straw.fill"),
        MenuItem(name: "ليمون نعناع", nameEn: "Lemon Mint", price: 40, category: "مشروبات باردة", categoryEn: "Cold Drinks", symbol: "drop.fill"),
        MenuItem(name: "مياه معدنية", nameEn: "Water", price: 15, category: "مشروبات باردة", categoryEn: "Cold Drinks", symbol: "waterbottle.fill"),
        MenuItem(name: "كرواسون", nameEn: "Croissant", price: 45, category: "أكل", categoryEn: "Food", symbol: "birthday.cake.fill"),
        MenuItem(name: "تشيز كيك", nameEn: "Cheesecake", price: 75, category: "أكل", categoryEn: "Food", symbol: "birthday.cake.fill"),
        MenuItem(name: "ساندوتش جبنة", nameEn: "Cheese Sandwich", price: 60, category: "أكل", categoryEn: "Food", symbol: "fork.knife"),
    ]
}

// MARK: - بيانات المحل اللي بتظهر على الفاتورة (تجريبية)
struct ShopInfo {
    var name: String
    var address: String
    var phone: String
    var vatRate: Double   // ضريبة القيمة المضافة %، محسوبة ضمن السعر

    static var demo: ShopInfo {
        ShopInfo(name: tr("كافيه النخيل", "Palm Café"),
                 address: tr("15 شارع النخيل، المعادي، القاهرة", "15 Palm St, Maadi, Cairo"),
                 phone: "02 2345 6789",
                 vatRate: 14)
    }
}

// MARK: - أيقونات متاحة للأصناف
let menuSymbols = ["cup.and.saucer.fill", "mug.fill", "leaf.fill", "takeoutbag.and.cup.and.straw.fill",
                   "drop.fill", "waterbottle.fill", "birthday.cake.fill", "fork.knife",
                   "carrot.fill", "fish.fill", "flame.fill", "snowflake"]

// MARK: - تنسيق الفلوس
func money(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)).locale(AppLanguage.current.locale)) + " " + tr("ج.م", "EGP")
}
