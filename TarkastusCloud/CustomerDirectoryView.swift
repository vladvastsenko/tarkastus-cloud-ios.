import SwiftUI

struct CustomerDirectoryView: View {
    @EnvironmentObject private var store: LocalReportStore
    @State private var name = ""
    var body: some View {
        List {
            Section("Asiakkaat") {
                ForEach(store.archive.customers, id: \.id) { customer in
                    NavigationLink(customer.name) { CustomerEditor(customer: customer) }
                }
                TextField("Uusi asiakas", text: $name)
                Button("Lisää asiakas") {
                    var next = store.archive
                    next.customers.append(CustomerProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines)))
                    if store.commit(next) { name = "" }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.navigationTitle("Asiakkaat ja kohteet")
    }
}

struct CustomerEditor: View {
    @EnvironmentObject private var store: LocalReportStore
    @State var customer: CustomerProfile
    @State private var siteName = ""
    var body: some View {
        Form {
            TextField("Nimi", text: $customer.name)
            TextField("Y-tunnus", text: $customer.businessId)
            TextField("Osoite", text: $customer.address)
            TextField("Postinumero", text: $customer.postalCode)
            TextField("Postitoimipaikka", text: $customer.city)
            TextField("Yhteyshenkilö", text: $customer.contactPerson)
            TextField("Puhelin", text: $customer.phone)
            TextField("Sähköposti", text: $customer.email)
            Button("Tallenna") {
                var next = store.archive
                if let i = next.customers.firstIndex(where: { $0.id == customer.id }) {
                    next.customers[i] = customer
                    _ = store.commit(next)
                }
            }
            Section("Kohteet") {
                ForEach(store.archive.sites.filter { $0.customerId == customer.id }, id: \.id) { site in
                    NavigationLink(site.name) { SiteEditor(site: site) }
                }
                TextField("Uusi kohde", text: $siteName)
                Button("Lisää kohde") {
                    var next = store.archive
                    next.sites.append(CustomerSite(customerId: customer.id, name: siteName))
                    if store.commit(next) { siteName = "" }
                }.disabled(siteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.navigationTitle("Asiakas")
    }
}

struct SiteEditor: View {
    @EnvironmentObject private var store: LocalReportStore
    @State var site: CustomerSite
    var body: some View {
        Form {
            TextField("Kohteen nimi", text: $site.name)
            TextField("Osoite", text: $site.address)
            Button("Tallenna") {
                var next = store.archive
                if let i = next.sites.firstIndex(where: { $0.id == site.id }) {
                    next.sites[i] = site
                    _ = store.commit(next)
                }
            }
        }.navigationTitle("Kohde")
    }
}
