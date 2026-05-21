import SwiftUI
import PhotosUI

struct AddItemSheet: View {
    @ObservedObject var vm: TierListViewModel
    @Environment(\.dismiss) var dismiss

    @State private var labelText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var addedIndices: Set<Int> = []

    // 通知用
    @State private var showAddedFeedback = false
    @State private var feedbackWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {

            NavigationStack {
                Form {

                    // ── テキストで追加 ──
                    Section("テキストで追加") {

                        TextField("アイテム名", text: $labelText)

                        Button("追加") {
                            guard !labelText.isEmpty else { return }

                            vm.addItem(label: labelText)
                            showFeedback()

                            labelText = ""
                        }
                        .disabled(labelText.isEmpty)
                    }

                    // ── 写真で追加 ──
                    Section("写真で追加（複数選択可）") {

                        PhotosPicker(
                            "写真を選ぶ",
                            selection: $selectedPhotos,
                            maxSelectionCount: 50,
                            matching: .images
                        )
                        .onChange(of: selectedPhotos) { _ in
                            addedIndices = []
                        }

                        // プレビュー
                        if !selectedPhotos.isEmpty {

                            ScrollView(.horizontal, showsIndicators: false) {

                                HStack(spacing: 8) {

                                    ForEach(
                                        Array(selectedPhotos.enumerated()),
                                        id: \.offset
                                    ) { index, photo in

                                        PhotoThumbnailView(
                                            photo: photo,
                                            isAdded: addedIndices.contains(index)
                                        )
                                    }
                                }
                                .padding(.vertical, 8)
                            }

                            // まとめて追加
                            Button {

                                Task {

                                    for (index, item) in selectedPhotos.enumerated() {

                                        guard !addedIndices.contains(index)
                                        else { continue }

                                        if let data = try? await item
                                            .loadTransferable(type: Data.self)
                                        {

                                            await MainActor.run {

                                                vm.addItem(
                                                    label: "",
                                                    imageData: data
                                                )

                                                addedIndices.insert(index)

                                                showFeedback()
                                            }
                                        }
                                    }
                                }

                            } label: {

                                HStack {
                                    Spacer()

                                    Text(
                                        addedIndices.count
                                            == selectedPhotos.count
                                            ? "すべて追加済み"
                                            : "\(selectedPhotos.count - addedIndices.count)枚を追加"
                                    )
                                    .bold()

                                    Spacer()
                                }
                            }
                            .disabled(
                                addedIndices.count
                                    == selectedPhotos.count
                            )
                        }
                    }
                }
                .navigationTitle("アイテム追加")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
            }

            // ── 追加通知 ──
            if showAddedFeedback {

                ZStack {

                    Circle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: 90, height: 90)

                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                .transition(
                    .asymmetric(
                        insertion:
                            .scale(scale: 0.7)
                            .combined(with: .opacity),

                        removal:
                            .scale(scale: 1.2)
                            .combined(with: .opacity)
                    )
                )
                .zIndex(100)
            }
        }
    }

    // MARK: - Feedback

    private func showFeedback() {

        // 前回予約キャンセル
        feedbackWorkItem?.cancel()

        withAnimation(
            .spring(
                response: 0.3,
                dampingFraction: 0.65
            )
        ) {
            showAddedFeedback = true
        }

        let workItem = DispatchWorkItem {

            withAnimation(.easeOut(duration: 0.25)) {
                showAddedFeedback = false
            }
        }

        feedbackWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.8,
            execute: workItem
        )
    }
}

// MARK: - Photo Thumbnail

struct PhotoThumbnailView: View {

    let photo: PhotosPickerItem
    let isAdded: Bool

    @State private var uiImage: UIImage? = nil

    var body: some View {

        ZStack(alignment: .topTrailing) {

            Group {

                if let image = uiImage {

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()

                } else {

                    Color(.systemGray5)
                        .overlay(ProgressView())
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(isAdded ? 0.4 : 0))
            )

            if isAdded {

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .background(
                        Color.white.clipShape(Circle())
                    )
                    .offset(x: 4, y: -4)
            }
        }
        .task {

            if let data = try? await photo
                .loadTransferable(type: Data.self),
               let image = UIImage(data: data)
            {

                let thumbnail = await image.byPreparingThumbnail(
                    ofSize: CGSize(width: 140, height: 140)
                )

                await MainActor.run {
                    uiImage = thumbnail ?? image
                }
            }
        }
    }
}
