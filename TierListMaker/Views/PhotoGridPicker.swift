import SwiftUI
import Photos

struct PhotoGridPicker: View {
    @Binding var addedAssetIds: Set<String>
    let onAdd: (Data) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var assets: [PHAsset] = []
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var selectedIds: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        NavigationStack {
            Group {
                switch authStatus {
                case .authorized, .limited:
                    photoGrid
                case .denied, .restricted:
                    deniedView
                case .notDetermined:
                    Color.clear
                @unknown default:
                    Color.clear
                }
            }
            .navigationTitle("写真を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加（\(selectedIds.count)枚）") {
                        addSelected()
                        dismiss()
                    }
                    .bold()
                    .disabled(selectedIds.isEmpty)
                }
            }
        }
        .onAppear {
            requestAuth()
        }
    }

    // ── フォトグリッド ──
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    PhotoGridCell(
                        asset: asset,
                        isAdded: addedAssetIds.contains(asset.localIdentifier),
                        isSelected: selectedIds.contains(asset.localIdentifier)
                    )
                    .onTapGesture {
                        // 追加済みはタップ不可
                        guard !addedAssetIds.contains(asset.localIdentifier) else { return }
                        withAnimation(.spring()) {
                            if selectedIds.contains(asset.localIdentifier) {
                                selectedIds.remove(asset.localIdentifier)
                            } else {
                                selectedIds.insert(asset.localIdentifier)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 権限拒否 ──
    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("写真へのアクセスが許可されていません")
                .font(.headline)
            Text("設定アプリから写真へのアクセスを許可してください")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // ── 権限リクエスト ──
    private func requestAuth() {
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    authStatus = status
                    if status == .authorized || status == .limited {
                        loadAssets()
                    }
                }
            }
        } else if authStatus == .authorized || authStatus == .limited {
            loadAssets()
        }
    }

    // ── 画像を読み込む ──
    private func loadAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var loaded: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            loaded.append(asset)
        }
        DispatchQueue.main.async {
            assets = loaded
        }
    }

    // ── 選択した画像を追加 ──
    private func addSelected() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat

        for id in selectedIds {
            guard let asset = assets.first(where: { $0.localIdentifier == id }) else { continue }
            manager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        onAdd(data)
                        addedAssetIds.insert(id)
                    }
                }
            }
        }
    }
}

// ── グリッドセル ──
struct PhotoGridCell: View {
    let asset: PHAsset
    let isAdded: Bool
    let isSelected: Bool

    @State private var image: UIImage? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGray5)
                        .overlay(ProgressView())
                }
            }
            .frame(width: cellSize, height: cellSize)
            .clipped()
            // 追加済みはグレーアウト
            .overlay(
                Color.black.opacity(isAdded ? 0.5 : 0)
            )
            // 選択中は青みがかる
            .overlay(
                Color.blue.opacity(isSelected ? 0.3 : 0)
            )
            .border(isSelected ? Color.blue : Color.clear, width: 3)

            if isAdded {
                // 追加済みバッジ
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                    .background(Color.white.clipShape(Circle()))
                    .padding(4)
            } else if isSelected {
                // 選択中バッジ
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .background(Color.white.clipShape(Circle()))
                    .padding(4)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .onAppear { loadImage() }
    }

    private var cellSize: CGFloat {
        (UIScreen.main.bounds.width - 6) / 3
    }

    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact

        let size = CGSize(width: cellSize * 2, height: cellSize * 2)
        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}
