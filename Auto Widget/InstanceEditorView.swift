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

// 💡 新增：文字颜色模式枚举
enum TextColorMode: String, CaseIterable {
    case system = "system"
    case color = "color"
    
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .color: return "自定义颜色"
        }
    }
}

struct InstanceEditorView: View {
    
    let existingInstance: WidgetDataSourceEntity?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase // 监听应用生命周期状态
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var textUpdatedAt: Date?
    
    
    // 背景相关状态
    @State private var backgroundMode: BackgroundMode = .system
    @State private var selectedColor: Color = .white
    @State private var currentText: String = "暂无文本"
    
    // 外观与字体相关状态
    @State private var textColorMode: TextColorMode = .system // 💡 文字颜色模式
    @State private var textColor: Color = .white
    @State private var selectedFontWeight: CGFloat = 400.0
    @State private var lastHapticBucket: Int? = nil
    @State private var weightHapticGenerator = UISelectionFeedbackGenerator()
    @State private var fontStyle: String = "system"
    @State private var customFontName: String? = nil // 💡 新增自定义字体名称状态
    @State private var savedCustomFonts: [CustomFontEntity] = [] // 💡 已导入的自定义字体列表
    @State private var isLiquidGlass: Bool = false
    @State private var selectedFontSize: CGFloat = 17
    
    // 图片选择状态
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var savedImageFileName: String? = nil
    @State private var imageScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    
    @State private var previousBackgroundMode: BackgroundMode = .system // 💡 正确使用 @State 修饰
    
    @FocusState private var isNameFocused: Bool // 💡 用于控制键盘收起状态
    
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
                _textUpdatedAt = State(initialValue: latest.textUpdatedAt)
                
                // 恢复背景模式
                let mode = latest.backgroundType ?? (latest.backgroundColorName != nil ? "color" : "system")
                _backgroundMode = State(initialValue: BackgroundMode(rawValue: mode) ?? .system)
                
                // 恢复背景颜色
                if let colorHex = latest.backgroundColorName {
                    _selectedColor = State(initialValue: Color(hex: colorHex))
                }
                
                // 恢复文字颜色模式与颜色
                let tMode = latest.textColorType ?? (latest.textColorName != nil ? "color" : "system")
                _textColorMode = State(initialValue: TextColorMode(rawValue: tMode) ?? .system)
                if let tColorHex = latest.textColorName {
                    _textColor = State(initialValue: Color(hex: tColorHex))
                }
                
                _fontStyle = State(initialValue: "system")
                _customFontName = State(initialValue: latest.customFontName) // 💡 恢复自定义字体
                _isLiquidGlass = State(initialValue: latest.isLiquidGlass ?? false)
                _selectedFontWeight = State(initialValue: latest.fontWeight ?? 400.0)
                
