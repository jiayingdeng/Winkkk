//
//  MobileSAMView.swift
//  完整的MobileSAM分割界面
//

import SwiftUI

struct MobileSAMView: View {
    @StateObject private var samManager = MobileSAMCompleteManager()
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedPoint: CGPoint?
    @State private var showingResult = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题
                Text("🎯 MobileSAM 智能分割")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // 模型状态指示器
                HStack {
                    Circle()
                        .fill(samManager.isModelLoaded ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(samManager.isModelLoaded ? "模型已加载" : "模型加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !samManager.isModelLoaded {
                    // 模型加载提示
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("正在初始化MobileSAM模型...")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("请确保CoreML模型文件已正确添加到项目中")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    // 主要功能区域
                    VStack(spacing: 20) {
                        // 图像选择区域
                        if let image = selectedImage {
                            ImageTapView(
                                image: image,
                                onTap: { point in
                                    selectedPoint = point
                                    performSegmentation(at: point)
                                }
                            )
                            .frame(height: 300)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        } else {
                            // 图像选择按钮
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 48))
                                        .foregroundColor(.blue)
                                    
                                    Text("选择图像进行分割")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [10]))
                                )
                            }
                        }
                        
                        // 操作按钮区域
                        HStack(spacing: 16) {
                            // 选择新图像
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Label("选择图像", systemImage: "photo")
                            }
                            .buttonStyle(.bordered)
                            
                            // 清除选择
                            if selectedImage != nil {
                                Button(action: {
                                    selectedImage = nil
                                    selectedPoint = nil
                                    samManager.segmentationResult = nil
                                }) {
                                    Label("清除", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                        
                        // 分割状态
                        if samManager.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("正在进行智能分割...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // 分割结果
                        if let result = samManager.segmentationResult {
                            VStack(spacing: 12) {
                                Text("分割结果")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Image(uiImage: result)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 200)
                                    .cornerRadius(8)
                                    .shadow(radius: 3)
                                
                                Button(action: {
                                    showingResult = true
                                }) {
                                    Label("查看详细结果", systemImage: "eye")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingResult) {
            if let result = samManager.segmentationResult {
                ResultDetailView(image: result)
            }
        }
    }
    
    private func performSegmentation(at point: CGPoint) {
        guard let image = selectedImage else { return }
        samManager.segmentObject(in: image, at: point)
    }
}

// MARK: - Image Tap View
struct ImageTapView: UIViewRepresentable {
    let image: UIImage
    let onTap: (CGPoint) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        imageView.addGestureRecognizer(tapGesture)
        
        containerView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: containerView.heightAnchor)
        ])
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let imageView = uiView.subviews.first as? UIImageView {
            imageView.image = image
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }
    
    class Coordinator: NSObject {
        let onTap: (CGPoint) -> Void
        
        init(onTap: @escaping (CGPoint) -> Void) {
            self.onTap = onTap
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            onTap(point)
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Result Detail View
struct ResultDetailView: View {
    let image: UIImage
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("分割结果")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Preview
struct MobileSAMView_Previews: PreviewProvider {
    static var previews: some View {
        MobileSAMView()
    }
}


