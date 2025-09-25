//
//  LivePhotoMaker.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/20.
//  Live Photo组装器 - 将视频片段和封面图组装成Live Photo
//

import Photos
import PhotosUI
import AVFoundation
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import os

/// Live Photo组装器
/// 负责将视频片段和封面图片组装成iOS原生支持的Live Photo格式
class LivePhotoMaker {
    
    // MARK: - Singleton
    static let shared = LivePhotoMaker()
    
    private init() {}
    
    // MARK: - Error Types
    enum LivePhotoError: LocalizedError {
        case invalidVideoURL
        case invalidImageURL
        case metadataWriteFailed(String)
        case livePhotoCreationFailed(String)
        case fileSystemError(String)
        case unsupportedFormat
        
        var errorDescription: String? {
            switch self {
            case .invalidVideoURL:
                return "无效的视频URL"
            case .invalidImageURL:
                return "无效的图片URL"
            case .metadataWriteFailed(let reason):
                return "元数据写入失败: \(reason)"
            case .livePhotoCreationFailed(let reason):
                return "Live Photo创建失败: \(reason)"
            case .fileSystemError(let reason):
                return "文件系统错误: \(reason)"
            case .unsupportedFormat:
                return "不支持的文件格式"
            }
        }
    }
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
    
    /// 将视频片段和封面图组装成Live Photo
    /// - Parameters:
    ///   - videoURL: 视频片段URL
    ///   - imageURL: 封面图片URL
    ///   - identifier: Live Photo配对标识符
    /// - Returns: 创建的PHLivePhoto对象
    func createLivePhoto(
        videoURL: URL,
        imageURL: URL,
        identifier: String? = nil
    ) async throws -> PHLivePhoto {
        
        // 验证输入文件
        guard fileManager.fileExists(atPath: videoURL.path) else {
            throw LivePhotoError.invalidVideoURL
        }
        
        guard fileManager.fileExists(atPath: imageURL.path) else {
            throw LivePhotoError.invalidImageURL
        }
        
        // 生成配对标识符
        let pairingIdentifier = identifier ?? UUID().uuidString
        
        // 创建临时目录用于处理
        let tempDir = createTempDirectory()
        defer { cleanupTempDirectory(tempDir) }
        
        // 处理视频文件
        let processedVideoURL = tempDir.appendingPathComponent("livephoto_video.mov")
        try await processVideoForLivePhoto(
            inputURL: videoURL,
            outputURL: processedVideoURL,
            identifier: pairingIdentifier
        )
        
        // 处理图片文件
        let processedImageURL = tempDir.appendingPathComponent("livephoto_image.heic")
        try await processImageForLivePhoto(
            inputURL: imageURL,
            outputURL: processedImageURL,
            identifier: pairingIdentifier
        )
        
        // 创建Live Photo
        return try await createPHLivePhoto(
            videoURL: processedVideoURL,
            imageURL: processedImageURL
        )
    }
    
    /// 保存Live Photo文件到指定目录
    /// - Parameters:
    ///   - videoURL: 视频URL
    ///   - imageURL: 图片URL
    ///   - identifier: 配对标识符
    ///   - destinationDir: 目标目录
    /// - Returns: 保存的文件URLs (视频, 图片)
    func saveLivePhotoFiles(
        videoURL: URL,
        imageURL: URL,
        identifier: String,
        to destinationDir: URL
    ) async throws -> (videoURL: URL, imageURL: URL) {
        
        // 确保目标目录存在
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        let fileName = LivePhotoConfig.generateFileName()
        let finalVideoURL = destinationDir.appendingPathComponent("\(fileName).\(LivePhotoConfig.videoExtension)")
        let finalImageURL = destinationDir.appendingPathComponent("\(fileName).\(LivePhotoConfig.imageExtension)")
        
        // 处理并保存视频
        try await processVideoForLivePhoto(
            inputURL: videoURL,
            outputURL: finalVideoURL,
            identifier: identifier
        )
        
        // 处理并保存图片
        try await processImageForLivePhoto(
            inputURL: imageURL,
            outputURL: finalImageURL,
            identifier: identifier
        )
        
        return (finalVideoURL, finalImageURL)
    }
    
