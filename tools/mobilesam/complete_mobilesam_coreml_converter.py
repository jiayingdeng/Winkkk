#!/usr/bin/env python3
"""
🎯 完整MobileSAM CoreML转换器
将PyTorch的mobile_sam.pt转换为iOS可用的CoreML模型
"""

import torch
import numpy as np
import coremltools as ct
from pathlib import Path
import traceback
from typing import Tuple, Optional, Dict, Any
import logging

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CompleteMobileSAMConverter:
    def __init__(self, pytorch_model_path: str, output_dir: str = "./coreml_models"):
        self.pytorch_model_path = Path(pytorch_model_path)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # 检查PyTorch模型是否存在
        if not self.pytorch_model_path.exists():
            raise FileNotFoundError(f"PyTorch模型不存在: {self.pytorch_model_path}")
            
        self.device = torch.device('cpu')  # 强制使用CPU以确保兼容性
        self.model = None
        
    def load_pytorch_model(self) -> bool:
        """加载PyTorch模型"""
        try:
            logger.info(f"📥 加载PyTorch模型: {self.pytorch_model_path}")
            
            # 加载state_dict
            checkpoint = torch.load(self.pytorch_model_path, map_location=self.device)
            
            # 需要创建MobileSAM模型结构
            # 我们将使用官方的mobile_sam代码来构建模型
            from mobile_sam import sam_model_registry, SamPredictor
            
            model_type = "vit_t"
            self.model = sam_model_registry[model_type](checkpoint=self.pytorch_model_path)
            self.model.to(device=self.device)
            self.model.eval()
            
            logger.info("✅ PyTorch模型加载成功")
            return True
            
        except ImportError:
            logger.error("❌ 需要安装mobile_sam包")
            logger.info("请运行: pip install git+https://github.com/ChaoningZhang/MobileSAM.git")
            return False
        except Exception as e:
            logger.error(f"❌ PyTorch模型加载失败: {e}")
            traceback.print_exc()
            return False
    
    def create_image_encoder_wrapper(self):
        """创建ImageEncoder包装器"""
        class ImageEncoderWrapper(torch.nn.Module):
            def __init__(self, image_encoder):
                super().__init__()
                self.image_encoder = image_encoder
                
            def forward(self, x):
                # 输入: (B, 3, 1024, 1024)
                # 输出: (B, 256, 64, 64)
                return self.image_encoder(x)
        
        return ImageEncoderWrapper(self.model.image_encoder)
    
    def create_mask_decoder_wrapper(self):
        """创建MaskDecoder包装器"""
        class MaskDecoderWrapper(torch.nn.Module):
            def __init__(self, mask_decoder, prompt_encoder):
                super().__init__()
                self.mask_decoder = mask_decoder
                self.prompt_encoder = prompt_encoder
                
            def forward(self, image_embeddings, point_coords, point_labels):
                # 处理点提示
                points = (point_coords, point_labels)
                
                # 编码提示
                sparse_embeddings, dense_embeddings = self.prompt_encoder(
                    points=points,
                    boxes=None,
                    masks=None,
                )
                
                # 解码掩码
                low_res_masks, iou_predictions = self.mask_decoder(
                    image_embeddings=image_embeddings,
                    image_pe=self.prompt_encoder.get_dense_pe(),
                    sparse_prompt_embeddings=sparse_embeddings,
                    dense_prompt_embeddings=dense_embeddings,
                    multimask_output=True,
                )
                
                return low_res_masks, iou_predictions
        
        return MaskDecoderWrapper(self.model.mask_decoder, self.model.prompt_encoder)
    
    def convert_image_encoder(self) -> bool:
        """转换ImageEncoder"""
        try:
            logger.info("🔄 转换ImageEncoder...")
            
            # 创建包装器
            encoder_wrapper = self.create_image_encoder_wrapper()
            encoder_wrapper.eval()
            
            # 创建示例输入
            example_input = torch.randn(1, 3, 1024, 1024)
            
            # 跟踪模型
            traced_model = torch.jit.trace(encoder_wrapper, example_input)
            
            # 转换为CoreML
            coreml_model = ct.convert(
                traced_model,
                inputs=[ct.TensorType(
                    name="image",
                    shape=(1, 3, 1024, 1024),
                    dtype=np.float32
                )],
                outputs=[ct.TensorType(
                    name="image_embeddings",
                    dtype=np.float32
                )],
                minimum_deployment_target=ct.target.iOS15,
                compute_units=ct.ComputeUnit.ALL
            )
            
            # 设置模型元数据
            coreml_model.short_description = "MobileSAM Image Encoder"
            coreml_model.author = "MobileSAM Team"
            coreml_model.license = "Apache 2.0"
            coreml_model.version = "1.0"
            
            # 保存模型
            encoder_path = self.output_dir / "MobileSAM_ImageEncoder.mlpackage"
            coreml_model.save(str(encoder_path))
            
            logger.info(f"✅ ImageEncoder转换成功: {encoder_path}")
            return True
            
        except Exception as e:
            logger.error(f"❌ ImageEncoder转换失败: {e}")
            traceback.print_exc()
            return False
    
    def convert_mask_decoder(self) -> bool:
        """转换MaskDecoder"""
        try:
            logger.info("🔄 转换MaskDecoder...")
            
            # 创建包装器
            decoder_wrapper = self.create_mask_decoder_wrapper()
            decoder_wrapper.eval()
            
            # 创建示例输入
            image_embeddings = torch.randn(1, 256, 64, 64)
            point_coords = torch.randn(1, 1, 2)  # 1个点
            point_labels = torch.ones(1, 1)      # 前景点
            
            # 跟踪模型
            with torch.no_grad():
                traced_model = torch.jit.trace(
                    decoder_wrapper, 
                    (image_embeddings, point_coords, point_labels)
                )
            
            # 转换为CoreML
            coreml_model = ct.convert(
                traced_model,
                inputs=[
                    ct.TensorType(
                        name="image_embeddings",
                        shape=(1, 256, 64, 64),
                        dtype=np.float32
                    ),
                    ct.TensorType(
                        name="point_coords",
                        shape=(1, 1, 2),
                        dtype=np.float32
                    ),
                    ct.TensorType(
                        name="point_labels",
                        shape=(1, 1),
                        dtype=np.float32
                    )
                ],
                outputs=[
                    ct.TensorType(name="masks", dtype=np.float32),
                    ct.TensorType(name="iou_predictions", dtype=np.float32)
                ],
                minimum_deployment_target=ct.target.iOS15,
                compute_units=ct.ComputeUnit.ALL
            )
            
            # 设置模型元数据
            coreml_model.short_description = "MobileSAM Mask Decoder"
            coreml_model.author = "MobileSAM Team"
            coreml_model.license = "Apache 2.0"
            coreml_model.version = "1.0"
            
            # 保存模型
            decoder_path = self.output_dir / "MobileSAM_MaskDecoder.mlpackage"
            coreml_model.save(str(decoder_path))
            
            logger.info(f"✅ MaskDecoder转换成功: {decoder_path}")
            return True
            
        except Exception as e:
            logger.error(f"❌ MaskDecoder转换失败: {e}")
            traceback.print_exc()
            return False
    
    def verify_conversion(self) -> bool:
        """验证转换结果"""
        try:
            logger.info("🔍 验证转换结果...")
            
            encoder_path = self.output_dir / "MobileSAM_ImageEncoder.mlpackage"
            decoder_path = self.output_dir / "MobileSAM_MaskDecoder.mlpackage"
            
            # 检查文件是否存在
            if not encoder_path.exists():
                logger.error("❌ ImageEncoder模型文件不存在")
                return False
                
            if not decoder_path.exists():
                logger.error("❌ MaskDecoder模型文件不存在")
                return False
            
            # 尝试加载模型
            try:
                encoder_model = ct.models.MLModel(str(encoder_path))
                decoder_model = ct.models.MLModel(str(decoder_path))
                
                logger.info("✅ 模型加载验证成功")
                logger.info(f"   ImageEncoder输入: {encoder_model.input_description}")
                logger.info(f"   ImageEncoder输出: {encoder_model.output_description}")
                logger.info(f"   MaskDecoder输入: {decoder_model.input_description}")
                logger.info(f"   MaskDecoder输出: {decoder_model.output_description}")
                
                return True
                
            except Exception as e:
                logger.error(f"❌ 模型加载验证失败: {e}")
                return False
                
        except Exception as e:
            logger.error(f"❌ 验证过程失败: {e}")
            return False
    
    def convert_all(self) -> bool:
        """执行完整转换流程"""
        logger.info("🚀 开始完整MobileSAM CoreML转换...")
        
        # 1. 加载PyTorch模型
        if not self.load_pytorch_model():
            return False
        
        # 2. 转换ImageEncoder
        if not self.convert_image_encoder():
            return False
        
        # 3. 转换MaskDecoder
        if not self.convert_mask_decoder():
            return False
        
        # 4. 验证转换结果
        if not self.verify_conversion():
            return False
        
        logger.info("🎉 完整MobileSAM CoreML转换成功！")
        logger.info(f"📁 输出目录: {self.output_dir}")
        
        return True

def main():
    """主函数"""
    # 配置路径
    pytorch_model_path = "./mobilesam_models/mobile_sam.pt"
    output_dir = "./coreml_models"
    
    # 创建转换器
    converter = CompleteMobileSAMConverter(pytorch_model_path, output_dir)
    
    # 执行转换
    success = converter.convert_all()
    
    if success:
        print("\n🎯 转换完成！可以在iOS项目中使用以下模型:")
        print("   - MobileSAM_ImageEncoder.mlpackage")
        print("   - MobileSAM_MaskDecoder.mlpackage")
    else:
        print("\n❌ 转换失败，请检查错误信息")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())