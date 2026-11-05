import SwiftUI
import UIKit

struct SettingsView: View {
    let advisor: any VerseAdvisor
    @AppStorage("settings.palette") private var paletteSetting = "auto"
    @AppStorage("settings.haptics") private var haptics = true
    @AppStorage("settings.reminder") private var reminderOn = false
    @AppStorage("settings.reminderMinutes") private var reminderMinutes = 7 * 60 + 30
    @AppStorage("onboarded") private var onboarded = true
    @State private var permission: Reminder.Permission = .notAsked
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                reminderMinutes = (c.hour ?? 7) * 60 + (c.minute ?? 30)
                Task { await reschedule() }
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    let kou = Almanac.kou(on: .now, calendar: .current)
                    HStack(spacing: Space.l) {
                        KoyomiWheel(filled: [], current: kou.index, showsCenter: false).frame(width: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("こよみ句帳").font(Typeset.title(20)).foregroundStyle(Ink.text)
                            Text("いまは\(kou.sekki)・\(kou.phase)「\(kou.name)」").font(Typeset.small).foregroundStyle(Ink.sub)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                Section("季節の色") {
                    swatchRow("auto", "自動（今は\(Almanac.kou(on: .now, calendar: .current).season.name)）", SeasonPalette.of(Almanac.kou(on: .now, calendar: .current).season))
                    ForEach(Season.allCases, id: \.rawValue) { s in
                        swatchRow("\(s)", "\(s.name)・\(SeasonPalette.of(s).name)", .of(s))
                    }
                }
                Section {
                    Toggle("毎朝、今日の候と季語を知らせる", isOn: $reminderOn)
                        .onChange(of: reminderOn) { _, on in Task { await toggled(on) } }
                    if reminderOn {
                        DatePicker("時刻", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                    if permission == .denied {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("通知が許可されていません。iPhone の設定で「こよみ句帳」の通知をオンにすると届きます。")
                                .font(Typeset.small).foregroundStyle(Ink.sub)
                            Button("設定を開く") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                        }
                    }
                } header: { Text("朝のお知らせ") } footer: {
                    Text("お知らせは端末の中で予約します。先の 14 日分を、日ごとの季語で入れておきます。")
                }
                Section("手応え") {
                    Toggle("振動", isOn: $haptics)
                }
                Section("Apple Intelligence") {
                    switch advisor.status {
                    case .available:
                        Text("使えます。句を読んで、推敲のヒントを 3 つ返します（端末の中で動き、句を外に送りません）。").font(Typeset.small)
                    case .unavailable(let reason):
                        Text(reason).font(Typeset.small).foregroundStyle(Ink.sub)
                    }
                }
                Section("使い方") {
                    Button("使い方をもう一度見る") { onboarded = false; dismiss() }
                }
                Section("プライバシー") {
                    Text("句は、この iPhone の中だけに保存します。アカウント・広告・解析はありません。アプリを削除すると句帳も消えます。")
                        .font(Typeset.small).foregroundStyle(Ink.sub)
                }
                Section("このアプリについて") {
                    Text("七十二候は略本暦にもとづきます。候の始まる日は年によって 1 日ほど前後するため、目安として「ごろ」と書いています。音の数は端末の辞書による読みの目安です。")
                        .font(Typeset.small).foregroundStyle(Ink.sub)
                    LabeledContent("バージョン", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Ink.ground)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
            .task { permission = await Reminder.permission() }
        }
    }

    private func swatchRow(_ key: String, _ label: String, _ p: SeasonPalette) -> some View {
        Button { paletteSetting = key } label: {
            HStack(spacing: Space.m) {
                HStack(spacing: 3) {
                    Circle().fill(p.accent).frame(width: 14, height: 14)
                    Circle().fill(p.soft).overlay(Circle().stroke(Ink.line, lineWidth: 0.6)).frame(width: 14, height: 14)
                    Circle().fill(p.deep).frame(width: 14, height: 14)
                }
                Text(label).foregroundStyle(Ink.text)
                Spacer()
                if paletteSetting == key { Image(systemName: "checkmark").foregroundStyle(palette.deep) }
            }
        }
        .haptic(.selection, trigger: paletteSetting)
    }

    private func toggled(_ on: Bool) async {
        if on {
            if await Reminder.permission() == .notAsked { _ = await Reminder.requestPermission() }
            permission = await Reminder.permission()
            if permission == .allowed { await reschedule() } else { reminderOn = false }
        } else {
            await Reminder.cancel()
        }
    }

    private func reschedule() async {
        guard reminderOn else { return }
        await Reminder.schedule(hour: reminderMinutes / 60, minute: reminderMinutes % 60)
    }
}
