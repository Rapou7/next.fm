import SwiftUI
import NextFMCore

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var selectedTab = "Summary"
    @State private var searchFocusRequest = 0

    private var tabSelection: Binding<String> {
        Binding(get: { selectedTab }, set: { tab in
            if tab == "Search", selectedTab == tab {
                searchFocusRequest += 1
            }
            selectedTab = tab
        })
    }

    var body: some View {
        Group {
            if model.isConnected {
                TabView(selection: tabSelection) {
                    Tab("Summary", systemImage: "square.grid.2x2.fill", value: "Summary") { navigation("Summary") { SummaryView() } }
                    Tab("Tops", systemImage: "chart.bar.xaxis", value: "Tops") { navigation("Tops") { TopsView() } }
                    Tab("Search", systemImage: "magnifyingglass", value: "Search") {
                        navigation("Search") { LibraryView(searchFocusRequest: searchFocusRequest) }
                    }
                    Tab("History", systemImage: "clock.arrow.circlepath", value: "History") { navigation("History") { HistoryView() } }
                }
            } else { ConnectView() }
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .init("nextfm.showcase.tab"))) { notification in
            if let tab = notification.object as? String {
                withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.5)) { selectedTab = tab }
            }
        }
        #endif
        .sheet(isPresented: $showSettings) { SettingsView() }
        .task(id: scenePhase) {
            #if DEBUG
            Diagnostics.shared.record("lifecycle.phase", detail: String(describing: scenePhase))
            #endif
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await model.refreshNowPlaying()
                do { try await Task.sleep(for: .seconds(45)) } catch { break }
            }
        }
    }
    private func navigation<Content: View>(_ screen: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .quickAppear()
                #if DEBUG
                .onAppear { Diagnostics.shared.record("screen.appear", detail: screen) }
                #endif
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("next.fm")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Account", systemImage: "person.crop.circle", action: { showSettings = true })
                            .labelStyle(.iconOnly)
                    }
                }
        }
    }
}

struct ConnectView: View {
    @Environment(AppModel.self) private var model
    @State private var username = ""
    @State private var apiKey = ""
    @State private var connecting = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 34).fill(Theme.accent.gradient).frame(width: 100, height: 100)
                        Image(systemName: "waveform").font(.system(size: 44, weight: .semibold)).foregroundStyle(.white)
                    }.padding(.top, 44)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("next.fm").font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("Your music.\nA different perspective.").font(.largeTitle.bold())
                        Text("The records on repeat. The artists you discover. Every scrobble, beautifully connected.")
                            .font(.body).foregroundStyle(.secondary)
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Connect to Last.fm").font(.headline)
                            TextField("Last.fm username", text: $username)
                                .textContentType(.username).autocorrectionDisabled().textInputAutocapitalization(.never)
                            Divider()
                            SecureField("Last.fm API key", text: $apiKey).autocorrectionDisabled().textInputAutocapitalization(.never)
                            Text("Use your public profile. Your password is never needed. History stays on this device.")
                                .font(.caption).foregroundStyle(.secondary)
                            Link("Get a Last.fm API key", destination: URL(string: "https://www.last.fm/api/account/create")!).font(.caption)
                        }
                    }
                    if let error = model.errorMessage { Text(error).font(.callout).foregroundStyle(Theme.accent) }
                    Button {
                        connecting = true
                        Task { await model.connect(username: username, apiKey: apiKey); connecting = false }
                    } label: {
                        HStack { Spacer(); if connecting { ProgressView() }; Text("Start listening closer").fontWeight(.semibold); Spacer() }.padding(.vertical, 9)
                    }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        .disabled(connecting || username.trimmingCharacters(in: .whitespaces).isEmpty || apiKey.isEmpty)
                    Button("Explore the demo") { Task { await model.showDemo() } }
                        .frame(maxWidth: .infinity).padding(.bottom, 24)
                }.padding(24)
            }.background(Theme.background)
                .onAppear { apiKey = model.apiKey }
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage("durationLookupsEnabled") private var durationLookupsEnabled = false
    @AppStorage(ListeningRankingOrder.storageKey) private var rankingOrder = ListeningRankingOrder.scrobbles
    @Bindable private var appearance = AppAppearance.shared

    private var effectiveRankingOrder: Binding<ListeningRankingOrder> {
        Binding(get: { durationLookupsEnabled ? rankingOrder : .scrobbles },
                set: { rankingOrder = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Profile", value: model.isDemo ? "Demo" : model.displayUsername)
                    LabeledContent("Stored scrobbles", value: model.history.count.formatted())
                    LabeledContent("History", value: model.historyComplete ? "Complete" : "Import in progress")
                    if let date = model.lastSynced { LabeledContent("Last refreshed") { Text(date, style: .relative) } }
                }
                Section("Appearance") {
                    Picker("Accent color", selection: $appearance.accent) {
                        ForEach(AccentColorOption.allCases) { option in
                            Label {
                                Text(option.title)
                            } icon: {
                                Image(systemName: "circle.fill").foregroundStyle(option.color ?? appearance.customColor)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    if appearance.accent == .custom {
                        ColorPicker("Custom color", selection: $appearance.customColor, supportsOpacity: false)
                    }
                }
                if !model.isDemo {
                    Section {
                        Toggle("Estimate listening time", isOn: $durationLookupsEnabled)
                        TimeEstimatesSetting(count: model.history.count)
                        Picker("Sort rankings by", selection: effectiveRankingOrder) {
                            Text("Scrobbles").tag(ListeningRankingOrder.scrobbles)
                            Text("Listening time").tag(ListeningRankingOrder.time)
                        }
                        .disabled(!durationLookupsEnabled)
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(durationLookupsEnabled
                                 ? "Listening time uses matched track durations."
                                 : "Enable listening time estimates to sort rankings by time.")
                            Text("Looks up track, artist and album names over HTTPS. Your username, play counts and timestamps stay on this device.")
                        }
                    }
                    Section("Sync") {
                        Text(model.syncMessage).font(.subheadline)
                        if model.isSyncing {
                            ProgressView(value: model.syncProgress)
                            Button("Pause import") { model.stopSync() }
                        } else { Button("Refresh / resume import") { model.startSync() } }
                        Text("Keep next.fm open for the first import. If you leave, progress is saved and can be resumed.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error = model.errorMessage { Section { Text(error).foregroundStyle(Theme.accent) } }
                #if DEBUG
                Section("Development") {
                    Button("Debug tools", systemImage: "ladybug") {
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .seconds(0.6))
                            DebugTools.shared.panel = true
                        }
                    }
                }
                #endif
                Section("About") {
                    NavigationLink { AboutView() } label: {
                        Label("About next.fm", systemImage: "info.circle")
                    }
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.2")
                    Text("Estimated minutes use catalog lengths for matched scrobbles.")
                    Text("Artist thumbnails use artwork from listened albums when available.")
                    Link("Powered by Last.fm", destination: URL(string: "https://www.last.fm")!)
                }.font(.subheadline)
                Section {
                    Button(model.isDemo ? "Connect your profile" : "Switch profile") { model.disconnect(); dismiss() }
                } footer: { Text("Switching profiles keeps previously imported history on this device.") }
            }
            .listeningDurations(model.history, query: "settings-\(model.revision)", fetchMissing: false)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Your account").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