                // 恢复图片
                if let imageName = latest.backgroundImageName {
                    _savedImageFileName = State(initialValue: imageName)
                    _selectedImage = State(initialValue: SharedImageHelper.loadImage(fileName: imageName))
                }
            }
        }
    }
    
    // 当前选中字体的字重调节能力
    private var currentFontWeightCapability: FontWeightCapability {
        CustomFontManager.shared.weightCapability(for: customFontName)
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
            fontSize: selectedFontSize,
            fontWeight: selectedFontWeight,
            textColorType: textColorMode.rawValue,
            textColorName: textColorMode == .color ? textColor.toHex() : nil,
            fontStyle: fontStyle,
            customFontName: customFontName,
            isLiquidGlass: isLiquidGlass
        )
        config.instance = mockEntity
        return SimpleEntry(date: Date(), configuration: config, resolvedInstance: mockEntity, text: currentText)
    }
    
    var body: some View {
        Form {
            // 名称输入
            Section {
                TextField("新建实例", text: $name)
                    .font(.system(size: 28, weight: .bold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.vertical, 6)
                    .focused($isNameFocused)
                    .submitLabel(.done) // 将回车键显示为“完成”
                    .onSubmit {
                        isNameFocused = false
                        
                    }
                          
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .listRowBackground(Color.clear)
            
            // 小组件预览
            Section {
                VStack(spacing: 8) { // 加上固定的子元素间距
                    ZStack {
                        Group {
                            switch backgroundMode {
                            case .system:
                                ContainerRelativeShape().fill(Color(.systemBackground))
                            case .color:
                                selectedColor
                            case .image:
                                if let selectedImage {
                                    GeometryReader { proxy in
                                        let containerSize = proxy.size
                                        let imageSize = selectedImage.size
                                        
                                        // 💡 保证长宽同时填满容器（scaledToFill 的基准比例）
                                        let widthRatio = containerSize.width / imageSize.width
                                        let heightRatio = containerSize.height / imageSize.height
                                        let baseFillScale = max(widthRatio, heightRatio)
                                        
                                        let currentScale = baseFillScale * imageScale
                                        
                                        // 实时计算填满容器后允许的最大拖动偏移边界
                                        let renderedWidth = imageSize.width * currentScale
                                        let renderedHeight = imageSize.height * currentScale
                                        let maxOffsetX = max(0, (renderedWidth - containerSize.width) / 2)
                                        let maxOffsetY = max(0, (renderedHeight - containerSize.height) / 2)
                                        
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .scaledToFill()
                                            .scaleEffect(imageScale)
                                            .offset(imageOffset)
                                            .frame(width: containerSize.width, height: containerSize.height)
                                            .clipped()
                                            .gesture(
                                                SimultaneousGesture(
                                                    MagnifyGesture()
                                                        .onChanged { value in
                                                            let delta = value.magnification / lastScale
                                                            lastScale = value.magnification
                                                            
                                                            // 缩放比例限制：确保绝不小于 1.0（即不能缩得比填满容器更小）
                                                            let newScale = min(max(imageScale * delta, 1.0), 6.0)
                                                            imageScale = newScale
                                                            
                                                            // 缩放时同步矫正偏移，防止产生空白
                                                            let newRenderedW = imageSize.width * baseFillScale * imageScale
                                                            let newRenderedH = imageSize.height * baseFillScale * imageScale
                                                            let newMaxX = max(0, (newRenderedW - containerSize.width) / 2)
                                                            let newMaxY = max(0, (newRenderedH - containerSize.height) / 2)
                                                            
                                                            imageOffset = CGSize(
                                                                width: min(max(imageOffset.width, -newMaxX), newMaxX),
                                                                height: min(max(imageOffset.height, -newMaxY), newMaxY)
                                                            )
                                                            lastOffset = imageOffset
                                                        }
                                                        .onEnded { _ in
                                                            lastScale = 1.0
                                                        },
                                                    DragGesture()
                                                        .onChanged { value in
                                                            let translation = value.translation
                                                            let targetX = lastOffset.width + translation.width
                                                            let targetY = lastOffset.height + translation.height
                                                            
                                                            // 严格限制拖动范围在安全边界内，绝不留白
                                                            imageOffset = CGSize(
                                                                width: min(max(targetX, -maxOffsetX), maxOffsetX),
                                                                height: min(max(targetY, -maxOffsetY), maxOffsetY)
                                                            )
                                                        }
                                                        .onEnded { _ in
                                                            lastOffset = imageOffset
                                                        }
                                                )
                                            )
                                    }
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
                    
                    // 💡 关键修改：用固定高度的容器包裹提示文字，彻底消除跳动
                    ZStack {
                        Text("双指缩放，单指拖动")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            // 只有当满足条件时才显现，不满足时透明度为 0 但依然占位
                            .opacity((backgroundMode == .image && selectedImage != nil) ? 1 : 0)
                    }

                    .animation(.easeInOut(duration: 0.2), value: backgroundMode == .image && selectedImage != nil)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .listSectionSeparator(.hidden)
            
            // 背景设置
            Section("背景样式") {
                VStack(spacing: 14) {

                    // MARK: 三选一选择器（点击时计算左右滑动方向）
                    HStack(spacing: 10) {
                        backgroundModeButton(mode: .system, title: "系统", icon: "sun.max")
                        backgroundModeButton(mode: .color, title: "颜色", icon: "paintpalette")
                        backgroundModeButton(mode: .image, title: "图片", icon: "photo")
                    }

                    // MARK: 独立配置卡片
                    VStack(alignment: .leading, spacing: 0) {
                        
                        let allCases = BackgroundMode.allCases
                        let currentIndex = allCases.firstIndex(of: backgroundMode) ?? 0
                        let prevIndex = allCases.firstIndex(of: previousBackgroundMode) ?? 0
                        let isMovingForward = currentIndex > prevIndex
                        
                        let insertionEdge: Edge = isMovingForward ? .trailing : .leading
                        let removalEdge: Edge = isMovingForward ? .leading : .trailing

                        // 💡 核心：ZStack 堆叠各个完整的卡片视图
                        ZStack(alignment: .topLeading) {
                            
                            // 1. 系统模式卡片
                            if backgroundMode == .system {
                                VStack(alignment: .leading, spacing: 0) {
                                    Label("背景将跟随系统外观自动调整", systemImage: "info.circle")
                                        .font(.subheadline)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: insertionEdge),
                                    removal: .move(edge: removalEdge)
                                ))
                            }

                            // 2. 颜色模式卡片
                            if backgroundMode == .color {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("自定义背景颜色与透明度")
                                                .font(.subheadline)
                                        }
                                        Spacer()
                                        ColorPicker("选择颜色", selection: $selectedColor, supportsOpacity: true)
                                            .labelsHidden()
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: insertionEdge),
                                    removal: .move(edge: removalEdge)
                                ))
                            }

                            // 3. 图片模式卡片
                            if backgroundMode == .image {
                                VStack(alignment: .leading, spacing: 12) {
                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                        HStack {
                                            Label(
                                                selectedImage == nil ? "选择背景图片" : "更换背景图片",
                                                systemImage: "photo"
                                            )
                                            Spacer()
                                            if let selectedImage {
                                                Image(uiImage: selectedImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 40, height: 40)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else {
                                                Image(systemName: "chevron.right")
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        .foregroundStyle(.primary)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Text("可在上方预览中双指缩放、拖动调整图片显示区域。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .opacity(selectedImage != nil ? 1 : 0.0)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: insertionEdge),
                                    removal: .move(edge: removalEdge)
                                ))
                            }
                        }
                        // 💡 联动动画与边界裁剪：整个卡片容器平滑滑动，超出部分被裁剪掉
                        .animation(.snappy(duration: 0.3), value: backgroundMode)
                        .animation(.easeInOut(duration: 0.2), value: selectedImage != nil)
                        .clipped()
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            
            // 💡 文字与外观设置
            Section("TEXT") {
                
                // 1. 文字颜色：跟随系统
                Button { textColorMode = .system } label: {
                    HStack {
                        Text(" \(TextColorMode.system.title)")
                        Spacer()
                        if textColorMode == .system {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                        }
                    }
                }.foregroundStyle(.primary)
                
                // 2. 文字颜色：自定义颜色
                Button { textColorMode = .color } label: {
                    HStack {
                        Text("\(TextColorMode.color.title)")
                        Spacer()
                        if textColorMode == .color {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                        }
                    }
                }.foregroundStyle(.primary)
                
                // 只有当选中“自定义颜色”时才动态展开取色器
                if textColorMode == .color {
                    ColorPicker("选择文字颜色与透明度", selection: $textColor)
                }
                
                // 合并后的字体选择（系统默认与预设字体合并，下方为自定义导入字体）
                let presetFonts = savedCustomFonts.filter { $0.isPreset }
                let userFonts = savedCustomFonts.filter { !$0.isPreset }
                
                Picker("字体样式", selection: Binding(
                    get: {
                        if let canonical = CustomFontManager.shared.canonicalFontName(for: customFontName),
                           !canonical.isEmpty {
                            return "custom_\(canonical)"
                        } else {
                            return "system"
                        }
                    },
                    set: { newValue in
                        if newValue.hasPrefix("custom_") {
                            let fontName = String(newValue.dropFirst(7))
                            customFontName = fontName
                            fontStyle = "system"
                        } else {
                            customFontName = nil
                            fontStyle = "system"
                        }
                    }
                )) {
                    Section("预设字体") {
                        Text("系统默认").tag("system")
                        ForEach(presetFonts) { font in
                            Text(font.displayName).tag("custom_\(font.name)")
                        }
                    }
                    
                    if !userFonts.isEmpty {
                        Section("自定义字体") {
                            ForEach(userFonts) { font in
                                Text(font.displayName).tag("custom_\(font.name)")
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("文字大小: \(Int(selectedFontSize)) pt")
                    Slider(value: $selectedFontSize, in: 12...32, step: 1)
                }
                
                fontWeightControl
            }
            
            Section {
                HStack {
                    Text("最后更新时间")
                        .foregroundStyle(.primary)
                    Spacer()
                    if let textUpdatedAt {
                        HStack(spacing: 0) {
                            Text(textUpdatedAt, style: .relative)
                            Text("前")
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Text("从未通过快捷指令更新")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        .onAppear {
            reloadLatestData()
            setupDarwinNotification()
            CustomFontManager.shared.registerAllFonts()
            savedCustomFonts = CustomFontManager.shared.loadSavedFonts() // 💡 加载预设与已保存的自定义字体
            normalizeWeightForCurrentFont()
        }
        .onChange(of: customFontName) { _, _ in
            normalizeWeightForCurrentFont()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                reloadLatestData()
                CustomFontManager.shared.registerAllFonts()
                savedCustomFonts = CustomFontManager.shared.loadSavedFonts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WidgetTextDidUpdateNotification"))) { _ in
            reloadLatestData()
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
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let newItem else { return }
                
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    await MainActor.run {
                        selectedImage = uiImage
                        imageScale = 1.0
                        lastScale = 1.0
                        imageOffset = .zero
                        lastOffset = .zero
                    }
                }
            }
        }
    }
    
    // MARK: - 自适应字体粗细控件
    @ViewBuilder
    private var fontWeightControl: some View {
        switch currentFontWeightCapability {
        case .discrete(let values, let defaultValue):
            let sorted = values.sorted()
            if sorted.count <= 1 {
                HStack {
                    Text("字体粗细")
                    Spacer()
                    Text("当前字体不支持调节")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                let currentIndex = sorted.indices.min(by: {
                    abs(sorted[$0] - selectedFontWeight) < abs(sorted[$1] - selectedFontWeight)
                }) ?? (sorted.firstIndex(of: defaultValue) ?? 0)
                
                let indexBinding = Binding<Double>(
                    get: { Double(currentIndex) },
                    set: { newIndex in
                        let idx = min(max(Int(newIndex.rounded()), 0), sorted.count - 1)
                        let snapped = sorted[idx]
                        selectedFontWeight = snapped
                        triggerWeightHapticIfNeeded(bucket: idx)
                    }
                )
                
                let ticks = sorted.enumerated().map { idx, val in
                    WeightTickItem(value: CGFloat(idx), label: "\(Int(val.rounded()))", isMajor: true)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("字体粗细")
                        Spacer()
                        Text(CustomFontManager.shared.discreteWeightDisplayName(for: sorted[currentIndex]))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: indexBinding, in: 0...Double(sorted.count - 1), step: 1) { editing in
                        if editing {
                            lastHapticBucket = currentIndex
                            weightHapticGenerator.prepare()
                        }
                    }
                    WeightTickBar(ticks: ticks, minValue: 0, maxValue: CGFloat(sorted.count - 1))
                }
            }
            
        case .variable(let minVal, let maxVal, _):
            let span = maxVal - minVal
            let useIntegerDisplay = span >= 20
            let hapticInterval = max(span / 16.0, 0.01)
            let clampedBinding = Binding<CGFloat>(
                get: { min(max(selectedFontWeight, minVal), maxVal) },
                set: { newValue in
                    let clamped = min(max(newValue, minVal), maxVal)
                    selectedFontWeight = clamped
                    let bucket = Int(((clamped - minVal) / hapticInterval).rounded())
                    triggerWeightHapticIfNeeded(bucket: bucket)
                }
            )
            let formattedValue = useIntegerDisplay
                ? "\(Int(clampedBinding.wrappedValue.rounded()))"
                : String(format: "%.2f", clampedBinding.wrappedValue)
            let ticks = buildVariableTicks(minVal: minVal, maxVal: maxVal, useIntegerDisplay: useIntegerDisplay)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("字体粗细")
                    Spacer()
                    Text(formattedValue)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if useIntegerDisplay {
                    Slider(value: clampedBinding, in: minVal...maxVal, step: 1) { editing in
                        if editing {
                            lastHapticBucket = Int(((clampedBinding.wrappedValue - minVal) / hapticInterval).rounded())
                            weightHapticGenerator.prepare()
                        }
                    }
                } else {
                    Slider(value: clampedBinding, in: minVal...maxVal) { editing in
                        if editing {
                            lastHapticBucket = Int(((clampedBinding.wrappedValue - minVal) / hapticInterval).rounded())
                            weightHapticGenerator.prepare()
                        }
                    }
                }
                WeightTickBar(ticks: ticks, minValue: minVal, maxValue: maxVal)
            }
            
        case .fixed:
            HStack {
                Text("字体粗细")
                Spacer()
                Text("当前字体不支持调节")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func triggerWeightHapticIfNeeded(bucket: Int) {
        if lastHapticBucket == nil {
            lastHapticBucket = bucket
            return
        }
        if lastHapticBucket != bucket {
            lastHapticBucket = bucket
            weightHapticGenerator.selectionChanged()
            weightHapticGenerator.prepare()
        }
    }
    
    private func buildVariableTicks(minVal: CGFloat, maxVal: CGFloat, useIntegerDisplay: Bool) -> [WeightTickItem] {
        let span = maxVal - minVal
        if useIntegerDisplay,
           minVal.truncatingRemainder(dividingBy: 100) == 0,
           maxVal.truncatingRemainder(dividingBy: 100) == 0 {
            let count = Int((span / 100).rounded())
            if count >= 2 && count <= 8 {
                return (0...count).map { idx in
                    let val = minVal + CGFloat(idx) * 100
                    return WeightTickItem(value: val, label: "\(Int(val))", isMajor: true)
                }
            }
        }
        
        let segments = 8
        return (0...segments).map { idx in
            let progress = CGFloat(idx) / CGFloat(segments)
            let val = minVal + span * progress
            let isMajor = idx % 2 == 0
            let label: String? = if isMajor {
                useIntegerDisplay ? "\(Int(val.rounded()))" : String(format: "%.1f", val)
            } else {
                nil
            }
            return WeightTickItem(value: val, label: label, isMajor: isMajor)
        }
    }
    
    private func normalizeWeightForCurrentFont() {
        lastHapticBucket = nil
        switch currentFontWeightCapability {
        case .discrete(let values, let defaultValue):
            selectedFontWeight = values.min(by: { abs($0 - selectedFontWeight) < abs($1 - selectedFontWeight) }) ?? defaultValue
        case .variable(let minVal, let maxVal, _):
            selectedFontWeight = min(max(selectedFontWeight, minVal), maxVal)
        case .fixed:
            break
        }
    }
    
    private func setupDarwinNotification() {
        guard let instanceID = existingInstance?.id else { return }
        let notificationName = "com.autowidget.textUpdated.\(instanceID)"
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                NotificationCenter.default.post(name: Notification.Name("WidgetTextDidUpdateNotification"), object: nil)
            },
            notificationName as CFString,
            nil,
            .deliverImmediately
        )
    }
    
    public func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        isSaving = true
        errorMessage = nil
        
        let query = WidgetInstanceQuery()
        var instances = query.loadAllInstances()
        let colorHex = selectedColor.toHex()
        
        let textColorHex = textColorMode == .color ? textColor.toHex() : nil
        let textColorType = textColorMode.rawValue
        
        let instanceID = existingInstance?.id ?? UUID().uuidString
        
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
                instances[index].fontWeight = selectedFontWeight
                instances[index].textColorName = textColorHex
                instances[index].textColorType = textColorType
                instances[index].fontStyle = fontStyle
                instances[index].customFontName = customFontName // 💡 保存自定义字体
                instances[index].isLiquidGlass = isLiquidGlass
                
                query.saveInstances(instances)
                currentText = instances[index].text ?? "暂无文本"
                WidgetCenter.shared.reloadTimelines(ofKind: "ShowWidget")
                WidgetCenter.shared.reloadAllTimelines()
                onSaved("已保存修改")
                dismiss()
            } else {
                errorMessage = "更新失败：未找到该实例"
            }
        } else {
            let newInstance = WidgetDataSourceEntity(
                id: instanceID,
                name: trimmed,
                textUpdatedAt: nil,
                backgroundColorName: colorHex,
                backgroundType: backgroundMode.rawValue,
                backgroundImageName: savedImageFileName,
                fontSize: selectedFontSize,
                fontWeight: selectedFontWeight,
                textColorType: textColorType,
                textColorName: textColorHex,
                fontStyle: fontStyle,
                customFontName: customFontName, // 💡 保存自定义字体
                isLiquidGlass: isLiquidGlass
            )
            instances.append(newInstance)
            query.saveInstances(instances)
            currentText = "暂无文本"
            WidgetCenter.shared.reloadTimelines(ofKind: "ShowWidget")
            WidgetCenter.shared.reloadAllTimelines()
            onSaved("创建成功")
            dismiss()
        }
        
        isSaving = false
    }
    
    // MARK: - 重新加载最新数据（解决更新时间不刷新的问题）
    private func reloadLatestData() {
        guard let existing = existingInstance else { return }
        
        let all = WidgetInstanceQuery().loadAllInstances()
        guard let latest = all.first(where: { $0.id == existing.id }) else { return }
        
        if latest.text != currentText || latest.textUpdatedAt != textUpdatedAt {
            currentText = latest.text ?? "暂无文本"
            textUpdatedAt = latest.textUpdatedAt
        }
    }
    
    // MARK: - 背景模式选择按钮
    @ViewBuilder
    private func backgroundModeButton(
        mode: BackgroundMode,
        title: String,
        icon: String
    ) -> some View {
        let isSelected = backgroundMode == mode

        Button {
            withAnimation(.snappy(duration: 0.3)) {
                previousBackgroundMode = backgroundMode 
                backgroundMode = mode
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(
                        isSelected ? Color.accentColor : Color.secondary
                    )

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.10)
                    : Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 1.5
                )
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.accentColor)
                        .padding(7)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WeightTickItem {
    let value: CGFloat
    let label: String?
    let isMajor: Bool
}

private struct WeightTickBar: View {
    let ticks: [WeightTickItem]
    let minValue: CGFloat
    let maxValue: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let trackWidth = max(geo.size.width, 1)
            let span = max(maxValue - minValue, 0.0001)
            
            ZStack(alignment: .topLeading) {
                ForEach(Array(ticks.enumerated()), id: \.offset) { _, tick in
                    let progress = min(max((tick.value - minValue) / span, 0), 1)
                    let x = trackWidth * progress
                    
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(tick.isMajor ? Color.secondary.opacity(0.65) : Color.secondary.opacity(0.3))
                            .frame(width: tick.isMajor ? 1.5 : 1, height: tick.isMajor ? 6 : 4)
                            .frame(height: 6, alignment: .top)
                        
                        Text(tick.label ?? " ")
                            .font(.system(size: 10, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .opacity(tick.label == nil ? 0 : 1)
                    }
                    .position(x: x, y: 11)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 22)
        .allowsHitTesting(false)
    }
}

@MainActor
private func renderCroppedImage(image: UIImage, scale: CGFloat, offset: CGSize) -> UIImage? {
    let renderView = ZStack {
        GeometryReader { proxy in
            let containerSize = proxy.size
            let imageSize = image.size
            let widthRatio = containerSize.width / imageSize.width
            let heightRatio = containerSize.height / imageSize.height
            let baseFillScale = max(widthRatio, heightRatio)
            
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: containerSize.width, height: containerSize.height)
        }
    }
    .frame(width: 300, height: 300)
    .clipped()
    
    let renderer = ImageRenderer(content: renderView)
    renderer.scale = 2.0
    return renderer.uiImage
}

// MARK: photo
struct SharedImageHelper {
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
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
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
