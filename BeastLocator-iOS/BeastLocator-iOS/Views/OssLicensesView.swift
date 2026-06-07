import SwiftUI

struct OssLicenseEntry: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: String
    let license: String
    let url: String
    let body: String
}

struct OssLicensesView: View {
    let licenses = [
        OssLicenseEntry(
            title: "OpenStreetMap Data",
            coordinate: "org.openstreetmap:openstreetmap:1.0",
            license: "ODbL 1.0",
            url: "https://www.openstreetmap.org/copyright",
            body: NSLocalizedString("license_odbl_body", comment: "")
        ),
        OssLicenseEntry(
            title: "Apple MapKit terms",
            coordinate: "com.apple.mapkit:mapkit:1.0",
            license: "Apple MapKit Terms",
            url: "https://www.apple.com/legal/internet-services/maps/terms-ja.html",
            body: "MapKit location & routing is provided under Apple MapKit terms."
        )
    ]
    
    var body: some View {
        List(licenses) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.coordinate)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(entry.license)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                HStack {
                    Button("oss_button_open_url") {
                        if let url = URL(string: entry.url) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Spacer()
                    
                    NavigationLink(destination: ScrollView {
                        Text(entry.body)
                            .padding()
                            .font(.system(.body, design: .monospaced))
                    }.navigationTitle(entry.title)) {
                        Text("oss_button_show_text")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("oss_screen_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
