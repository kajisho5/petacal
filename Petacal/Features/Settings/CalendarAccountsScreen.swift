import AuthenticationServices
import PetaCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum DeviceWord {
    /// 「iPhone」「iPad」「Mac」 for 「この iPhone」 and 「iPhone のカレンダー」.
    static var name: String {
        #if os(macOS)
        "Mac"
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }
}

/// S-16 カレンダーのアカウント: the device's calendars and the Google accounts connected directly.
struct CalendarAccountsScreen: View {
    @Environment(CalendarStore.self) private var store
    @State private var showingIntro = false
    @State private var reconnecting: String?
    @State private var failure: LocalizedStringKey?

    private var deviceCount: Int {
        store.calendars.filter { !GoogleRef.isGoogle($0.id) }.count
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    VisibleCalendarsScreen()
                } label: {
                    LabeledContent {
                        Text("\(deviceCount)件")
                    } label: {
                        Label { Text("\(DeviceWord.name) のカレンダー") } icon: { Image(systemName: "calendar") }
                    }
                }
            } header: {
                Text("この \(DeviceWord.name)")
            } footer: {
                Text("iCloud や、設定アプリで追加したアカウントのカレンダー")
            }

            if let google = store.google {
                Section {
                    ForEach(google.accounts) { account in
                        NavigationLink {
                            GoogleAccountScreen(email: account.email)
                        } label: {
                            GoogleAccountRow(account: account, loading: google.loading.contains(account.email),
                                             unreachable: google.unreachable.contains(account.email))
                        }
                    }
                    Button {
                        showingIntro = true
                    } label: {
                        Label("Google アカウントを追加", systemImage: "plus")
                    }
                    .disabled(!google.isAvailable)
                } header: {
                    Text("Google")
                } footer: {
                    if !google.isAvailable {
                        Text("Google カレンダーとの直接の連携は準備中です。")
                    } else if google.accounts.contains(where: \.needsSignIn) {
                        Text("しばらく使わなかったか、Google 側でアクセスを取り消したため、予定を読み込めません。押してログインし直すと、元どおりに表示されます。")
                    } else {
                        Text("Google カレンダーと直接つなぐと、予定ごとの色もそのまま表示できます。予定はこの \(DeviceWord.name) と Google のあいだだけでやりとりし、開発者には送りません。")
                    }
                }
            }
        }
        .navigationTitle("カレンダーのアカウント")
        .sheet(isPresented: $showingIntro) {
            GoogleConnectIntro { failure = $0 }
                .sheetSize()
        }
        .alert("Google とつなげませんでした", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let failure { Text(failure) }
        }
        .task { await store.google?.loadAll() }
    }
}

private struct GoogleAccountRow: View {
    let account: GoogleStore.Account
    let loading: Bool
    let unreachable: Bool

    @Environment(CalendarStore.self) private var store

    private var shownCount: Int {
        account.calendars.filter { store.isVisible(GoogleRef(email: account.email, calendarID: $0.id).calendarKey) }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: account.email)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if account.needsSignIn {
                    Text("ログインし直してください").font(.footnote).foregroundStyle(.red)
                } else if unreachable {
                    Text("最後に読み込んだ予定を表示しています").font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("カレンダー \(shownCount) 件を表示中").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if loading {
                ProgressView().accessibilityLabel(Text("読み込み中"))
            } else if account.needsSignIn {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .accessibilityLabel(Text("要ログイン"))
            }
        }
    }
}

/// S-17: what the connection reads and changes, before Google's own screen. One button, no close button.
struct GoogleConnectIntro: View {
    var loginHint: String?
    let onFailure: (LocalizedStringKey) -> Void

