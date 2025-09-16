//
//  DesignPreview.swift
//  Winkkk
//
//  UI设计风格预览页面
//  仅用于预览，不影响主应用编译
//

import SwiftUI

// MARK: - 方案一：小红书风格 - 简约清新
struct DesignOption1_Preview: View {
    @State private var isRecording = false
    @State private var recordingTime = "00:00"
    @State private var currentTime: Double = 30.0
    @State private var duration: Double = 120.0
    
    var body: some View {
        ZStack {
            // 背景：白色主色调
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部状态栏区域
                HStack {
                    Text("Winkkk")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    if isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isRecording ? 1.2 : 0.8)
                                .animation(.easeInOut(duration: 0.8).repeatForever(), value: isRecording)
                            
                            Text(recordingTime)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // 相机预览区域（用渐变模拟）
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.black.opacity(0.8), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Text("相机预览")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.title2)
                    )
                    .frame(maxHeight: .infinity)
                
                // 底部控制面板：扁平化设计，圆角卡片
                VStack(spacing: 20) {
                    // 时间轴：细线条设计，粉色拖拽点
                    VStack(spacing: 12) {
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(formatTime(duration))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        ZStack(alignment: .leading) {
                            // 背景线条
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 2)
                            
                            // 进度线条
                            Rectangle()
                                .fill(Color.pink.opacity(0.8))
                                .frame(width: max(0, CGFloat(currentTime / duration) * 300), height: 2)
                            
                            // 粉色小圆点拖拽指示器
                            Circle()
                                .fill(Color.pink)
                                .frame(width: 16, height: 16)
                                .offset(x: CGFloat(currentTime / duration) * 284)
                                .shadow(color: .pink.opacity(0.3), radius: 4)
                        }
                        .frame(width: 300, height: 20)
                    }
                    
                    // 按钮区域
                    HStack(spacing: 40) {
                        // 相册按钮：线性图标
                        Button(action: {}) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.black)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        
                        // 录制按钮：大圆形，粉色渐变
                        Button(action: { isRecording.toggle() }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.pink.opacity(0.8), Color.pink.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .pink.opacity(0.3), radius: 8, y: 4)
                                
                                // 内部指示器
                                if isRecording {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 30, height: 30)
                                }
                            }
                        }
                        
                        // 截图按钮：相机图标形状
                        Button(action: {}) {
                            Image(systemName: "camera")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.black)
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                )
            }
        }
        .onAppear {
            startTimer()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isRecording {
                let components = recordingTime.split(separator: ":").map { Int($0) ?? 0 }
                let totalSeconds = components[0] * 60 + components[1] + 1
                recordingTime = String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
            }
        }
    }
}

// MARK: - 方案三：专业摄影风格 - 深色高端
struct DesignOption3_Preview: View {
    @State private var isRecording = false
    @State private var recordingTime = "00:00"
    @State private var currentTime: Double = 45.0
    @State private var duration: Double = 120.0
    @State private var selectedTool = 0
    
    var body: some View {
        ZStack {
            // 深色背景
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部工具栏：深色透明
                HStack {
                    // 左侧参数显示
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            parameterView("ISO", "200")
                            parameterView("f/2.8", "")
                            parameterView("1/60", "")
                        }
                        
                        if isRecording {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(isRecording ? 1.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: isRecording)
                                
                                Text("REC " + recordingTime)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 右侧设置按钮
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial.opacity(0.3))
                )
                
                // 相机预览区域
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        // 模拟取景网格
                        VStack(spacing: 0) {
                            ForEach(0..<3) { _ in
                                HStack(spacing: 0) {
                                    ForEach(0..<3) { _ in
                                        Rectangle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    }
                                }
                            }
                        }
                    )
                    .overlay(
                        Text("4K ProRes")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.ultraThinMaterial.opacity(0.7))
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding()
                    )
                    .frame(maxHeight: .infinity)
                
                // 底部控制区域：磨砂玻璃效果
                VStack(spacing: 20) {
                    // 精密时间轴
                    VStack(spacing: 8) {
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("4K 60fps")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.yellow.opacity(0.8))
                            
                            Spacer()
                            
                            Text(formatTime(duration))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // 专业时间轴
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, CGFloat(currentTime / duration) * 300), height: 4)
                            
                            // 精密控制指示器
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 4, height: 20)
                                .offset(x: CGFloat(currentTime / duration) * 296)
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                        .frame(width: 300)
                    }
                    
                    // 专业控制按钮
                    HStack(spacing: 30) {
                        // 图库按钮
                        Button(action: {}) {
                            Image(systemName: "rectangle.stack")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial.opacity(0.3))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        
                        // 专业录制按钮：金属质感
                        Button(action: { isRecording.toggle() }) {
                            ZStack {
                                // 外圈：金属边框
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white, .gray.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: 76, height: 76)
                                
                                // 内圈背景
                                Circle()
                                    .fill(
                                        isRecording ?
                                        LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom) :
                                        LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .frame(width: 68, height: 68)
                                    .shadow(color: .black.opacity(0.3), radius: isRecording ? 8 : 4)
                                
                                // 内部指示器
                                if isRecording {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Circle()
                                        .fill(Color.red.opacity(0.8))
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }
                        
                        // 工具切换按钮
                        Button(action: {}) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial.opacity(0.3))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    
                    // 专业工具栏
                    HStack(spacing: 20) {
                        toolButton("手动", selectedTool == 0)
                        toolButton("自动", selectedTool == 1)
                        toolButton("电影", selectedTool == 2)
                        toolButton("慢动作", selectedTool == 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 25)
                .background(
                    .ultraThinMaterial.opacity(0.8)
                )
            }
        }
        .onAppear {
            startTimer()
        }
    }
    
    @ViewBuilder
    private func parameterView(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.yellow.opacity(0.8))
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    @ViewBuilder
    private func toolButton(_ title: String, _ isSelected: Bool) -> some View {
        Button(action: {}) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .yellow : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.yellow.opacity(0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.yellow.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isRecording {
                let components = recordingTime.split(separator: ":").map { Int($0) ?? 0 }
                let totalSeconds = components[0] * 60 + components[1] + 1
                recordingTime = String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
            }
        }
    }
}

// MARK: - 预览入口
struct DesignPreview: View {
    @State private var selectedDesign = 0
    
    var body: some View {
        TabView(selection: $selectedDesign) {
            DesignOption1_Preview()
                .tabItem {
                    Image(systemName: "1.circle")
                    Text("方案一")
                }
                .tag(0)
            
            DesignOption3_Preview()
                .tabItem {
                    Image(systemName: "3.circle")
                    Text("方案三")
                }
                .tag(1)
        }
    }
}

#Preview("方案一：小红书风格") {
    DesignOption1_Preview()
}

#Preview("方案三：专业摄影风格") {
    DesignOption3_Preview()
}

#Preview("设计对比") {
    DesignPreview()
}
