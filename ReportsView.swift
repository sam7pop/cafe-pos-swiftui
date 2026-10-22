import SwiftUI
import Charts

struct ReportsView: View {
    @Environment(POSStore.self) private var store
    @State private var orderToVoid: Order?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kpis
                HStack(alignment: .top, spacing: 16) {
                    hourlyChart
                    topItemsCard.frame(width: 280)
                }
                cashiersCard
                auditCard
                ordersCard
            }
            .padding()
        }
        .navigationTitle(tr("التقارير والرقابة", "Reports & Audit"))
    }

    // MARK: - الأرقام الرئيسية
    private var kpis: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            KPI(title: tr("المبيعات", "Sales"), value: money(store.totalSales), note: tr("\(store.validOrders.count) فاتورة", "\(store.validOrders.count) bills"))
            KPI(title: tr("متوسط الفاتورة", "Average bill"), value: money(store.averageBill), note: tr("بعد الخصومات", "After discounts"))
            KPI(title: tr("الإلغاءات", "Voids"), value: money(store.voidedTotal), note: tr("\(store.voidedOrders.count) فاتورة ملغية", "\(store.voidedOrders.count) voided bills"),
                tint: store.voidedOrders.count >= 5 ? .red : nil)
            KPI(title: tr("الخصومات", "Discounts"), value: money(store.discountsTotal), note: "\(PaymentMethod.cash.title) \(money(store.cashSales)) · \(PaymentMethod.card.title) \(money(store.cardSales))")
        }
    }

    // MARK: - المبيعات بالساعة
    private var hourlyChart: some View {
        Card(title: tr("المبيعات بالساعة", "Sales by Hour")) {
            Chart(store.salesByHour) { h in
                BarMark(x: .value(tr("الساعة", "Hour"), h.label), y: .value(tr("المبيعات", "Sales"), h.total))
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 220)
        }
    }

    // MARK: - الأكثر مبيعاً
    private var topItemsCard: some View {
        Card(title: tr("الأكثر مبيعاً", "Top Sellers")) {
            let maxQ = Double(store.topItems.first?.quantity ?? 1)
            VStack(spacing: 10) {
                ForEach(store.topItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(item.quantity)").monospacedDigit().foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            Capsule().fill(.blue.opacity(0.75))
                                .frame(width: geo.size.width * Double(item.quantity) / maxQ, height: 6)
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    // MARK: - الكاشيرات
    private var cashiersCard: some View {
        Card(title: tr("أداء الكاشيرات", "Cashier Performance")) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    Text(tr("الكاشير", "Cashier")); Text(tr("المبيعات", "Sales")); Text(tr("الإلغاءات", "Voids")); Text(tr("الحالة", "Status"))
                }
                .font(.caption).foregroundStyle(.secondary)
                ForEach(store.cashiers, id: \.self) { name in
                    let voids = store.voidCount(for: name)
                    GridRow {
                        Text(name).bold()
                        Text(money(store.sales(for: name))).monospacedDigit()
                        Text("\(voids)").monospacedDigit()
                        StatusBadge(level: voids >= 4 ? .critical : (voids >= 2 ? .warning : .good))
                    }
                }
            }
        }
    }

    // MARK: - سجل الرقابة
    private var auditCard: some View {
        Card(title: tr("سجل الرقابة", "Audit Log"), subtitle: tr("كل إلغاء وخصم كبير وتقفيل شيفت بيتسجل هنا ومينفعش يتمسح", "Every void, large discount and shift close is recorded here and cannot be deleted")) {
            if store.events.isEmpty {
                Text(tr("مفيش حركات لسه", "No activity yet")).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.events.prefix(12)) { e in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: e.kind.symbol)
                                .foregroundStyle(e.kind.isCritical ? .red : .orange)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(e.kind.title) · \(e.cashier)").font(.body.weight(.medium))
                                Text(e.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(money(e.amount)).monospacedDigit()
                                Text(timeText(e.date)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - آخر الفواتير
    private var ordersCard: some View {
        Card(title: tr("آخر الفواتير", "Recent Bills")) {
            if let order = orderToVoid {
                VoidOrderView(order: order) { orderToVoid = nil }.id(order.id)
            }
            VStack(spacing: 8) {
                ForEach(Array(store.orders.suffix(8).reversed())) { o in
                    HStack {
                        Text("#\(o.number)").monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                        Text(timeText(o.date)).foregroundStyle(.secondary)
                        Text(o.cashier)
                        Text(o.payment.title).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                        Spacer()
                        Text(money(o.total)).monospacedDigit().strikethrough(o.isVoided)
                        Button {
                            store.logReprint(o)
                            printReceipt(o, shop: store.shop, isCopy: true)
                        } label: {
                            Image(systemName: "printer")
                        }
                        .buttonStyle(.bordered)
                        .help(tr("إعادة طباعة (بتتسجل في سجل الرقابة)", "Reprint (recorded in the audit log)"))
                        if o.isVoided {
                            Text(tr("ملغية", "Voided")).font(.caption.bold()).foregroundStyle(.red)
                        } else {
                            Button(tr("إلغاء", "Void")) { orderToVoid = o }
                                .buttonStyle(.bordered)
                                .tint(.red)
                        }
                    }
                    Divider()
                }
            }
        }
    }
}

// MARK: - إلغاء فاتورة بسبب + موافقة مدير
struct VoidOrderView: View {
    @Environment(POSStore.self) private var store
    let order: Order
    let onClose: () -> Void
    @State private var reason = ""
    @State private var pin = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "xmark.octagon.fill").font(.system(size: 36)).foregroundStyle(.red)
            Text(tr("إلغاء فاتورة رقم \(order.number)", "Void bill #\(order.number)")).font(.title3.bold())
            Text("\(money(order.total)) · \(order.cashier)").foregroundStyle(.secondary)
            TextField(tr("سبب الإلغاء (إجباري)", "Reason (required)"), text: $reason).textFieldStyle(.roundedBorder)
            SecureField(tr("باسورد المدير", "Manager password"), text: $pin).textFieldStyle(.roundedBorder)
            if wrong { Text(tr("الباسورد غلط، أو الحساب مش حساب مدير.", "Wrong password, or not a manager account.")).font(.caption).foregroundStyle(.red) }
            HStack {
                Button(tr("رجوع", "Back")) { onClose() }
                Button(tr("تأكيد الإلغاء", "Confirm void")) {
                    if store.isManagerPassword(pin) {
                        store.void(order, reason: reason)
                        onClose()
                    } else { wrong = true; pin = "" }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.red.opacity(0.35)))
    }
}

// MARK: - مكونات صغيرة
struct Card<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct KPI: View {
    let title: String
    let value: String
    let note: String
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit().foregroundStyle(tint ?? .primary)
            Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StatusBadge: View {
    enum Level { case good, warning, critical }
    let level: Level

    var body: some View {
        let (text, color, symbol): (String, Color, String) = {
            switch level {
            case .good: return (tr("ممتاز", "Good"), .green, "checkmark.circle.fill")
            case .warning: return (tr("متابعة", "Watch"), .orange, "exclamationmark.circle.fill")
            case .critical: return (tr("مراجعة عاجلة", "Urgent review"), .red, "exclamationmark.octagon.fill")
            }
        }()
        Label(text, systemImage: symbol)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
