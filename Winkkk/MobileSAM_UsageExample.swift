
//
//  ContentView.swift
//  MobileSAM使用示例
//

import SwiftUI

struct ContentView: View {
    @StateObject private var mobileSAM = MobileSAMManager()
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎯 MobileSAM 通用分割")
                .font(.title)
                .fontWeight(.bold)
            
            // 图像显示区域
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 400)
                
                if let image = mobileSAM.segmentationResult ?? selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 380)
                        .cornerRadius(10)
                        .onTapGesture { location in
                            if let originalImage = selectedImage {
                                mobileSAM.segmentObject(in: originalImage, at: location)
                            }
                        }
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("点击选择图片")
                            .foregroundColor(.gray)
                    }
                }
                
                if mobileSAM.isLoading {
                    ProgressView("正在分割...")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .onTapGesture {
                if selectedImage == nil {
                    showingImagePicker = true
                }
            }
            
            // 控制按钮
            HStack(spacing: 20) {
                Button("选择图片") {
                    showingImagePicker = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("重置") {
                    selectedImage = nil
                    mobileSAM.segmentationResult = nil
                }
                .buttonStyle(.bordered)
            }
            
            // 使用说明
            VStack(alignment: .leading, spacing: 10) {
                Text("🔧 使用方法:")
                    .font(.headline)
                
                Text("1. 选择包含物体的图片")
                Text("2. 点击想要分割的物体")
                Text("3. 等待AI自动识别和分割")
                Text("4. 支持: 食物🍎、首饰💍、植物🌱、任何物体!")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
}

// 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
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
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ContentView()
}
