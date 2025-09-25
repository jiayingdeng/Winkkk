#!/bin/bash

# MobileSAM 环境搭建脚本
# 适用于 macOS 开发环境

echo "🚀 开始搭建 MobileSAM 开发环境..."

# 1. 创建项目目录
PROJECT_DIR="$HOME/Desktop/MobileSAM_Project"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "📁 项目目录创建完成: $PROJECT_DIR"

# 2. 创建 Python 虚拟环境
echo "🐍 创建 Python 虚拟环境..."
python3 -m venv mobilesam_env
source mobilesam_env/bin/activate

# 3. 安装基础依赖
echo "📦 安装基础依赖..."
pip install --upgrade pip
pip install torch torchvision torchaudio
pip install opencv-python
pip install matplotlib
pip install numpy
pip install Pillow
pip install coremltools  # iOS转换必需

# 4. 克隆 MobileSAM 仓库
echo "⬇️ 下载 MobileSAM 源码..."
git clone https://github.com/ChaoningZhang/MobileSAM.git
cd MobileSAM

# 5. 安装 MobileSAM
echo "🔧 安装 MobileSAM..."
pip install -e .

# 6. 创建权重目录并下载模型
echo "💾 下载预训练模型权重..."
mkdir -p weights
cd weights
curl -L -o mobile_sam.pt "https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt"

echo "✅ MobileSAM 环境搭建完成！"
echo "📍 项目路径: $PROJECT_DIR/MobileSAM"
echo "🎯 接下来可以运行测试脚本验证安装"

# 7. 创建测试脚本
cd ..
cat > test_mobilesam.py << 'EOF'
#!/usr/bin/env python3
"""
MobileSAM 安装验证脚本
验证模型是否能正常加载和运行
"""

import torch
import sys
import os

def test_mobilesam_installation():
    try:
        # 测试导入
        from mobile_sam import sam_model_registry, SamPredictor
        print("✅ MobileSAM 导入成功")
        
        # 测试模型加载
        model_type = "vit_t"
        sam_checkpoint = "MobileSAM/weights/mobile_sam.pt"
        
        if not os.path.exists(sam_checkpoint):
            print("❌ 模型权重文件未找到")
            return False
            
        print(f"📦 模型权重文件大小: {os.path.getsize(sam_checkpoint) / 1024 / 1024:.2f} MB")
        
        # 加载模型
        device = "cpu"  # 移动端推荐CPU
        model = sam_model_registry[model_type](checkpoint=sam_checkpoint)
        model.to(device=device)
        model.eval()
        
        print("✅ MobileSAM 模型加载成功")
        print(f"🎯 使用设备: {device}")
        print(f"📊 模型参数量: {sum(p.numel() for p in model.parameters()) / 1e6:.2f}M")
        
        return True
        
    except Exception as e:
        print(f"❌ 安装验证失败: {e}")
        return False

if __name__ == "__main__":
    success = test_mobilesam_installation()
    if success:
        print("\n🎉 MobileSAM 安装验证成功！可以开始使用了")
    else:
        print("\n💥 安装验证失败，请检查安装步骤")
        sys.exit(1)
EOF

chmod +x test_mobilesam.py

echo ""
echo "🧪 运行安装验证:"
echo "cd $PROJECT_DIR"
echo "source mobilesam_env/bin/activate"
echo "python test_mobilesam.py"