    // MARK: - Private Methods
    
    /// 处理视频文件，添加Live Photo元数据
    private func processVideoForLivePhoto(
        inputURL: URL,
        outputURL: URL,
        identifier: String
    ) async throws {
        
        print("🎬 Live Photo视频处理诊断...")
        print("   输入URL: \(inputURL)")
        print("   输出URL: \(outputURL)")
        
        // 验证输入文件
        guard fileManager.fileExists(atPath: inputURL.path) else {
            print("   ❌ 输入文件不存在")
            throw LivePhotoError.invalidVideoURL
        }
        
        // 删除可能存在的输出文件
        if fileManager.fileExists(atPath: outputURL.path) {
            print("   检测到已存在的输出文件，正在删除...")
            do {
                try fileManager.removeItem(at: outputURL)
                print("   ✅ 已删除存在的输出文件")
            } catch {
                print("   ⚠️ 删除已存在文件失败: \(error)")
            }
        }
        
        // 确保输出目录存在
        let outputDir = outputURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: outputDir.path) {
            do {
                try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
                print("   ✅ 输出目录创建成功")
            } catch {
                print("   ❌ 输出目录创建失败: \(error)")
                throw LivePhotoError.fileSystemError("无法创建输出目录: \(error.localizedDescription)")
            }
        }
        
        let asset = AVAsset(url: inputURL)
        
        // 🎯 关键修复：检查音视频轨道
        print("   开始检查媒体轨道...")
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        print("   视频轨道数量: \(videoTracks.count)")
        print("   音频轨道数量: \(audioTracks.count)")
        
        guard !videoTracks.isEmpty else {
            print("   ❌ 视频文件没有视频轨道")
            throw LivePhotoError.invalidVideoURL
        }
        
        // 根据音频轨道情况选择导出预设
        let presetName: String
        if audioTracks.isEmpty {
            print("   ⚠️ 检测到无音频轨道，使用视频专用预设")
            presetName = AVAssetExportPresetHighestQuality
        } else {
            print("   ✅ 检测到音频轨道，使用标准预设")
            presetName = AVAssetExportPresetHighestQuality
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: presetName
        ) else {
            print("   ❌ 无法创建视频导出会话")
            throw LivePhotoError.livePhotoCreationFailed("无法创建视频导出会话")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 🎯 关键修复：音频处理配置
        if audioTracks.isEmpty {
            print("   🔇 配置无音频导出")
            // 对于无音频的视频，确保不尝试处理音频
            exportSession.audioMix = nil
        } else {
            print("   🔊 配置音频导出")
            // 有音频时的正常配置
        }
        
        // 添加Live Photo元数据
        let metadataItem = createLivePhotoMetadataItem(identifier: identifier)
        exportSession.metadata = [metadataItem]
        
        print("🎬 开始Live Photo视频处理...")
        
        // 🚀 添加超时机制的导出
        let exportResult = await withCheckedContinuation { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { _ in
                print("⏰ Live Photo视频处理超时，取消导出")
                exportSession.cancelExport()
                continuation.resume(returning: false)
            }
            
            exportSession.exportAsynchronously {
                timer.invalidate()
                continuation.resume(returning: true)
            }
        }
        
        // 检查超时和导出结果
        if !exportResult {
            throw LivePhotoError.livePhotoCreationFailed("Live Photo视频处理超时（20秒）")
        }
        
        switch exportSession.status {
        case .completed:
            print("✅ Live Photo视频处理完成")
            break
        case .failed:
            let error = exportSession.error?.localizedDescription ?? "未知错误"
            print("❌ Live Photo视频处理失败: \(error)")
            
            // 🎯 检测音频相关错误并提供友好提示
            if let nsError = exportSession.error as NSError? {
                print("   错误域: \(nsError.domain)")
                print("   错误代码: \(nsError.code)")
                
                if nsError.code == -12848 || nsError.code == -11829 {
                    throw LivePhotoError.livePhotoCreationFailed("视频音频格式不兼容，请尝试其他视频")
                }
            }
            
            throw LivePhotoError.livePhotoCreationFailed("视频处理失败: \(error)")
        case .cancelled:
            print("⏹️ Live Photo视频处理被取消")
            throw LivePhotoError.livePhotoCreationFailed("视频处理被取消或超时")
        default:
            print("⚠️ Live Photo视频处理状态异常: \(exportSession.status.rawValue)")
            throw LivePhotoError.livePhotoCreationFailed("视频处理状态异常")
        }
    }
    