    @Environment(CalendarStore.self) private var store
    @Environment(\.webAuthenticationSession) private var web
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "calendar")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .padding(.top, 48)
                    .accessibilityHidden(true)
                Text("Google カレンダーとつなぎます")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 18) {
                    item("見るもの", "カレンダーの一覧、予定、予定ごとの色")
                    item("変えるもの", "このアプリで追加・変更・削除した予定だけ")
                    item("送り先", "この \(DeviceWord.name) と Google のあいだだけ。開発者には送りません")
                    item("やめるとき", "いつでも「接続を解除」できます")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Text("次の画面で Google にログインし、許可を選びます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    connect()
                } label: {
                    Group {
                        if working { ProgressView() } else { Text("続ける") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(working)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(Color.pageBackground)
        }
        .interactiveDismissDisabled(working)
    }

    private func item(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func connect() {
        guard let google = store.google else { return }
        working = true
        let session = web
        Task {
            defer { working = false }
            do {
                try await google.connect(using: session, loginHint: loginHint)
                dismiss()
            } catch GoogleStore.Failure.cancelled {
                // Closed Google's screen or chose 「キャンセル」: stay here, no message.
            } catch GoogleStore.Failure.missingPermission {
                dismiss()
                onFailure("Google の画面で、予定とカレンダーの一覧の両方にチェックを入れてください。")
            } catch GoogleStore.Failure.network {
                dismiss()
                onFailure("Google につながりませんでした。通信の状態を確かめて、もう一度試してください。")
            } catch {
                dismiss()
                onFailure("少し待ってから、もう一度試してください。")
            }
        }
    }
}

/// S-18 Google アカウント: which calendars to show, the event colors, and disconnecting.
struct GoogleAccountScreen: View {
    let email: String

    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDisconnect = false
    @State private var signingIn = false
    @State private var failure: LocalizedStringKey?

    var body: some View {
        if let google = store.google, let account = google.account(email) {
            List {
                Section {
                    Text(verbatim: email).foregroundStyle(.secondary)
                }
                if account.needsSignIn {
                    Section {
                        Button("ログインし直す") { signingIn = true }
                    } footer: {
                        Text("しばらく使わなかったか、Google 側でアクセスを取り消したため、予定を読み込めません。")
                    }
                }
                Section {
                    if account.calendars.isEmpty {
                        if google.loading.contains(email) {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("表示できるカレンダーがありません").foregroundStyle(.secondary)
                        }
                    }
                    ForEach(account.calendars) { entry in
                        let key = GoogleRef(email: email, calendarID: entry.id).calendarKey
                        Toggle(isOn: Binding(get: { store.isVisible(key) }, set: { store.setVisible(key, $0) })) {
                            HStack(spacing: 12) {
                                Circle().fill(Color(entry.color)).frame(width: 20, height: 20)
                                    .accessibilityHidden(true)
                                Text(verbatim: entry.title).lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("表示するカレンダー")
                } footer: {
                    if google.unreachable.contains(email) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Google から読み込めませんでした。通信の状態を確かめて、もう一度試してください。")
                            Button("もう一度") { Task { await google.load(email, force: true) } }
                        }
                    }
                }
                Section {
                    Toggle("予定ごとの Google の色を使う", isOn: Binding(
                        get: { account.useEventColors }, set: { google.setUseEventColors(email, $0) }))
                } header: {
                    Text("色")
                } footer: {
                    Text("オフにすると、カレンダーごとの色で表示します。")
                }
                Section {
                    LabeledContent("最後に読み込んだ時刻") {
                        if google.loading.contains(email) {
                            ProgressView()
                        } else if let last = account.lastLoaded {
                            Text(last, format: .dateTime.month().day().hour().minute())
                        } else {
                            Text("まだありません")
                        }
                    }
                    Button("接続を解除", role: .destructive) { confirmDisconnect = true }
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("設定アプリにも同じアカウントがあるときは、二重に表示しないように、そちらのカレンダーを隠します。")
                }
            }
            .navigationTitle("Google")
            .refreshable { await google.load(email, force: true) }
            .alert("接続を解除しますか？", isPresented: $confirmDisconnect) {
                Button("キャンセル", role: .cancel) {}
                Button("解除", role: .destructive) {
                    Task {
                        await google.disconnect(email)
                        dismiss()
                    }
                }
            } message: {
                Text("このアプリから Google の予定が見えなくなります。Google カレンダーの予定は消えません。")
            }
            .sheet(isPresented: $signingIn) {
                GoogleConnectIntro(loginHint: email) { failure = $0 }
                    .sheetSize()
            }
            .alert("Google とつなげませんでした", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                if let failure { Text(failure) }
            }
        } else {
            ContentUnavailableView("接続を解除しました", systemImage: "person.crop.circle.badge.minus")
        }
    }
}
