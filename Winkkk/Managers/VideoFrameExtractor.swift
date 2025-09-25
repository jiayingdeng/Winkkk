//
//  VideoFrameExtractor.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/25.
//  视频帧提取器 - 从视频中提取关键帧用于分割测试
//

import UIKit
import AVFoundation
import CoreMedia

class VideoFrameExtractor {
    
    // MARK: - Singleton
    static let shared = VideoFrameExtractor()
    private init() {}
    
    // MARK: - Types
    typealias FrameExtractionCompletion = (Result<[UIImage], FrameExtractionError>) -> Void
    typealias ProgressCallback = (Int, Int) -> Void
    
    // MARK: - Public Methods
    
    /// 从视频中提取指定数量的关键帧
    /// - Parameters:
    ///   - videoURL: 视频文件URL
    ///   - frameCount: 要提取的帧数量，默认为5
    ///   - maxResolution: 最大分辨率，默认为720p
    ///   - progressCallback: 进度回调
    ///   - completion: 完成回调
    func extractFrames(
        from videoURL: URL,
        frameCount: Int = 5,
        maxResolution: CGFloat = 720.0,
        progressCallback: ProgressCallback? = nil,
        completion: @escaping FrameExtractionCompletion
    ) {
        Task {
            do {
                // 创建AVAsset
                let asset = AVAsset(url: videoURL)
                
                // 获取视频时长
                let duration = try await asset.load(.duration)
                guard duration.seconds > 0 else {
                    DispatchQueue.main.async {
                        completion(.failure(.invalidVideoDuration))
                    }
                    return
                }
                
                // 计算帧的时间戳
                let timestamps = self.calculateFrameTimestamps(videoDuration: duration, frameCount: frameCount)
                
                // 创建图像生成器
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.requestedTimeToleranceAfter = .zero
                imageGenerator.requestedTimeToleranceBefore = .zero
                
                // 设置最大尺寸以控制内存使用
                imageGenerator.maximumSize = CGSize(width: maxResolution, height: maxResolution)
                
                var extractedFrames: [UIImage] = []
                
                // 提取每一帧
                for (index, timestamp) in timestamps.enumerated() {
                    do {
                        let cgImage = try imageGenerator.copyCGImage(at: timestamp, actualTime: nil)
                        let uiImage = UIImage(cgImage: cgImage)
                        extractedFrames.append(uiImage)
                        
                        // 更新进度
                        DispatchQueue.main.async {
                            progressCallback?(index + 1, frameCount)
                        }
                        
                        print("✅ 成功提取第\(index + 1)帧，时间: \(timestamp.seconds)秒")
                        
                    } catch {
                        print("❌ 提取第\(index + 1)帧失败: \(error)")
                        // 继续处理其他帧，不中断整个过程
                    }
                }
                
                // 检查是否成功提取了足够的帧
                guard !extractedFrames.isEmpty else {
                    DispatchQueue.main.async {
                        completion(.failure(.noFramesExtracted))
                    }
                    return
                }
                
                print("✅ 成功提取\(extractedFrames.count)帧")
                
                // 返回结果
                DispatchQueue.main.async {
                    completion(.success(extractedFrames))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.assetLoadFailed(error)))
                }
            }
        }
    }
    
    /// 获取视频基本信息
    /// - Parameter videoURL: 视频文件URL
    /// - Returns: 视频信息
    func getVideoInfo(from videoURL: URL) async -> ExtractedVideoInfo? {
        do {
            let asset = AVAsset(url: videoURL)
            
            // 加载基本属性
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)
            
            // 获取视频轨道
            guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
                return nil
            }
            
            let naturalSize = try await videoTrack.load(.naturalSize)
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
            
            return ExtractedVideoInfo(
                duration: duration.seconds,
                resolution: naturalSize,
                frameRate: nominalFrameRate,
                fileSize: getFileSize(url: videoURL)
            )
            
        } catch {
            print("❌ 获取视频信息失败: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// 计算均匀分布的帧时间戳
    /// - Parameters:
    ///   - videoDuration: 视频时长
    ///   - frameCount: 帧数量
    /// - Returns: 时间戳数组
    private func calculateFrameTimestamps(videoDuration: CMTime, frameCount: Int) -> [CMTime] {
        guard frameCount > 0 else { return [] }
        
        let durationSeconds = videoDuration.seconds
        var timestamps: [CMTime] = []
        
        if frameCount == 1 {
            // 只提取一帧时，选择中间位置
            let midTime = durationSeconds / 2.0
            timestamps.append(CMTime(seconds: midTime, preferredTimescale: videoDuration.timescale))
        } else {
            // 多帧时均匀分布，避开开头和结尾
            let margin = durationSeconds * 0.1 // 10%边距
            let usableDuration = durationSeconds - (2 * margin)
            let interval = usableDuration / Double(frameCount - 1)
            
            for i in 0..<frameCount {
                let timeSeconds = margin + (Double(i) * interval)
                let timestamp = CMTime(seconds: timeSeconds, preferredTimescale: videoDuration.timescale)
                timestamps.append(timestamp)
            }
        }
        
        return timestamps
    }
    
    /// 获取文件大小
    /// - Parameter url: 文件URL
    /// - Returns: 文件大小（字节）
    private func getFileSize(url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - Data Structures

struct ExtractedVideoInfo {
    let duration: Double        // 时长（秒）
    let resolution: CGSize      // 分辨率
    let frameRate: Float        // 帧率
    let fileSize: Int64         // 文件大小（字节）
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedResolution: String {
        return "\(Int(resolution.width))×\(Int(resolution.height))"
    }
}

enum FrameExtractionError: LocalizedError {
    case invalidVideoDuration
    case assetLoadFailed(Error)
    case noFramesExtracted
    case imageGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidVideoDuration:
            return "视频时长无效"
        case .assetLoadFailed(let error):
            return "视频资源加载失败: \(error.localizedDescription)"
        case .noFramesExtracted:
            return "未能提取任何视频帧"
        case .imageGenerationFailed:
            return "图像生成失败"
        }
    }
}
