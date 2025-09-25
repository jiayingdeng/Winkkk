#!/usr/bin/env python3
"""
MobileSAM 模型权重文件备用下载脚本
提供多个下载源和下载方式
"""

import os
import urllib.request
import urllib.error
import sys
from pathlib import Path

def download_with_progress(url, filename):
    """带进度条的下载函数"""
    def progress_hook(block_num, block_size, total_size):
        if total_size > 0:
            percent = min(100, (block_num * block_size * 100) // total_size)
            sys.stdout.write(f"\r下载进度: {percent}% ({block_num * block_size // 1024 // 1024}MB / {total_size // 1024 // 1024}MB)")
            sys.stdout.flush()
    
    try:
        urllib.request.urlretrieve(url, filename, progress_hook)
        print(f"\n✅ 下载完成: {filename}")
        return True
    except Exception as e:
        print(f"\n❌ 下载失败: {e}")
        return False

def main():
    # 目标文件路径
    project_dir = Path.home() / "Desktop" / "MobileSAM_Project"
    weights_dir = project_dir / "MobileSAM" / "weights"
    target_file = weights_dir / "mobile_sam.pt"
    
    # 确保目录存在
    weights_dir.mkdir(parents=True, exist_ok=True)
    
    # 多个下载源
    download_urls = [
        "https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt",
        "https://huggingface.co/ChaoningZhang/MobileSAM/resolve/main/mobile_sam.pt",
        "https://drive.google.com/uc?export=download&id=1CiMlRb6DpDWrByZLBc86MBWfCaJLfX_1"  # 备用链接
    ]
    
    print("🚀 开始下载 MobileSAM 模型权重文件...")
    print(f"📁 目标路径: {target_file}")
    
    # 检查文件是否已存在
    if target_file.exists():
        file_size = target_file.stat().st_size
        print(f"⚠️  文件已存在，大小: {file_size // 1024 // 1024}MB")
        if file_size > 9 * 1024 * 1024:  # 大于9MB
            print("✅ 文件似乎完整，跳过下载")
            return True
        else:
            print("🔄 文件不完整，重新下载...")
            target_file.unlink()
    
    # 尝试各个下载源
    for i, url in enumerate(download_urls, 1):
        print(f"\n📥 尝试下载源 {i}/{len(download_urls)}: {url}")
        
        if download_with_progress(url, str(target_file)):
            # 验证文件大小
            file_size = target_file.stat().st_size
            print(f"📊 文件大小: {file_size // 1024 // 1024}MB")
            
            if file_size > 9 * 1024 * 1024:  # 期望大小约9.66MB
                print("✅ 下载成功！文件大小正常")
                return True
            else:
                print("⚠️  文件大小异常，删除并尝试下一个源...")
                target_file.unlink()
        
        print(f"❌ 下载源 {i} 失败，尝试下一个...")
    
    print("\n💥 所有下载源都失败了！")
    print("\n🔧 手动下载方案:")
    print("1. 访问: https://github.com/ChaoningZhang/MobileSAM/releases")
    print("2. 下载 mobile_sam.pt 文件")
    print(f"3. 放置到: {target_file}")
    print("\n或者使用迅雷等下载工具下载:")
    print("https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt")
    
    return False

if __name__ == "__main__":
    success = main()
    if not success:
        sys.exit(1)


