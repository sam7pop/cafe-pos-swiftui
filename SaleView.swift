import SwiftUI

struct SaleView: View {
    @Environment(POSStore.self) private var store
    @State private var category = "all"
    @State private var receipt: Order?
    @State private var pendingDiscount: Int?

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    private var items: [MenuItem] {
        category == "all" ? store.menu : store.menu.filter { $0.category == category }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Picker(tr("القسم", "Category"), selection: $category) {
                    Text(tr("الكل", "All")).tag("all")
                    ForEach(store.categories, id: \.self) { Text(store.categoryTitle($0)).tag($0) }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { item in
                            Button { store.add(item) } label: { ItemTile(item: item) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)

            Divider()

            CartPanel(receipt: $receipt, pendingDiscount: $pendingDiscount)
                .frame(width: 330)
        }
        .navigationTitle(tr("البيع", "Sale"))
        .sheet(item: $receipt) { ReceiptView(order: $0) }
        .sheet(item: Binding(
            get: { pendingDiscount.map { DiscountRequest(percent: $0) } },
            set: { pendingDiscount = $0?.percent }
        )) { req in
            ManagerApprovalView(title: tr("خصم \(req.percent)%", "\(req.percent)% discount"),
                                message: tr("أي خصم أكبر من \(store.maxDiscountWithoutManager)% محتاج باسورد المدير، وهيتسجل في سجل الرقابة.",
                                            "Any discount above \(store.maxDiscountWithoutManager)% needs a manager password and is recorded in the audit log.")) {
                store.discountPercent = req.percent
            }
        }
    }
}

struct DiscountRequest: Identifiable {
    var percent: Int
    var id: Int { percent }
}

// MARK: - كارت الصنف
struct ItemTile: View {
    let item: MenuItem
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.symbol)
                .font(.system(size: 28))
                .foregroundStyle(.tint)
                .frame(height: 34)
            Text(item.displayName).font(.headline).lineLimit(1)
            Text(money(item.price)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.quaternary))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - الطلب الحالي
struct CartPanel: View {
    @Environment(POSStore.self) private var store
    @Binding var receipt: Order?
    @Binding var pendingDiscount: Int?

    private let discounts = [0, 5, 10, 20, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("الطلب الحالي", "Current Order")).font(.title3.bold())
                Spacer()
                if !store.cart.isEmpty {
                    Button(tr("مسح", "Clear"), role: .destructive) { store.clearCart() }
                        .buttonStyle(.borderless)
                }
            }

            if store.cart.isEmpty {
                ContentUnavailableView(tr("الطلب فاضي", "No items yet"), systemImage: "cart",
                                       description: Text(tr("اختار الأصناف من المنيو", "Pick items from the menu")))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.cart) { line in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(line.item.displayName).font(.body.weight(.medium))
                                Text(money(line.total)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                            Spacer()
                            Button { store.decrease(line) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                            Text("\(line.quantity)").monospacedDigit().frame(minWidth: 22)
                            Button { store.add(line.item) } label: { Image(systemName: "plus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                .listStyle(.plain)
            }

            VStack(spacing: 8) {
                HStack {
                    Text(tr("الخصم", "Discount"))
                    Spacer()
                    Picker(tr("الخصم", "Discount"), selection: Binding(
                        get: { store.discountPercent },
                        set: { value in
                            if store.needsManager(for: value) { pendingDiscount = value }
                            else { store.discountPercent = value }
                        })) {
                        ForEach(discounts, id: \.self) { Text("\($0)%").tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
                row(tr("الإجمالي قبل الخصم", "Subtotal"), store.cartSubtotal)
                if store.cartDiscount > 0 { row(tr("الخصم", "Discount"), -store.cartDiscount) }
                Divider()
                HStack {
                    Text(tr("المطلوب", "Total")).font(.title3.bold())
                    Spacer()
                    Text(money(store.cartTotal)).font(.title2.bold()).monospacedDigit()
                }
            }

            HStack(spacing: 10) {
                ForEach(PaymentMethod.allCases) { method in
                    Button {
                        receipt = store.checkout(paidBy: method)
                    } label: {
                        Label(method.title, systemImage: method.symbol)
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(method == .cash ? .green : .blue)
                    .disabled(store.cart.isEmpty)
                }
            }
        }
        .padding()
    }

    private func row(_ title: String, _ value: Double) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(money(value)).monospacedDigit()
        }
    }
}

// MARK: - الفاتورة بعد الدفع
struct ReceiptView: View {
    let order: Order
    @Environment(POSStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
            Text(tr("فاتورة رقم \(order.number)", "Bill #\(order.number)")).font(.title2.bold())
            Text("\(timeText(order.date)) · \(order.cashier) · \(order.payment.title)")
                .foregroundStyle(.secondary)
            Divider()
            ForEach(order.lines) { line in
                HStack {
                    Text("\(line.item.displayName) × \(line.quantity)")
                    Spacer()
                    Text(money(line.total)).monospacedDigit()
                }
            }
            if order.discountAmount > 0 {
                HStack {
                    Text(tr("خصم \(order.discountPercent)%", "Discount \(order.discountPercent)%")).foregroundStyle(.secondary)
                    Spacer()
                    Text(money(-order.discountAmount)).monospacedDigit()
                }
            }
            Divider()
            HStack {
                Text(tr("الإجمالي", "Total")).font(.headline)
                Spacer()
                Text(money(order.total)).font(.headline).monospacedDigit()
            }
            HStack {
                Button {
                    printReceipt(order, shop: store.shop, isCopy: false)
                } label: {
                    Label(tr("طباعة الفاتورة", "Print bill"), systemImage: "printer.fill")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("p")

                Button(tr("طلب جديد", "New order")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 340)
    }
}

// MARK: - موافقة المدير برقم سري
struct ManagerApprovalView: View {
    @Environment(POSStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    let onApprove: () -> Void
    @State private var pin = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.badge.key.fill").font(.system(size: 36)).foregroundStyle(.orange)
            Text(title).font(.title3.bold())
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            SecureField(tr("باسورد المدير", "Manager password"), text: $pin)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
                .onSubmit(approve)
            if wrong {
                Text(tr("الباسورد غلط، أو الحساب مش حساب مدير.", "Wrong password, or not a manager account.")).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button(tr("إلغاء", "Cancel"), role: .cancel) { dismiss() }
                Button(tr("موافقة", "Approve"), action: approve).buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 340)
    }

    private func approve() {
        if store.isManagerPassword(pin) { onApprove(); dismiss() }
        else { wrong = true; pin = "" }
    }
}
