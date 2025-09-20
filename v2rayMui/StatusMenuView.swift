import SwiftUI

struct StatusMenuView: View {
    @StateObject private var vm = StatusViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.connected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(vm.connected ? "已连接" : "未连接")
                    .font(.headline)
                Spacer(minLength: 8)
                if vm.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let name = vm.selectedName {
                Text("当前服务器：\(name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("未选择服务器")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("状态：\(vm.statusText)")
                .font(.footnote)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 8) {
                Button(vm.connected ? "断开" : "连接") {
                    Task { await vm.toggleConnection() }
                }
                .keyboardShortcut(.defaultAction)

                Button("刷新") {
                    Task { await vm.fetchStatus() }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 220)
    }
}

#Preview {
    StatusMenuView()
}


