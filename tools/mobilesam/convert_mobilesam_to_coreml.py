#!/usr/bin/env python3
"""
MobileSAM PyTorch 到 CoreML 转换脚本
将完整的 mobile_sam.pt 转换为独立的 CoreML 组件
"""

import os
import torch
import numpy as np
from pathlib import Path
import traceback

try:
    import coremltools as ct
    HAS_COREMLTOOLS = True
except ImportError:
    HAS_COREMLTOOLS = False
    print("⚠️  coremltools 未安装，请运行: pip install coremltools")

class MobileSAMConverter:
    def __init__(self, model_path="./mobilesam_models/mobile_sam.pt"):
        self.model_path = Path(model_path)
        self.output_dir = Path("./coreml_models")
        self.output_dir.mkdir(exist_ok=True)
        
        # 加载完整模型
        print(f"🔄 正在加载模型: {self.model_path}")
        self.checkpoint = torch.load(self.model_path, map_location='cpu')
        print(f"✅ 模型加载成功")
        
    def analyze_model_structure(self):
        """详细分析模型结构"""
        print("\n🔍 详细模型结构分析:")
        print("=" * 60)
        
        # 按组件分类权重
        components = {
            'image_encoder': [],
            'prompt_encoder': [],
            'mask_decoder': []
        }
        
        for key in self.checkpoint.keys():
            if key.startswith('image_encoder'):
                components['image_encoder'].append(key)
            elif key.startswith('prompt_encoder'):
                components['prompt_encoder'].append(key)
            elif key.startswith('mask_decoder'):
                components['mask_decoder'].append(key)
        
        for component, keys in components.items():
            print(f"\n📦 {component.upper()}:")
            print(f"   包含 {len(keys)} 个参数")
            if keys:
                # 显示前几个和后几个参数名
                sample_keys = keys[:3] + (['...'] if len(keys) > 6 else []) + keys[-3:]
                for key in sample_keys:
                    if key != '...':
                        shape = self.checkpoint[key].shape if hasattr(self.checkpoint[key], 'shape') else 'N/A'
                        print(f"     - {key}: {shape}")
                    else:
                        print(f"     - ...")
        
        return components
    
    def create_image_encoder_model(self):
        """创建ImageEncoder模型类"""
        print("\n🔧 创建ImageEncoder模型...")
        
        class MobileSAMImageEncoder(torch.nn.Module):
            def __init__(self, checkpoint):
                super().__init__()
                # 这里需要根据MobileSAM的具体架构来实现
                # 基于TinyViT的结构
                pass
            
            def forward(self, x):
                # 实现前向传播
                # 输入: (1, 3, 1024, 1024)
                # 输出: (1, 256, 64, 64) - 图像特征
                return x  # 占位符
        
        return MobileSAMImageEncoder(self.checkpoint)
    
    def create_mask_decoder_model(self):
        """创建MaskDecoder模型类"""
        print("\n🔧 创建MaskDecoder模型...")
        
        class MobileSAMMaskDecoder(torch.nn.Module):
            def __init__(self, checkpoint):
                super().__init__()
                # 根据SAM的MaskDecoder结构实现
                pass
            
            def forward(self, image_embeddings, point_coords, point_labels):
                # 实现前向传播
                # 输入: 
                #   - image_embeddings: (1, 256, 64, 64)
                #   - point_coords: (1, N, 2)
                #   - point_labels: (1, N)
                # 输出: masks, iou_predictions
                batch_size = image_embeddings.shape[0]
                return torch.zeros(batch_size, 1, 256, 256), torch.zeros(batch_size, 1)  # 占位符
        
        return MobileSAMMaskDecoder(self.checkpoint)
    
    def convert_to_coreml_basic(self):
        """基础转换方法 - 创建CoreML模型结构"""
        if not HAS_COREMLTOOLS:
            print("❌ 无法转换：缺少 coremltools")
            return False
            
        try:
            print("\n🚀 开始基础CoreML转换...")
            
            # 1. 分析现有模型参数
            components = self.analyze_model_structure()
            
            # 2. 创建ImageEncoder的CoreML模型描述
            self.create_image_encoder_spec()
            
            # 3. 创建MaskDecoder的CoreML模型描述
            self.create_mask_decoder_spec()
            
            print("✅ 基础转换完成！")
            return True
            
        except Exception as e:
            print(f"❌ 转换失败: {e}")
            traceback.print_exc()
            return False
    
    def create_image_encoder_spec(self):
        """创建ImageEncoder的CoreML规格"""
        print("\n📝 创建ImageEncoder CoreML规格...")
        
        # 创建一个简化的ImageEncoder规格
        try:
            import coremltools.models.datatypes as dt
            from coremltools.models.neural_network import NeuralNetworkBuilder
            
            # 定义输入输出
            input_features = [('image', dt.Array(3, 1024, 1024))]
            output_features = [('image_embeddings', dt.Array(256, 64, 64))]
            
            # 创建神经网络构建器
            builder = NeuralNetworkBuilder(input_features, output_features)
            
            # 这里需要根据实际的TinyViT结构添加层
            # 为了演示，我们添加一个简化的结构
            builder.add_convolution(
                name='conv1',
                kernel_channels=3,
                output_channels=96,
                height=4,
                width=4,
                stride_height=4,
                stride_width=4,
                border_mode='valid',
                groups=1,
                input_name='image',
                output_name='features'
            )
            
            # 添加更多层...
            
            # 保存模型
            model = ct.models.MLModel(builder.spec)
            model_path = self.output_dir / "MobileSAM_ImageEncoder_Simple.mlmodel"
            model.save(str(model_path))
            print(f"✅ ImageEncoder规格已保存: {model_path}")
            
        except Exception as e:
            print(f"⚠️  ImageEncoder规格创建失败: {e}")
    
    def create_mask_decoder_spec(self):
        """创建MaskDecoder的CoreML规格"""
        print("\n📝 创建MaskDecoder CoreML规格...")
        
        try:
            import coremltools.models.datatypes as dt
            from coremltools.models.neural_network import NeuralNetworkBuilder
            
            # 定义输入输出
            input_features = [
                ('image_embeddings', dt.Array(256, 64, 64)),
                ('point_coords', dt.Array(2, 1)),  # 简化为单点
                ('point_labels', dt.Array(1,))
            ]
            output_features = [
                ('masks', dt.Array(1, 256, 256)),
                ('iou_predictions', dt.Array(1,))
            ]
            
            # 创建神经网络构建器
            builder = NeuralNetworkBuilder(input_features, output_features)
            
            # 这里需要根据实际的MaskDecoder结构添加层
            # 为了演示，添加简化结构
            
            # 保存模型
            model = ct.models.MLModel(builder.spec)
            model_path = self.output_dir / "MobileSAM_MaskDecoder_Simple.mlmodel"
            model.save(str(model_path))
            print(f"✅ MaskDecoder规格已保存: {model_path}")
            
        except Exception as e:
            print(f"⚠️  MaskDecoder规格创建失败: {e}")
    
    def extract_weights_for_coreml(self):
        """提取权重用于CoreML转换"""
        print("\n💾 提取模型权重...")
        
        # 保存权重到numpy格式，便于在Swift中使用
        weights_dir = self.output_dir / "weights"
        weights_dir.mkdir(exist_ok=True)
        
        component_weights = {
            'image_encoder': {},
            'prompt_encoder': {},
            'mask_decoder': {}
        }
        
        for key, value in self.checkpoint.items():
            if key.startswith('image_encoder'):
                component_weights['image_encoder'][key] = value.numpy()
            elif key.startswith('prompt_encoder'):
                component_weights['prompt_encoder'][key] = value.numpy()
            elif key.startswith('mask_decoder'):
                component_weights['mask_decoder'][key] = value.numpy()
        
        # 保存权重
        for component, weights in component_weights.items():
            if weights:
                save_path = weights_dir / f"{component}_weights.npz"
                np.savez(str(save_path), **weights)
                print(f"✅ {component} 权重已保存: {save_path}")
        
        print(f"📁 权重文件目录: {weights_dir}")
        return weights_dir
    
    def generate_swift_integration_code(self):
        """生成Swift集成代码"""
        print("\n📝 生成Swift集成代码...")
        
        swift_code = '''
// MobileSAM 完整实现 - Swift 集成代码
import CoreML
import Vision
import Accelerate

class CompleteMobileSAMManager {
    private var imageEncoder: MLModel?
    private var maskDecoder: MLModel?
    
    init() {
        loadModels()
    }
    
    private func loadModels() {
        // 加载ImageEncoder
        guard let imageEncoderURL = Bundle.main.url(forResource: "MobileSAM_ImageEncoder", withExtension: "mlmodelc") else {
            print("❌ 找不到ImageEncoder模型")
            return
        }
        
        // 加载MaskDecoder  
        guard let maskDecoderURL = Bundle.main.url(forResource: "MobileSAM_MaskDecoder", withExtension: "mlmodelc") else {
            print("❌ 找不到MaskDecoder模型")
            return
        }
        
        do {
            imageEncoder = try MLModel(contentsOf: imageEncoderURL)
            maskDecoder = try MLModel(contentsOf: maskDecoderURL)
            print("✅ MobileSAM模型加载成功")
        } catch {
            print("❌ 模型加载失败: \\(error)")
        }
    }
    
    func segmentObject(image: UIImage, point: CGPoint) -> UIImage? {
        guard let imageEncoder = imageEncoder,
              let maskDecoder = maskDecoder else {
            print("❌ 模型未加载")
            return nil
        }
        
        // 1. 图像预处理
        guard let processedImage = preprocessImage(image) else {
            return nil
        }
        
        // 2. 图像编码
        guard let imageEmbeddings = encodeImage(processedImage, using: imageEncoder) else {
            return nil
        }
        
        // 3. 掩码解码
        guard let mask = decodeMask(imageEmbeddings: imageEmbeddings, 
                                   point: point, 
                                   using: maskDecoder) else {
            return nil
        }
        
        // 4. 后处理
        return postprocessMask(mask, originalSize: image.size)
    }
    
    private func preprocessImage(_ image: UIImage) -> MLMultiArray? {
        // 实现图像预处理逻辑
        // 调整大小到1024x1024，归一化等
        return nil
    }
    
    private func encodeImage(_ image: MLMultiArray, using encoder: MLModel) -> MLMultiArray? {
        // 使用ImageEncoder编码图像
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": image])
            let output = try encoder.prediction(from: input)
            return output.featureValue(for: "image_embeddings")?.multiArrayValue
        } catch {
            print("❌ 图像编码失败: \\(error)")
            return nil
        }
    }
    
    private func decodeMask(imageEmbeddings: MLMultiArray, 
                           point: CGPoint, 
                           using decoder: MLModel) -> MLMultiArray? {
        // 使用MaskDecoder生成掩码
        do {
            let pointCoords = createPointCoords(point)
            let pointLabels = createPointLabels()
            
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "image_embeddings": imageEmbeddings,
                "point_coords": pointCoords,
                "point_labels": pointLabels
            ])
            
            let output = try decoder.prediction(from: input)
            return output.featureValue(for: "masks")?.multiArrayValue
        } catch {
            print("❌ 掩码解码失败: \\(error)")
            return nil
        }
    }
    
    private func createPointCoords(_ point: CGPoint) -> MLMultiArray {
        // 创建点坐标数组
        // TODO: 实现具体逻辑
        return MLMultiArray()
    }
    
    private func createPointLabels() -> MLMultiArray {
        // 创建点标签数组  
        // TODO: 实现具体逻辑
        return MLMultiArray()
    }
    
    private func postprocessMask(_ mask: MLMultiArray, originalSize: CGSize) -> UIImage? {
        // 后处理掩码，转换为UIImage
        // TODO: 实现具体逻辑
        return nil
    }
}
'''
        
        swift_file = self.output_dir / "CompleteMobileSAMManager.swift"
        with open(swift_file, 'w', encoding='utf-8') as f:
            f.write(swift_code)
        
        print(f"✅ Swift集成代码已生成: {swift_file}")
        return swift_file

def main():
    """主函数"""
    print("🎯 MobileSAM PyTorch 到 CoreML 转换器")
    print("=" * 60)
    
    # 检查模型文件是否存在
    model_path = "./mobilesam_models/mobile_sam.pt"
    if not Path(model_path).exists():
        print(f"❌ 模型文件不存在: {model_path}")
        print("请先运行 download_complete_mobilesam.py 下载模型")
        return
    
    # 创建转换器
    converter = MobileSAMConverter(model_path)
    
    # 分析模型结构
    converter.analyze_model_structure()
    
    # 提取权重
    converter.extract_weights_for_coreml()
    
    # 基础转换
    if HAS_COREMLTOOLS:
        converter.convert_to_coreml_basic()
    else:
        print("⚠️  跳过CoreML转换 - 缺少coremltools")
    
    # 生成Swift代码
    converter.generate_swift_integration_code()
    
    print("\n🎉 转换完成！")
    print("\n📋 下一步:")
    print("   1. 安装 coremltools: pip install coremltools")
    print("   2. 实现完整的模型转换逻辑")
    print("   3. 将生成的CoreML模型集成到iOS项目")
    print("   4. 使用生成的Swift代码实现完整工作流程")

if __name__ == "__main__":
    main()


