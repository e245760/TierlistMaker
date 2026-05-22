import SwiftUI
import Photos

struct PhotoGridPicker: View {
    @Binding var addedAssetIds: Set<String>
    let onAdd: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var assets: [PHAsset] = []
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var selectedIds: Set<String> = []

    private let imageManager = PHCachingImageManager()

    // MARK: - UIサイズ（pt基準）
    private var itemSize: CGFloat {
        UIScreen.main.bounds.width / 3
    }

    // MARK: - Grid（固定）
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(itemSize), spacing: 2),
            count: 3
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch authStatus {
                case .authorized, .limited:
                    photoGrid

                case .denied, .restricted:
                    deniedView

                case .notDetermined:
                    ProgressView()

                @unknown default:
                    ProgressView()
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
        .onDisappear {
            imageManager.stopCachingImagesForAllAssets()
        }
    }

    // MARK: - Grid

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    PhotoGridCell(
                        asset: asset,
                        manager: imageManager,
                        itemSize: itemSize,
                        isAdded: addedAssetIds.contains(asset.localIdentifier),
                        isSelected: selectedIds.contains(asset.localIdentifier)
                    )
                    .onTapGesture {
                        guard !addedAssetIds.contains(asset.localIdentifier) else { return }
                        toggleSelection(asset.localIdentifier)
                    }
                }
            }
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    // MARK: - Auth

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

    // MARK: - Load

    private func loadAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        let result = PHAsset.fetchAssets(with: .image, options: options)

        var loaded: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            loaded.append(asset)
        }

        DispatchQueue.main.async {
            self.assets = loaded

            // 初期キャッシュ（軽量）
            let pixel = itemSize * UIScreen.main.scale

            imageManager.startCachingImages(
                for: Array(loaded.prefix(150)),
                targetSize: CGSize(width: pixel, height: pixel),
                contentMode: .aspectFill,
                options: nil
            )
        }
    }

    // MARK: - Add

    private func addSelected() {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let pixel = itemSize * UIScreen.main.scale
        let targetSize = CGSize(width: pixel, height: pixel)

        for id in selectedIds {
            guard let asset = assets.first(where: { $0.localIdentifier == id }) else { continue }

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard let image,
                      let data = image.jpegData(compressionQuality: 0.85)
                else { return }

                DispatchQueue.main.async {
                    onAdd(data)
                    addedAssetIds.insert(id)
                }
            }
        }
    }

    // MARK: - Denied

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("写真へのアクセスが許可されていません")
                .font(.headline)

            Button("設定を開く") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct PhotoGridCell: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    let itemSize: CGFloat

    let isAdded: Bool
    let isSelected: Bool

    @State private var image: UIImage?
    @State private var requestId: PHImageRequestID?

    var body: some View {
        ZStack(alignment: .topTrailing) {

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: itemSize, height: itemSize)
                        .clipped()
                } else {
                    Color(.systemGray5)
                        .frame(width: itemSize, height: itemSize)
                        .overlay(ProgressView())
                }
            }

            .overlay(Color.black.opacity(isAdded ? 0.4 : 0))
            .overlay(Color.blue.opacity(isSelected ? 0.3 : 0))
            .border(isSelected ? Color.blue : .clear, width: 2)

            if isAdded || isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(isAdded ? .green : .blue)
                    .padding(6)
            }
        }
        .onAppear { loadImage() }
        .onDisappear { cancelRequest() }
    }

    private func loadImage() {
        guard image == nil else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let pixel = itemSize * UIScreen.main.scale

        requestId = manager.requestImage(
            for: asset,
            targetSize: CGSize(width: pixel, height: pixel),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            guard let image else { return }
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }

    private func cancelRequest() {
        guard let requestId else { return }
        manager.cancelImageRequest(requestId)
    }
}
