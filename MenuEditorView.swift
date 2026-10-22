import SwiftUI

/// إدارة المنيو: إضافة أصناف، وتغيير الأسعار، والحذف. بتظهر لحساب المدير بس.
struct MenuEditorView: View {
    @Environment(POSStore.self) private var store

    // الإضافة
    @State private var name = ""
    @State private var nameEn = ""
    @State private var price: Double?
    @State private var category = ""          // مفتاح القسم بالعربي، أو "new" لقسم جديد
    @State private var newCategory = ""
    @State private var newCategoryEn = ""
    @State private var symbol = menuSymbols[0]
    @State private var message: (text: String, ok: Bool)?

    // التعديل والحذف
    @State private var editingID: UUID?
    @State private var editPrice: Double?
    @State private var itemToRemove: MenuItem?

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                addCard.frame(width: 360)
                listCard
            }
            .padding()
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(tr("المنيو والأصناف", "Menu & Items"))
        .onAppear { if category.isEmpty { category = store.categories.first ?? "new" } }
    }

    // MARK: - إضافة صنف
    private var addCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("إضافة صنف جديد", "Add a New Item")).font(.title3.bold())

            TextField(tr("اسم الصنف بالعربي", "Name in Arabic"), text: $name)
                .textFieldStyle(.roundedBorder)
            TextField(tr("اسم الصنف بالإنجليزي", "Name in English"), text: $nameEn)
                .textFieldStyle(.roundedBorder)
            TextField(tr("السعر (ج.م)", "Price (EGP)"), value: $price, format: .number)
                .textFieldStyle(.roundedBorder)

            Picker(tr("القسم", "Category"), selection: $category) {
                ForEach(store.categories, id: \.self) { Text(store.categoryTitle($0)).tag($0) }
                Text(tr("+ قسم جديد", "+ New category")).tag("new")
            }

            if category == "new" {
                TextField(tr("اسم القسم بالعربي", "Category name in Arabic"), text: $newCategory)
                    .textFieldStyle(.roundedBorder)
                TextField(tr("اسم القسم بالإنجليزي", "Category name in English"), text: $newCategoryEn)
                    .textFieldStyle(.roundedBorder)
            }

            Text(tr("الأيقونة", "Icon")).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 6), spacing: 8) {
                ForEach(menuSymbols, id: \.self) { s in
                    Button { symbol = s } label: {
                        Image(systemName: s)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(symbol == s ? Color.accentColor.opacity(0.2) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(symbol == s ? Color.accentColor : Color.secondary.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let message {
                Label(message.text, systemImage: message.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(message.ok ? .green : .red)
            }

            Button(action: add) {
                Label(tr("إضافة للمنيو", "Add to menu"), systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func add() {
        let isNew = category == "new"
        let catAr = isNew ? newCategory : category
        let catEn = isNew ? newCategoryEn : (store.menu.first { $0.category == category }?.categoryEn ?? "")
        if let error = store.addItem(name: name, nameEn: nameEn, price: price ?? 0,
                                     category: catAr, categoryEn: catEn, symbol: symbol) {
            message = (error, false)
        } else {
            message = (tr("اتضاف الصنف للمنيو.", "Item added to the menu."), true)
            name = ""; nameEn = ""; price = nil
            if isNew { category = catAr.trimmingCharacters(in: .whitespaces); newCategory = ""; newCategoryEn = "" }
        }
    }

    // MARK: - الأصناف الحالية
    private var listCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("المنيو الحالي (\(store.menu.count) صنف)", "Current Menu (\(store.menu.count) items)"))
                .font(.title3.bold())
            Text(tr("أي تغيير في السعر أو حذف صنف بيتسجل في سجل الرقابة.",
                    "Every price change or removal is recorded in the audit log."))
                .font(.caption).foregroundStyle(.secondary)

            if let item = itemToRemove {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("متأكد إنك عايز تمسح \(item.displayName) من المنيو؟", "Remove \(item.displayName) from the menu?"))
                        .font(.headline)
                    HStack {
                        Button(tr("رجوع", "Back")) { itemToRemove = nil }
                        Button(tr("مسح", "Remove")) { store.removeItem(item); itemToRemove = nil }
                            .buttonStyle(.borderedProminent).tint(.red)
                    }
                }
                .padding(12)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            ForEach(store.categories, id: \.self) { cat in
                Text(store.categoryTitle(cat)).font(.headline).padding(.top, 6)
                ForEach(store.menu.filter { $0.category == cat }) { item in
                    row(item)
                    Divider()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ item: MenuItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol).foregroundStyle(.tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.displayName).font(.body.weight(.medium))
                Text(AppLanguage.isArabic ? item.nameEn : item.name).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if editingID == item.id {
                TextField(tr("السعر", "Price"), value: $editPrice, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit { savePrice(item) }
                Button(tr("حفظ", "Save")) { savePrice(item) }
                    .buttonStyle(.borderedProminent)
                Button(tr("رجوع", "Back")) { editingID = nil }
            } else {
                Text(money(item.price)).monospacedDigit()
                Button(tr("تعديل السعر", "Edit price")) {
                    editingID = item.id
                    editPrice = item.price
                }
                .buttonStyle(.bordered)
                Button(tr("مسح", "Remove")) { itemToRemove = item }
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
        }
    }

    private func savePrice(_ item: MenuItem) {
        if let p = editPrice, p > 0 { store.changePrice(of: item, to: p) }
        editingID = nil
    }
}
