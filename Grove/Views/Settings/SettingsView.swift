import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            EditorSettingsView()
                .tabItem {
                    Label("Editor", systemImage: "doc.text")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Picker("Appearance", selection: $settingsManager.settings.theme) {
                ForEach(Theme.allCases) { theme in
                    Text(theme.label).tag(theme)
                }
            }
            .pickerStyle(.inline)
            
            Picker("Default View", selection: $settingsManager.settings.defaultView) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
        }
        .padding()
    }
}

struct EditorSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Picker("Style", selection: $settingsManager.settings.style) {
                ForEach(EditorStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            
            Divider()
            
            Picker("Font", selection: $settingsManager.settings.fontFamily) {
                Text("Menlo").tag("Menlo")
                Text("Monaco").tag("Monaco")
                Text("Courier New").tag("Courier New")
                Text("SF Mono").tag("SF Mono")
                Text("JetBrains Mono").tag("JetBrains Mono")
            }
            
            HStack {
                Text("Font Size")
                Spacer()
                Text("\(Int(settingsManager.settings.fontSize)) pt")
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settingsManager.settings.fontSize, in: 10...24, step: 1)
            
            HStack {
                Text("Line Height")
                Spacer()
                Text(String(format: "%.1f", settingsManager.settings.lineHeight))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settingsManager.settings.lineHeight, in: 1.0...2.5, step: 0.1)

            Divider()

            Toggle("Novel-style paragraphs", isOn: $settingsManager.settings.novelStyleParagraphs)
                .help("Indent first line of paragraphs like a printed book")
        }
        .padding()
    }
}