    /// 处理图片文件，添加Live Photo元数据
    private func processImageForLivePhoto(
        inputURL: URL,
        outputURL: URL,
        identifier: String
    ) async throws {
        
        guard let image = UIImage(contentsOfFile: inputURL.path) else {
            throw LivePhotoError.invalidImageURL
        }
        
        // 创建HEIC数据
        guard let heicData = image.heicData() else {
            throw LivePhotoError.unsupportedFormat
        }
        
        // 添加Live Photo元数据到HEIC
        let dataWithMetadata = try addLivePhotoMetadataToImage(
            imageData: heicData,
            identifier: identifier
        )
        
        // 写入文件
        do {
            try dataWithMetadata.write(to: outputURL)
        } catch {
            throw LivePhotoError.fileSystemError("图片保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建Live Photo元数据项
    private func createLivePhotoMetadataItem(identifier: String) -> AVMetadataItem {
        let metadataItem = AVMutableMetadataItem()
        metadataItem.keySpace = .quickTimeMetadata
        metadataItem.key = "com.apple.quicktime.content.identifier" as NSString
        metadataItem.value = identifier as NSString
        metadataItem.dataType = kCMMetadataBaseDataType_UTF8 as String
        return metadataItem
    }
    
    /// 为图片数据添加Live Photo元数据
    private func addLivePhotoMetadataToImage(
        imageData: Data,
        identifier: String
    ) throws -> Data {
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw LivePhotoError.metadataWriteFailed("无法创建图片源")
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw LivePhotoError.metadataWriteFailed("无法创建图片目标")
        }
        
        // 复制原始图片
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LivePhotoError.metadataWriteFailed("无法读取图片")
        }
        
        // 创建元数据
        let metadata = NSMutableDictionary()
        
        // 添加Live Photo标识符
        let makerAppleDict = NSMutableDictionary()
        makerAppleDict["17"] = identifier // Live Photo identifier key
        metadata[kCGImagePropertyMakerAppleDictionary] = makerAppleDict
        
        // 添加EXIF数据
        let exifDict = NSMutableDictionary()
        exifDict[kCGImagePropertyExifUserComment] = "Live Photo"
        metadata[kCGImagePropertyExifDictionary] = exifDict
        
        // 写入图片和元数据
        CGImageDestinationAddImage(destination, cgImage, metadata)
        
        guard CGImageDestinationFinalize(destination) else {
            throw LivePhotoError.metadataWriteFailed("图片元数据写入失败")
        }
        
        return mutableData as Data
    }
    
    /// 创建PHLivePhoto对象
    private func createPHLivePhoto(
        videoURL: URL,
        imageURL: URL
    ) async throws -> PHLivePhoto {
        
        return try await withCheckedThrowingContinuation { continuation in
            let hasResumed = OSAllocatedUnfairLock(initialState: false)
            
            PHLivePhoto.request(
                withResourceFileURLs: [videoURL, imageURL],
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                hasResumed.withLock { resumed in
                    // 确保continuation只被resume一次
                    guard !resumed else { return }
                    resumed = true
                    
                    if let livePhoto = livePhoto {
                        continuation.resume(returning: livePhoto)
                    } else {
                        let error = info[PHLivePhotoInfoErrorKey] as? Error
                        let errorMessage = error?.localizedDescription ?? "Live Photo创建失败"
                        continuation.resume(throwing: LivePhotoError.livePhotoCreationFailed(errorMessage))
                    }
                }
            }
        }
    }
    
    /// 创建临时目录
    private func createTempDirectory() -> URL {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("LivePhoto_\(UUID().uuidString)")
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    /// 清理临时目录
    private func cleanupTempDirectory(_ url: URL) {
        try? fileManager.removeItem(at: url)
    }
}

// MARK: - UIImage Extension for HEIC Support
extension UIImage {
    
    /// 将图片转换为HEIC格式数据
    func heicData(quality: CGFloat = 0.9) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
}
