import Foundation
import Observation

/// العقل بتاع التطبيق: الطلب الحالي، والفواتير، وسجل الرقابة، وحسابات الشيفت.
@Observable
final class POSStore {
    // المستخدمين وتسجيل الدخول
    var users: [AppUser] = []
    var currentUser: AppUser?
    var cashiers: [String] { users.filter { !$0.isManager }.map(\.name) }
    var currentCashier: String { currentUser?.name ?? "" }
    var isManagerLoggedIn: Bool { currentUser?.isManager ?? false }
    private let usersKey = "cafepos.users"
    private let menuKey = "cafepos.menu"

    // الإعدادات
    var maxDiscountWithoutManager = 10 // أي خصم أكبر من كده محتاج موافقة
    var allowedDifference: Double = 20 // العجز أو الزيادة المسموح بيهم
    var openingFloat: Double = 500
    var cashPayouts: Double = 150      // مصروفات اتدفعت من الدرج
    var shop: ShopInfo { ShopInfo.demo }

    // البيانات
    var menu: [MenuItem] = MenuItem.sampleMenu
    var cart: [OrderLine] = []
    var discountPercent = 0
    var orders: [Order] = []
    var events: [AuditEvent] = []
    private var nextNumber = 1

    init(withDemoData: Bool = true) {
        loadUsers()
        loadMenu()
        if withDemoData && !menu.isEmpty { loadDemoData() }
    }

