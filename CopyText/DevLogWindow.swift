import SwiftUI

struct DevLogWindow: View {
    @ObservedObject var eventLog: EventLog

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CopyText Dev Log")
                    .font(.headline)
                Spacer()
                Button("Copy All") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(eventLog.allText, forType: .string)
                }
                Button("Clear") {
                    eventLog.clear()
                }
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(eventLog.entries) { entry in
                            Text(entry.formattedLine)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: eventLog.entries.count) { _ in
                    if let last = eventLog.entries.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}
