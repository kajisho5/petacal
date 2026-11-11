import SwiftUI

struct SettingsScreen: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(short)（\(build)）"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("バージョン", value: version)
            } footer: {
                Text("画面の骨組みを確認するための、最初のバージョンです。予定と記録の機能はこのあと追加します。")
            }
        }
        .navigationTitle("設定")
    }
}
