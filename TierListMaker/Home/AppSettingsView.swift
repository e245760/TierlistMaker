import SwiftUI

struct AppSettingsView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @Environment(\.setAppTheme) private var setAppTheme

    var body: some View {
        NavigationStack {
            Form {

                // ── テーマ ──
                Section("テーマ") {
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            let isSelected = appTheme == theme
                            Button {
                                withAnimation(.spring()) { setAppTheme(theme) }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: theme.icon)
                                        .font(.title2)
                                        .foregroundColor(isSelected ? .white : .primary)
                                    Text(theme.label)
                                        .font(.caption.bold())
                                        .foregroundColor(isSelected ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── ヘルプ ──
                Section("ヘルプ") {
                    NavigationLink {
                        HowToUseView()
                    } label: {
                        Label("使い方", systemImage: "book.pages")
                    }

                    NavigationLink {
                        FAQView()
                    } label: {
                        Label("よくある質問", systemImage: "questionmark.circle")
                    }
                }

                // ── アプリ情報 ──
                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(
                            Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                            as? String ?? "1.0.0"
                        )
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

// MARK: - 使い方

struct HowToUseView: View {
    private struct Step {
        let title: String
        let icon: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(title: "アイテムを追加する",   icon: "photo.badge.plus",
             detail: "「＋」ボタンからテキストや写真でアイテムを追加できます。"),
        Step(title: "アイテムを配置する",   icon: "hand.tap",
             detail: "プールのアイテムをタップして選択し、配置したいティア行をタップします。"),
        Step(title: "ドラッグで移動",       icon: "hand.draw",
             detail: "アイテムを長押しするとドラッグできます。別のティアへ移動したり、トレイへ戻したりできます。"),
        Step(title: "行を編集する",         icon: "pencil",
             detail: "ティアラベルをダブルタップまたは長押しすると、色・テキスト・サイズなどを編集できます。"),
        Step(title: "表全体の設定",         icon: "gearshape",
             detail: "右上の歯車アイコンから、ラベルサイズ・アイテムサイズ・テーマを一括変更できます。"),
        Step(title: "ライブラリに保存",     icon: "chevron.left",
             detail: "左上の「‹」ボタンで戻ると自動的にライブラリへ保存されます。"),
    ]

    var body: some View {
        List {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 34, height: 34)
                            Image(systemName: step.icon)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        Text(step.title)
                            .font(.headline)
                    }
                    Text(step.detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 46)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("使い方")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - よくある質問

struct FAQView: View {
    private struct FAQ {
        let question: String
        let answer: String
    }

    private let faqs: [FAQ] = [
        FAQ(question: "アイテムを削除するには？",
            answer: "アイテムをタップして選択し、「タップして編集」から編集シートを開くと削除できます。"),
        FAQ(question: "ティア行の順番を変えるには？",
            answer: "現バージョンでは行の並び替えは未対応です。今後のアップデートで対応予定です。"),
        FAQ(question: "ティア表はどこに保存されますか？",
            answer: "「‹」ボタンでライブラリに戻ると端末内に自動保存されます。"),
        FAQ(question: "画像アイテムの画質を上げるには？",
            answer: "アイテムサイズを「横長」に変更すると、より大きく鮮明に表示されます。"),
        FAQ(question: "ティア表を削除するには？",
            answer: "ライブラリのカードを長押しするとコンテキストメニューが表示され、削除できます。"),
    ]

    @State private var expandedIndex: Int? = nil

    var body: some View {
        List {
            ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedIndex == index },
                        set: { expandedIndex = $0 ? index : nil }
                    )
                ) {
                    Text(faq.answer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } label: {
                    Text(faq.question)
                        .font(.subheadline.bold())
                }
            }
        }
        .navigationTitle("よくある質問")
        .navigationBarTitleDisplayMode(.large)
    }
}
