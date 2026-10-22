import SwiftUI

struct ShiftCloseView: View {
    @Environment(POSStore.self) private var store

    private let denominations: [Double] = [200, 100, 50, 20, 10, 5, 1, 0.5]
    @State private var counts: [Int] = [0, 0, 0, 0, 0, 0, 0, 0]
    @State private var closed = false
    @State private var didPrefill = false

    private var counted: Double {
        zip(denominations, counts).reduce(0) { $0 + $1.0 * Double($1.1) }
    }
    private var difference: Double { counted - store.expectedCash }
    private var status: (text: String, color: Color, symbol: String) {
        if abs(difference) <= store.allowedDifference { return (tr("مطابق", "Balanced"), .green, "checkmark.seal.fill") }
        return difference < 0 ? (tr("عجز", "Short"), .red, "exclamationmark.triangle.fill") : (tr("زيادة", "Over"), .orange, "arrow.up.circle.fill")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 20) {
                    countCard
                    summaryCard
                }
                .frame(maxWidth: 900)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(tr("تقفيل الشيفت", "Close Shift"))
        .onAppear(perform: prefillDemoCount)
    }

    // MARK: - عدّ الدرج بالفئات
    private var countCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("عدّ الدرج", "Count the Drawer")).font(.title3.bold())
            Text(tr("اكتب عدد كل فئة في الدرج", "Enter how many of each note and coin")).font(.caption).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text(tr("الفئة", "Note")).foregroundStyle(.secondary)
                    Text(tr("العدد", "Count")).foregroundStyle(.secondary)
                    Text(tr("القيمة", "Value")).foregroundStyle(.secondary)
                }
                .font(.caption)
                ForEach(denominations.indices, id: \.self) { i in
                    GridRow {
                        Text(denominations[i] < 1 ? tr("نص جنيه", "0.5 EGP") : tr("\(Int(denominations[i])) جنيه", "\(Int(denominations[i])) EGP"))
                        HStack(spacing: 6) {
                            TextField("0", value: $counts[i], format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 64)
                                .multilineTextAlignment(.center)
                            Stepper("", value: $counts[i], in: 0...999).labelsHidden()
                        }
                        Text(money(denominations[i] * Double(counts[i]))).monospacedDigit()
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text(tr("إجمالي العدّ", "Total counted")).bold()
                    Text("")
                    Text(money(counted)).bold().monospacedDigit()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - النتيجة
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("النتيجة", "Result")).font(.title3.bold())
            line(tr("الكاشير", "Cashier"), store.currentCashier)
            line(tr("رصيد افتتاح الدرج", "Opening float"), money(store.openingFloat))
            line(tr("مبيعات كاش", "Cash sales"), money(store.cashSales))
            line(tr("مصروفات من الدرج", "Paid out from drawer"), money(-store.cashPayouts))
            Divider()
            line(tr("النقدية المتوقعة", "Expected cash"), money(store.expectedCash), bold: true)
            line(tr("النقدية الفعلية", "Counted cash"), money(counted), bold: true)

            HStack {
                Label(status.text, systemImage: status.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(status.color)
                Spacer()
                Text(money(difference)).font(.title2.bold()).monospacedDigit().foregroundStyle(status.color)
            }
            .padding(12)
            .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            Text(tr("المسموح: ± ", "Allowed: ± ") + money(store.allowedDifference)).font(.caption).foregroundStyle(.secondary)

            Button {
                store.closeShift(counted: counted)
                closed = true
            } label: {
                Label(closed ? tr("اتقفل الشيفت واتسجل", "Shift closed and recorded") : tr("تقفيل الشيفت", "Close shift"), systemImage: closed ? "checkmark" : "lock.fill")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .disabled(closed)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func line(_ title: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(title).foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value).monospacedDigit().fontWeight(bold ? .semibold : .regular)
        }
    }

    /// يملأ عدّ تجريبي ناقص حوالي 60 جنيه عن المتوقع، عشان العرض يبيّن حالة العجز.
    private func prefillDemoCount() {
        guard !didPrefill else { return }
        didPrefill = true
        var remaining = max(0, store.expectedCash - 60)
        for i in denominations.indices {
            let n = Int(remaining / denominations[i])
            counts[i] = n
            remaining -= Double(n) * denominations[i]
        }
    }
}
