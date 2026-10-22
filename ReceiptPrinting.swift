import SwiftUI
#if os(macOS)
import AppKit
import PDFKit
#else
import UIKit
#endif

// MARK: - شكل الفاتورة المطبوعة (عرض طابعة كاشير 80 مم)
struct PrintableReceipt: View {
    let order: Order
    let shop: ShopInfo
    let isCopy: Bool

    private let small = Font.system(size: 9)
    private let smallBold = Font.system(size: 9, weight: .semibold)

    var body: some View {
        VStack(spacing: 5) {
            // رأس الفاتورة
            Text(shop.name).font(.system(size: 16, weight: .bold))
            Text(shop.address).font(.system(size: 8)).multilineTextAlignment(.center)
            Text(tr("تليفون: ", "Tel: ") + shop.phone).font(.system(size: 8))
            if isCopy {
                Text(tr("— نسخة —", "— COPY —")).font(.system(size: 11, weight: .heavy))
            }
            DashedLine()

            // بيانات الفاتورة
            infoRow(tr("رقم الفاتورة", "Bill No."), "#\(order.number)")
            infoRow(tr("التاريخ", "Date"), dateText(order.date))
            infoRow(tr("الوقت", "Time"), timeText(order.date))
            infoRow(tr("الكاشير", "Cashier"), order.cashier)
            infoRow(tr("طريقة الدفع", "Payment"), order.payment.title)
            DashedLine()

            // الأصناف
            HStack(spacing: 4) {
                Text(tr("الصنف", "Item")).frame(maxWidth: .infinity, alignment: .leading)
                Text(tr("الكمية", "Qty")).frame(width: 28)
                Text(tr("السعر", "Price")).frame(width: 40)
                Text(tr("الإجمالي", "Total")).frame(width: 46, alignment: .trailing)
            }
            .font(smallBold)
            ForEach(order.lines) { line in
                HStack(alignment: .top, spacing: 4) {
                    Text(line.item.displayName).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(line.quantity)").frame(width: 28)
                    Text(number(line.item.price)).frame(width: 40)
                    Text(number(line.total)).frame(width: 46, alignment: .trailing)
                }
                .font(small)
            }
            DashedLine()

            // الحساب
            infoRow(tr("الإجمالي قبل الخصم", "Subtotal"), money(order.subtotal))
            if order.discountAmount > 0 {
                infoRow(tr("خصم \(order.discountPercent)%", "Discount \(order.discountPercent)%"),
                        "-" + money(order.discountAmount))
            }
            HStack {
                Text(tr("المطلوب", "TOTAL"))
                Spacer()
                Text(money(order.total))
            }
            .font(.system(size: 13, weight: .bold))
            if shop.vatRate > 0 {
                infoRow(tr("منها ضريبة القيمة المضافة \(Int(shop.vatRate))%", "Incl. VAT \(Int(shop.vatRate))%"),
                        money(order.total * shop.vatRate / (100 + shop.vatRate)))
            }
            infoRow(tr("عدد الأصناف", "Items count"), "\(order.itemCount)")

            if order.isVoided {
                DashedLine()
                Text(tr("فاتورة ملغية", "VOIDED BILL")).font(.system(size: 12, weight: .heavy))
                if let reason = order.voidReason {
                    Text(tr("السبب: ", "Reason: ") + reason).font(.system(size: 8))
                }
            }

            DashedLine()
            Text(tr("شكراً لزيارتكم", "Thank you for your visit")).font(.system(size: 10, weight: .semibold))
            Text(tr("طُبعت: ", "Printed: ") + dateText(Date()) + " " + timeText(Date()))
                .font(.system(size: 7))
        }
        .padding(10)
        .frame(width: 226)
        .foregroundStyle(.black)
        .background(.white)
        .environment(\.layoutDirection, AppLanguage.current.layoutDirection)
        .environment(\.locale, AppLanguage.current.locale)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
        .font(small)
    }

    private func number(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...2)).locale(AppLanguage.current.locale))
    }
}

/// خط متقطع زي الفواتير الحقيقية
struct DashedLine: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 0.7, dash: [3, 2]))
        }
        .frame(height: 1)
        .padding(.vertical, 2)
    }
}

/// التاريخ حسب اللغة
func dateText(_ date: Date) -> String {
    date.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(AppLanguage.current.locale))
}

// MARK: - الطباعة
/// بيحوّل الفاتورة لـ PDF ويفتح شباك الطباعة (تقدر تطبع أو تحفظها PDF)
@MainActor
func printReceipt(_ order: Order, shop: ShopInfo, isCopy: Bool) {
    let renderer = ImageRenderer(content: PrintableReceipt(order: order, shop: shop, isCopy: isCopy))
    renderer.proposedSize = ProposedViewSize(width: 226, height: nil)

    let pdfData = NSMutableData()
    renderer.render { size, draw in
        var box = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
        context.beginPDFPage(nil)
        draw(context)
        context.endPDFPage()
        context.closePDF()
    }

    #if os(macOS)
    guard let document = PDFDocument(data: pdfData as Data),
          let info = NSPrintInfo.shared.copy() as? NSPrintInfo else { return }
    info.topMargin = 10
    info.leftMargin = 10
    info.rightMargin = 10
    info.isHorizontallyCentered = true
    info.isVerticallyCentered = false
    info.jobDisposition = .spool
    if let operation = document.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false) {
        operation.jobTitle = tr("فاتورة \(order.number)", "Bill \(order.number)")
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }
    #else
    let controller = UIPrintInteractionController.shared
    let info = UIPrintInfo(dictionary: nil)
    info.outputType = .general
    info.jobName = tr("فاتورة \(order.number)", "Bill \(order.number)")
    controller.printInfo = info
    controller.printingItem = pdfData as Data
    controller.present(animated: true)
    #endif
}
