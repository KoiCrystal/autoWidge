//
//  InstanceEditorView.swift
//  Auto Widget
//
//  Created by Zhaomin Wu & Jinyu Zhang on 2026/8/30.
//

import SwiftUI
import AppIntents
import WidgetKit
import PhotosUI // 相册选择组件

enum BackgroundMode: String, CaseIterable {
    case system = "system"
    case color = "color"
    case image = "image"
    
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .color: return "自定义颜色"
        case .image: return "自定义图片"
        }
    }
}

struct InstanceEditorView: View {
    
    let existingInstance: WidgetDataSourceEntity?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    // 背景相关状态
    @State private var backgroundMode: BackgroundMode = .system
    @State private var selectedColor: Color = .white
    @State private var selectedFontSize: CGFloat = 17
    @State private var currentText: String = "暂无文本"
    
    // 图片选择状态
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var savedImageFileName: String? = nil
    @State private var imageScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var onSaved: (String) -> Void
    
    init(existingInstance: WidgetDataSourceEntity? = nil, onSaved: @escaping (String) -> Void) {
        self.existingInstance = existingInstance
        self.onSaved = onSaved
        _name = State(initialValue: existingInstance?.name ?? "")
        
        if let instance = existingInstance {
            let all = WidgetInstanceQuery().loadAllInstances()
            if let latest = all.first(where: { $0.id == instance.id }) {
                _currentText = State(initialValue: latest.text ?? "暂无文本")
                _selectedFontSize = State(initialValue: latest.fontSize ?? 17)
                
                // 恢复背景模式
                let mode = latest.backgroundType ?? (latest.backgroundColorName != nil ? "color" : "system")
                _backgroundMode = State(initialValue: BackgroundMode(rawValue: mode) ?? .system)
                
                // 恢复颜色
                if let colorHex = latest.backgroundColorName {
                    _selectedColor = State(initialValue: Color(hex: colorHex))
                }
                
                // 恢复图片
                if let imageName = latest.backgroundImageName {
                    _savedImageFileName = State(initialValue: imageName)
                    _selectedImage = State(initialValue: SharedImageHelper.loadImage(fileName: imageName))
                }
            }
        }
    }
    
    // 预览用的 Entry
    private var previewEntry: SimpleEntry {
        let config = ConfigurationAppIntent()
        let mockEntity = WidgetDataSourceEntity(
            id: existingInstance?.id ?? "preview_id",
            name: name.isEmpty ? "小组件名称" : name,
            text: currentText,
            backgroundColorName: selectedColor.toHex(),
            backgroundType: backgroundMode.rawValue,
            backgroundImageName: savedImageFileName,
            fontSize: selectedFontSize
        )
        config.instance = mockEntity
        // 这里传入 resolvedInstance: mockEntity
        return SimpleEntry(date: Date(), configuration: config, resolvedInstance: mockEntity, text: currentText)
    }
    