    // MARK: - المستخدمين
    private func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let saved = try? JSONDecoder().decode([AppUser].self, from: data), !saved.isEmpty {
            users = saved
        } else {
            users = [
                AppUser(name: "المدير", password: "1234", isManager: true),
                AppUser(name: "أحمد", password: "1111", isManager: false),
                AppUser(name: "سارة", password: "2222", isManager: false),
                AppUser(name: "كريم", password: "3333", isManager: false),
            ]
            saveUsers()
        }
    }

    private func saveUsers() {
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: usersKey)
        }
    }

    /// بيرجّع true لو الاسم والباسورد صح
    func login(name: String, password: String) -> Bool {
        guard let user = users.first(where: { $0.name == name }), user.check(password) else { return false }
        currentUser = user
        log(.login, detail: "\(user.roleName): \(user.name)", amount: 0)
        return true
    }

    func logout() {
        guard let user = currentUser else { return }
        log(.logout, detail: "\(user.roleName): \(user.name)", amount: 0)
        cart.removeAll()
        discountPercent = 0
        currentUser = nil
    }

    /// المدير بس يقدر يضيف. بيرجّع رسالة خطأ، أو nil لو تمت الإضافة.
    func addUser(name: String, password: String, confirm: String, isManager: Bool) -> String? {
        guard isManagerLoggedIn else { return tr("المدير بس هو اللي يقدر يضيف مستخدمين.", "Only a manager can add users.") }
        let clean = name.trimmingCharacters(in: .whitespaces)
        if clean.isEmpty { return tr("اكتب اسم المستخدم.", "Enter a user name.") }
        if users.contains(where: { $0.name == clean }) { return tr("الاسم ده موجود قبل كده.", "This name already exists.") }
        if normalizeDigits(password).count < 4 { return tr("الباسورد لازم يكون 4 حروف أو أرقام على الأقل.", "Password must be at least 4 characters.") }
        if normalizeDigits(password) != normalizeDigits(confirm) { return tr("الباسورد وتأكيده مش زي بعض.", "Passwords don't match.") }
        users.append(AppUser(name: clean, password: password, isManager: isManager))
        saveUsers()
        log(.userAdded, detail: "\(isManager ? tr("مدير", "Manager") : tr("كاشير", "Cashier")): \(clean)", amount: 0)
        return nil
    }

    func removeUser(_ user: AppUser) {
        guard isManagerLoggedIn, user.id != currentUser?.id else { return }
        if user.isManager && users.filter(\.isManager).count <= 1 { return } // لازم يفضل مدير واحد على الأقل
        users.removeAll { $0.id == user.id }
        saveUsers()
        log(.userRemoved, detail: "\(user.roleName): \(user.name)", amount: 0)
    }

    /// موافقة المدير: أي باسورد لحساب مدير
    func isManagerPassword(_ password: String) -> Bool {
        users.contains { $0.isManager && $0.check(password) }
    }

    // MARK: - المنيو (المدير بس يقدر يعدّل)
    private func loadMenu() {
        if let data = UserDefaults.standard.data(forKey: menuKey),
           let saved = try? JSONDecoder().decode([MenuItem].self, from: data), !saved.isEmpty {
            menu = saved
        }
    }

    private func saveMenu() {
        if let data = try? JSONEncoder().encode(menu) {
            UserDefaults.standard.set(data, forKey: menuKey)
        }
    }

    /// بيرجّع رسالة خطأ، أو nil لو الصنف اتضاف
    func addItem(name: String, nameEn: String, price: Double, category: String, categoryEn: String, symbol: String) -> String? {
        guard isManagerLoggedIn else { return tr("المدير بس هو اللي يقدر يضيف أصناف.", "Only a manager can add items.") }
        let n = name.trimmingCharacters(in: .whitespaces)
        let nEn = nameEn.trimmingCharacters(in: .whitespaces)
        let c = category.trimmingCharacters(in: .whitespaces)
        let cEn = categoryEn.trimmingCharacters(in: .whitespaces)
        if n.isEmpty || nEn.isEmpty { return tr("اكتب اسم الصنف بالعربي والإنجليزي.", "Enter the item name in Arabic and English.") }
        if c.isEmpty || cEn.isEmpty { return tr("اختار القسم أو اكتب اسم القسم الجديد.", "Choose a category or name the new one.") }
        if price <= 0 { return tr("السعر لازم يكون أكبر من صفر.", "Price must be more than zero.") }
        if menu.contains(where: { $0.name == n || $0.nameEn.lowercased() == nEn.lowercased() }) {
            return tr("الصنف ده موجود قبل كده.", "This item already exists.")
        }
        let item = MenuItem(name: n, nameEn: nEn, price: price, category: c, categoryEn: cEn, symbol: symbol)
        menu.append(item)
        saveMenu()
        log(.itemAdded, detail: "\(item.displayName) · \(money(price))", amount: price)
        return nil
    }

    func changePrice(of item: MenuItem, to newPrice: Double) {
        guard isManagerLoggedIn, newPrice > 0, let i = menu.firstIndex(where: { $0.id == item.id }) else { return }
        let old = menu[i].price
        guard old != newPrice else { return }
        menu[i].price = newPrice
        saveMenu()
        log(.priceChanged, detail: "\(item.displayName): \(money(old)) → \(money(newPrice))", amount: newPrice - old)
    }

    func removeItem(_ item: MenuItem) {
        guard isManagerLoggedIn else { return }
        menu.removeAll { $0.id == item.id }
        saveMenu()
        log(.itemRemoved, detail: item.displayName, amount: item.price)
    }

    /// الأقسام بالترتيب (بالمفتاح العربي)
    var categories: [String] {
        var result: [String] = []
        for item in menu where !result.contains(item.category) { result.append(item.category) }
        return result
    }
    func categoryTitle(_ key: String) -> String {
        menu.first(where: { $0.category == key })?.displayCategory ?? key
    }

    // MARK: - الطلب الحالي
    var cartSubtotal: Double { cart.reduce(0) { $0 + $1.total } }
    var cartDiscount: Double { cartSubtotal * Double(discountPercent) / 100 }
    var cartTotal: Double { cartSubtotal - cartDiscount }

    func add(_ item: MenuItem) {
        if let i = cart.firstIndex(where: { $0.item.id == item.id }) {
            cart[i].quantity += 1
        } else {
            cart.append(OrderLine(item: item, quantity: 1))
        }
    }

    func decrease(_ line: OrderLine) {
        guard let i = cart.firstIndex(where: { $0.id == line.id }) else { return }
        if cart[i].quantity > 1 {
            cart[i].quantity -= 1
        } else {
            remove(line)
        }
    }

    func remove(_ line: OrderLine) {
        cart.removeAll { $0.id == line.id }
        log(.removeLine, detail: "\(line.item.displayName) × \(line.quantity)", amount: line.total)
    }

    func clearCart() {
        for line in cart { log(.removeLine, detail: "\(line.item.displayName) × \(line.quantity)", amount: line.total) }
        cart.removeAll()
        discountPercent = 0
    }

    func needsManager(for discount: Int) -> Bool { discount > maxDiscountWithoutManager }

    @discardableResult
    func checkout(paidBy payment: PaymentMethod) -> Order? {
        guard !cart.isEmpty else { return nil }
        let order = Order(number: nextNumber, date: Date(), cashier: currentCashier,
                          lines: cart, discountPercent: discountPercent, payment: payment)
        orders.append(order)
        if needsManager(for: discountPercent) {
            log(.bigDiscount, detail: discountDetail(discountPercent, order.number), amount: order.discountAmount)
        }
        nextNumber += 1
        cart.removeAll()
        discountPercent = 0
        return order
    }

    // MARK: - إلغاء فاتورة (بيتسجل باسم الكاشير والسبب)
    func void(_ order: Order, reason: String) {
        guard let i = orders.firstIndex(where: { $0.id == order.id }), !orders[i].isVoided else { return }
        orders[i].isVoided = true
        orders[i].voidReason = reason
        log(.voidOrder, detail: voidDetail(order.number, reason), amount: order.total)
    }

    private func discountDetail(_ percent: Int, _ number: Int) -> String {
        tr("خصم \(percent)% على فاتورة رقم \(number)", "\(percent)% discount on bill #\(number)")
    }
    private func voidDetail(_ number: Int, _ reason: String) -> String {
        tr("فاتورة رقم \(number) · السبب: \(reason)", "Bill #\(number) · Reason: \(reason)")
    }

    /// إعادة الطباعة بتتسجل في سجل الرقابة
    func logReprint(_ order: Order) {
        log(.reprint, detail: tr("فاتورة رقم \(order.number)", "Bill #\(order.number)"), amount: order.total)
    }

    // MARK: - أرقام الشيفت
    var validOrders: [Order] { orders.filter { !$0.isVoided } }
    var totalSales: Double { validOrders.reduce(0) { $0 + $1.total } }
    var cashSales: Double { validOrders.filter { $0.payment == .cash }.reduce(0) { $0 + $1.total } }
    var cardSales: Double { validOrders.filter { $0.payment == .card }.reduce(0) { $0 + $1.total } }
    var discountsTotal: Double { validOrders.reduce(0) { $0 + $1.discountAmount } }
    var voidedOrders: [Order] { orders.filter { $0.isVoided } }
    var voidedTotal: Double { voidedOrders.reduce(0) { $0 + $1.total } }
    var averageBill: Double { validOrders.isEmpty ? 0 : totalSales / Double(validOrders.count) }
    var expectedCash: Double { openingFloat + cashSales - cashPayouts }

    func voidCount(for cashier: String) -> Int { voidedOrders.filter { $0.cashier == cashier }.count }
    func sales(for cashier: String) -> Double { validOrders.filter { $0.cashier == cashier }.reduce(0) { $0 + $1.total } }

    var salesByHour: [HourSales] {
        let cal = Calendar.current
        var totals: [Int: Double] = [:]
        for o in validOrders { totals[cal.component(.hour, from: o.date), default: 0] += o.total }
        return totals.keys.sorted().map { HourSales(hour: $0, total: totals[$0] ?? 0) }
    }

    var topItems: [ItemSales] {
        var q: [String: Int] = [:]
        for o in validOrders { for l in o.lines { q[l.item.displayName, default: 0] += l.quantity } }
        return q.map { ItemSales(name: $0.key, quantity: $0.value) }
            .sorted { $0.quantity > $1.quantity }
            .prefix(5).map { $0 }
    }

    // MARK: - تقفيل الشيفت
    func closeShift(counted: Double) {
        let diff = counted - expectedCash
        let status = abs(diff) <= allowedDifference ? tr("مطابق", "Balanced") : (diff < 0 ? tr("عجز", "Short") : tr("زيادة", "Over"))
        log(.shiftClosed, detail: "\(status) · \(tr("المتوقع", "Expected")) \(money(expectedCash)) · \(tr("الفعلي", "Counted")) \(money(counted))", amount: diff)
    }

    // MARK: - السجل
    private func log(_ kind: AuditEvent.Kind, detail: String, amount: Double, at date: Date = Date(), by cashier: String? = nil) {
        events.insert(AuditEvent(date: date, cashier: cashier ?? currentCashier, kind: kind, detail: detail, amount: amount), at: 0)
    }

    // MARK: - بيانات تجريبية لليوم الحالي
    private func loadDemoData() {
        var rng = SeededGenerator(seed: 42)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weights: [Int: Int] = [9: 4, 10: 5, 11: 6, 12: 7, 13: 8, 14: 6, 15: 6, 16: 7, 17: 9, 18: 11, 19: 12, 20: 13, 21: 10]

        for hour in weights.keys.sorted() {
            let cashier = hour < 15 ? "أحمد" : (hour < 19 ? "سارة" : "كريم")
            for _ in 0..<(weights[hour] ?? 5) {
                let minute = Int.random(in: 0..<60, using: &rng)
                guard let date = cal.date(byAdding: .minute, value: hour * 60 + minute, to: today) else { continue }
                var lines: [OrderLine] = []
                for _ in 0..<Int.random(in: 1...3, using: &rng) {
                    let item = menu[Int.random(in: 0..<menu.count, using: &rng)]
                    if let i = lines.firstIndex(where: { $0.item.id == item.id }) { lines[i].quantity += 1 }
                    else { lines.append(OrderLine(item: item, quantity: Int.random(in: 1...2, using: &rng))) }
                }
                let discount = cashier == "كريم" && Int.random(in: 0..<6, using: &rng) == 0 ? 30 : (Int.random(in: 0..<8, using: &rng) == 0 ? 10 : 0)
                var order = Order(number: nextNumber, date: date, cashier: cashier, lines: lines,
                                  discountPercent: discount, payment: Int.random(in: 0..<10, using: &rng) < 6 ? .cash : .card)
                nextNumber += 1
                if discount > maxDiscountWithoutManager {
                    log(.bigDiscount, detail: discountDetail(discount, order.number), amount: order.discountAmount, at: date, by: cashier)
                }
                let voidChance = cashier == "كريم" ? 7 : 40
                if Int.random(in: 0..<voidChance, using: &rng) == 0 {
                    order.isVoided = true
                    order.voidReason = cashier == "كريم" ? tr("الزبون غيّر رأيه", "Customer changed mind") : tr("خطأ في الطلب", "Wrong order")
                    log(.voidOrder, detail: voidDetail(order.number, order.voidReason ?? ""), amount: order.total, at: date.addingTimeInterval(240), by: cashier)
                }
                orders.append(order)
            }
        }
        orders.sort { $0.date < $1.date }
        events.sort { $0.date > $1.date }
    }
}

/// مولّد أرقام عشوائية ثابت، عشان البيانات التجريبية تطلع نفسها كل مرة.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
