#!/usr/bin/env python3
"""
完整的MobileSAM模型下载脚本
包含ImageEncoder和MaskDecoder的完整工作流程
"""

import os
import requests
import torch
from pathlib import Path
import urllib.request
from tqdm import tqdm

class MobileSAMDownloader:
    def __init__(self, download_dir="./mobilesam_models"):
        self.download_dir = Path(download_dir)
        self.download_dir.mkdir(exist_ok=True)
        
        # 官方下载地址
        self.urls = {
            # MobileSAM官方模型
            "mobile_sam": "https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt",
            
            # SAM官方模型（备用）
            "sam_vit_h": "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth",
            "sam_vit_l": "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_l_0b3195.pth", 
            "sam_vit_b": "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth",
        }
    
    def download_with_progress(self, url, filename):
        """带进度条的下载函数"""
        print(f"🔄 正在下载: {filename}")
        filepath = self.download_dir / filename
        
        try:
            response = requests.get(url, stream=True)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0))
            
            with open(filepath, 'wb') as file, tqdm(
                desc=filename,
                total=total_size,
                unit='iB',
                unit_scale=True,
                unit_divisor=1024,
            ) as progress_bar:
                for chunk in response.iter_content(chunk_size=8192):
                    size = file.write(chunk)
                    progress_bar.update(size)
            
            print(f"✅ 下载完成: {filepath}")
            return filepath
            
        except Exception as e:
            print(f"❌ 下载失败 {filename}: {e}")
            return None
    
    def download_mobilesam(self):
        """下载MobileSAM模型"""
        print("📥 开始下载MobileSAM模型...")
        
        # 下载主模型
        mobile_sam_path = self.download_with_progress(
            self.urls["mobile_sam"], 
            "mobile_sam.pt"
        )
        
        if mobile_sam_path and mobile_sam_path.exists():
            print(f"🎯 MobileSAM模型下载成功: {mobile_sam_path}")
            return mobile_sam_path
        else:
            print("❌ MobileSAM模型下载失败")
            return None
    
    def analyze_model_structure(self, model_path):
        """分析模型结构"""
        print(f"\n🔍 正在分析模型结构: {model_path}")
        
        try:
            # 加载模型
            checkpoint = torch.load(model_path, map_location='cpu')
            
            print(f"📊 模型信息:")
            print(f"   - 模型类型: {type(checkpoint)}")
            
            if isinstance(checkpoint, dict):
                print(f"   - 包含的键: {list(checkpoint.keys())}")
                
                # 检查是否包含完整的SAM结构
                if 'model' in checkpoint:
                    model = checkpoint['model']
                    if hasattr(model, 'image_encoder'):
                        print("   ✅ 包含 ImageEncoder")
                    if hasattr(model, 'mask_decoder'):
                        print("   ✅ 包含 MaskDecoder") 
                    if hasattr(model, 'prompt_encoder'):
                        print("   ✅ 包含 PromptEncoder")
                        
            return True
            
        except Exception as e:
            print(f"❌ 模型分析失败: {e}")
            return False
    
    def convert_to_coreml(self, pytorch_model_path):
        """转换为CoreML格式"""
        print(f"\n🔄 正在转换为CoreML格式...")
        
        try:
            import coremltools as ct
            import torch
            
            # 这里需要根据MobileSAM的具体结构来实现
            # 由于我们需要分离ImageEncoder和MaskDecoder
            print("⚠️  CoreML转换需要根据具体的模型结构来实现")
            print("   建议使用官方提供的转换脚本或工具")
            
            return True
            
        except ImportError:
            print("❌ 缺少coremltools，请安装: pip install coremltools")
            return False
        except Exception as e:
            print(f"❌ CoreML转换失败: {e}")
            return False
    
    def download_all(self):
        """下载所有必需的模型文件"""
        print("🚀 开始下载完整的MobileSAM模型组件...\n")
        
        # 显示官方地址信息
        print("📍 官方下载地址:")
        print("   🔹 MobileSAM GitHub: https://github.com/ChaoningZhang/MobileSAM")
        print("   🔹 SAM GitHub: https://github.com/facebookresearch/segment-anything")
        print("   🔹 Meta SAM 官方: https://ai.facebook.com/research/publications/segment-anything/")
        print()
        
        # 下载MobileSAM
        mobile_sam_path = self.download_mobilesam()
        
        if mobile_sam_path:
            # 分析模型结构
            self.analyze_model_structure(mobile_sam_path)
            
            # 提示转换信息
            print(f"\n💡 下一步建议:")
            print("   1. 分析下载的模型结构，确认包含完整的SAM组件")
            print("   2. 使用官方转换脚本将PyTorch模型转换为CoreML")
            print("   3. 分离ImageEncoder和MaskDecoder为独立的CoreML模型")
            print("   4. 在iOS项目中正确实现SAM工作流程")
            
        return mobile_sam_path

def main():
    """主函数"""
    print("🎯 MobileSAM完整模型下载器")
    print("=" * 50)
    
    downloader = MobileSAMDownloader()
    result = downloader.download_all()
    
    if result:
        print(f"\n🎉 下载完成！模型保存在: {result}")
        print("\n📋 官方地址总结:")
        print("   🔸 MobileSAM: https://github.com/ChaoningZhang/MobileSAM")
        print("   🔸 原始SAM: https://github.com/facebookresearch/segment-anything")
        print("   🔸 模型下载: https://dl.fbaipublicfiles.com/segment_anything/")
    else:
        print("\n❌ 下载失败，请检查网络连接或手动下载")

if __name__ == "__main__":
    main()