    var body: some View {
        Form {
            // 名称输入
            Section {
                TextField("新建实例", text: $name, axis: .vertical)
                    .font(.system(size: 28, weight: .bold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(1...3)
                    .padding(.vertical, 6)
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .listRowBackground(Color.clear)
            
            // 小组件预览
            Section {
                VStack {
                    ZStack {
                        // 背景渲染与手势交互
                        Group {
                            switch backgroundMode {
                            case .system:
                                ContainerRelativeShape().fill(Color(.systemBackground))
                            case .color:
                                selectedColor
                            case .image:
                                if let selectedImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .scaledToFit() // 💡 改为 scaledToFit，完整展示长方形原图
                                        .scaleEffect(imageScale)
                                        .offset(imageOffset)
                                        .gesture(
                                            SimultaneousGesture(
                                                MagnifyGesture()
                                                    .onChanged { value in
                                                        let delta = value.magnification / lastScale
                                                        lastScale = value.magnification
                                                        imageScale = min(max(imageScale * delta, 0.2), 6.0)
                                                    }
                                                    .onEnded { _ in
                                                        lastScale = 1.0
                                                    },
                                                DragGesture()
                                                    .onChanged { value in
                                                        let translation = value.translation
                                                        imageOffset = CGSize(
                                                            width: lastOffset.width + translation.width,
                                                            height: lastOffset.height + translation.height
                                                        )
                                                    }
                                                    .onEnded { _ in
                                                        lastOffset = imageOffset
                                                    }
                                            )
                                        )
                                } else {
                                    Color(.systemGray5)
                                }
                            }
                        }
                        
                        // 顶层叠加小组件文字
                        ShowWidgetEntryView(entry: previewEntry)
                            .allowsHitTesting(false)
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                    .padding(16)
                    
                    if backgroundMode == .image && selectedImage != nil {
                        Text("提示：可双指缩放查看长方形原图，单指拖动调整小组件内显示的区域")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .listSectionSeparator(.hidden)
            
            // 背景设置：系统列表样式，选中后打勾，并动态展开对应控件
            Section("背景样式") {
                // 1. 跟随系统
                Button {
                    backgroundMode = .system
                } label: {
                    HStack {
                        Text(BackgroundMode.system.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if backgroundMode == .system {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                
                // 2. 自定义颜色
                Button {
                    backgroundMode = .color
                } label: {
                    HStack {
                        Text(BackgroundMode.color.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if backgroundMode == .color {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                
                // 只有当选中“自定义颜色”时才出现取色器
                if backgroundMode == .color {
                    ColorPicker("选择背景颜色", selection: $selectedColor)
                        .foregroundStyle(.tint)
                }
                
                // 3. 自定义图片
                Button {
                    backgroundMode = .image
                } label: {
                    HStack {
                        Text(BackgroundMode.image.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if backgroundMode == .image {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                
                // 只有当选中“自定义图片”时才出现图片选择器
                if backgroundMode == .image {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Text("选择背景图片")
                            Spacer()
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Text("未选择")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                selectedImage = uiImage
                                let instanceID = existingInstance?.id ?? UUID().uuidString
                                if let fileName = SharedImageHelper.saveImage(uiImage, for: instanceID) {
                                    savedImageFileName = fileName
                                }
                            }
                        }
                    }
                }
            }
            
            // 文字大小设置
            Section("外观设置") {
                VStack(alignment: .leading) {
                    Text("文字大小: \(Int(selectedFontSize)) pt")
                    Slider(value: $selectedFontSize, in: 12...32, step: 1)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    public func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        isSaving = true
        errorMessage = nil
        
        let query = WidgetInstanceQuery()
        var instances = query.loadAllInstances()
        let colorHex = selectedColor.toHex()
        let instanceID = existingInstance?.id ?? UUID().uuidString
        
        // 💡 如果当前是图片模式，利用 ImageRenderer 将用户调整好的缩放/平移画面“快照裁切”为最终图片
        if backgroundMode == .image, let selectedImage = selectedImage {
            let finalImage = await renderCroppedImage(image: selectedImage, scale: imageScale, offset: imageOffset)
            if let finalImage, let fileName = SharedImageHelper.saveImage(finalImage, for: instanceID) {
                savedImageFileName = fileName
            }
        }
        
        if let existing = existingInstance {
            if let index = instances.firstIndex(where: { $0.id == existing.id }) {
                instances[index].name = trimmed
                instances[index].backgroundColorName = colorHex
                instances[index].backgroundType = backgroundMode.rawValue
                instances[index].backgroundImageName = savedImageFileName
                instances[index].fontSize = selectedFontSize
                
                query.saveInstances(instances)
                currentText = instances[index].text ?? "暂无文本"
                dismiss()
            } else {
                errorMessage = "更新失败：未找到该实例"
            }
        } else {
            let newInstance = WidgetDataSourceEntity(
                id: instanceID,
                name: trimmed,
                backgroundColorName: colorHex,
                backgroundType: backgroundMode.rawValue,
                backgroundImageName: savedImageFileName,
                fontSize: selectedFontSize
            )
            instances.append(newInstance)
            query.saveInstances(instances)
            currentText = "暂无文本"
            dismiss()
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        isSaving = false
    }
}

@MainActor
private func renderCroppedImage(image: UIImage, scale: CGFloat, offset: CGSize) -> UIImage? {
    let renderView = ZStack {
        Image(uiImage: image)
            .resizable()
            .scaledToFit() // 💡 保持与预览一致
            .scaleEffect(scale)
            .offset(offset)
    }
    .frame(width: 300, height: 300) // 高分辨率正方形画布
    .clipped()
    
    let renderer = ImageRenderer(content: renderView)
    renderer.scale = 2.0 // 2x Retina 清晰度
    return renderer.uiImage
}







// MARK: photo
struct SharedImageHelper {
    // 将图片保存到 App Group 共享容器
    static func saveImage(_ image: UIImage, for instanceID: String) -> String? {
        let fileName = "widget_bg_\(instanceID).jpg"
        guard let data = image.jpegData(compressionQuality: 0.85),
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.autowidget.app2widget") else {
            return nil
        }
        let fileURL = containerURL.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("保存小组件背景图片失败: \(error)")
            return nil
        }
    }
    
    // 从 App Group 共享容器加载图片
    static func loadImage(fileName: String?) -> UIImage? {
        guard let fileName = fileName,
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.autowidget.app2widget") else {
            return nil
        }
        let fileURL = containerURL.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: fileURL) {
            return UIImage(data: data)
        }
        return nil
    }
}



extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (24位) -> #RRGGBB
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: // RGBA (32位) -> #RRGGBBAA
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
    
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        let a = Int(alpha * 255)
        
        return String(format: "#%02x%02x%02x%02x", r, g, b, a)
    }
}
