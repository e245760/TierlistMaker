//
//  AddItemSheet.swift
//  TierListMaker
//
//  Created by Tome Kanya   on 2026/05/18.
//

import SwiftUI
import PhotosUI

struct AddItemSheet: View {
    @ObservedObject var vm: TierListViewModel
    @Environment(\.dismiss) var dismiss

    @State private var labelText = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("テキストで追加") {
                    TextField("アイテム名", text: $labelText)
                    Button("追加") {
                        guard !labelText.isEmpty else { return }
                        vm.addItem(label: labelText, imageData: imageData)
                        labelText = ""
                        imageData = nil
                    }
                    .disabled(labelText.isEmpty)
                }

                Section("写真で追加") {
                    PhotosPicker("写真を選ぶ", selection: $selectedPhoto, matching: .images)
                        .onChange(of: selectedPhoto) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    imageData = data
                                    vm.addItem(label: "", imageData: data)
                                }
                            }
                        }
                }
            }
            .navigationTitle("アイテム追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
