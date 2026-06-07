import SwiftUI

struct AboutView: View {
    @State private var showingChannelInfo = false
    @State private var showingVersionDetails = false
    
    var body: some View {
        List {
            Section(header: Text("about_section_title")) {
                HStack(spacing: 16) {
                    Image("annyui")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BeastLocator")
                            .font(.headline)
                        
                        Text("v0.9.5-Beta")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("about_dev_channel_title")) {
                HStack {
                    Text("about_dev_channel_title")
                    Spacer()
                    Text("about_dev_channel_value_beta")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingChannelInfo = true
                }
            }
            
            Section(header: Text("about_version_details_title")) {
                Button(action: {
                    showingVersionDetails = true
                }) {
                    Text("about_version_details_title")
                }
            }
            
            Section(header: Text("about_oss_title")) {
                NavigationLink(destination: OssLicensesView()) {
                    Text("about_oss_open")
                }
            }
            
            Section(header: Text("about_support_title")) {
                Button("about_support_open_site") {
                    if let url = URL(string: "https://linkserver.jp/") {
                        UIApplication.shared.open(url)
                    }
                }
                
                Button("about_support_open_twitter") {
                    if let url = URL(string: "https://x.com/Link_2011A") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            
            Section(header: Text("about_update_title")) {
                Text("about_update_notes")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("about_screen_title")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showingChannelInfo) {
            Alert(
                title: Text(String(format: NSLocalizedString("about_dev_channel_dialog_title", comment: ""), NSLocalizedString("about_dev_channel_value_beta", comment: ""))),
                message: Text("about_dev_channel_desc_dev"),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingVersionDetails) {
            Alert(
                title: Text("about_version_details_title"),
                message: Text(String(format: NSLocalizedString("about_version_details_message", comment: ""), "0.9.5-Beta", 202603281, "17C529")),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
