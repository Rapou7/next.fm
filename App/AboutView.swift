import SwiftUI

struct AboutView: View {
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.2" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Theme.accent.opacity(0.2), radius: 20, y: 8)
                    Text("next.fm").font(.largeTitle.bold())
                    Text("Your music. A different perspective.").font(.headline).multilineTextAlignment(.center)
                    Text("A native Last.fm companion for exploring your listening history, favorite music, and the patterns behind every scrobble.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Version \(version) (\(build))").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            }.listRowBackground(Color.clear)
            Section {
                Link(destination: URL(string: "https://github.com/Rapou7/next.fm")!) {
                    Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            Section("Made together") {
                LabeledContent("Rapou7", value: "Creator & product direction")
                LabeledContent("Codex · OpenAI", value: "Development collaborator")
            }
            Section("Acknowledgments") {
                Link("Last.fm · listening data", destination: URL(string: "https://www.last.fm")!)
                Link("Last.fm Stats Web · statistics inspiration", destination: URL(string: "https://github.com/felhag/lastfm-stats-web")!)
                Text("An independent project. Album artwork and artist names belong to their respective owners.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("About").navigationBarTitleDisplayMode(.inline)
    }
}
