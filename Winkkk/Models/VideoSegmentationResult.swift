//
//  VideoSegmentationResult.swift
//  Winkkk
//
//  Created by Winkkk on 2024/12/25.
//  视频分割结果数据模型
//

import UIKit
import Foundation

// MARK: - 视频分割会话结果
struct VideoSegmentationSession {
    let videoInfo: VideoInfo
    let frameResults: [FrameSegmentationResult]
    let sessionStats: SessionStatistics
    let timestamp: Date
    
    init(videoInfo: VideoInfo, frameResults: [FrameSegmentationResult]) {
        self.videoInfo = videoInfo
        self.frameResults = frameResults
        self.sessionStats = SessionStatistics(from: frameResults)
        self.timestamp = Date()
    }
}

// MARK: - 单帧分割结果
struct FrameSegmentationResult {
    let frameIndex: Int                    // 帧索引（0开始）
    let timePosition: Double               // 时间位置（秒）
    let originalImage: UIImage             // 原始帧图像
    let segmentationResult: DeepLabSegmentationResult  // DeepLabV3分割结果
    let processingTime: TimeInterval       // 处理时间（秒）
    var status: VideoProcessingStatus      // 处理状态
    
    // 便捷属性
    var subjectImage: UIImage {
        return segmentationResult.subjectImage
    }
    
    var maskImage: UIImage {
        return segmentationResult.maskImage
    }
    
    var confidence: Float {
        return segmentationResult.confidence
    }
    
    var subjectPixelRatio: Float {
        return segmentationResult.subjectPixelRatio
    }
    
    var formattedTimePosition: String {
        let minutes = Int(timePosition) / 60
        let seconds = Int(timePosition) % 60
        let milliseconds = Int((timePosition.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

// MARK: - 视频处理状态
enum VideoProcessingStatus {
    case pending        // 等待处理
    case processing     // 处理中
    case completed      // 已完成
    case failed(Error)  // 处理失败
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
    
    var displayText: String {
        switch self {
        case .pending:
            return "等待处理"
        case .processing:
            return "处理中..."
        case .completed:
            return "已完成"
        case .failed(let error):
            return "失败: \(error.localizedDescription)"
        }
    }
    
    var color: UIColor {
        switch self {
        case .pending:
            return .systemGray
        case .processing:
            return .systemBlue
        case .completed:
            return .systemGreen
        case .failed:
            return .systemRed
        }
    }
}

// MARK: - 会话统计信息
struct SessionStatistics {
    let totalFrames: Int
    let completedFrames: Int
    let failedFrames: Int
    let averageConfidence: Float
    let averageSubjectRatio: Float
    let averageProcessingTime: TimeInterval
    let totalProcessingTime: TimeInterval
    let consistencyScore: Float  // 帧间一致性评分
    
    init(from results: [FrameSegmentationResult]) {
        self.totalFrames = results.count
        
        let completedResults = results.filter { $0.status.isCompleted }
        self.completedFrames = completedResults.count
        self.failedFrames = totalFrames - completedFrames
        
        if completedResults.isEmpty {
            self.averageConfidence = 0.0
            self.averageSubjectRatio = 0.0
            self.averageProcessingTime = 0.0
            self.totalProcessingTime = 0.0
            self.consistencyScore = 0.0
        } else {
            // 计算平均值
            self.averageConfidence = completedResults.map { $0.confidence }.reduce(0, +) / Float(completedResults.count)
            self.averageSubjectRatio = completedResults.map { $0.subjectPixelRatio }.reduce(0, +) / Float(completedResults.count)
            self.averageProcessingTime = completedResults.map { $0.processingTime }.reduce(0, +) / Double(completedResults.count)
            self.totalProcessingTime = completedResults.map { $0.processingTime }.reduce(0, +)
            
            // 计算一致性评分（基于相邻帧的主体像素比例差异）
            self.consistencyScore = Self.calculateConsistencyScore(from: completedResults)
        }
    }
    
    // 计算帧间一致性评分
    private static func calculateConsistencyScore(from results: [FrameSegmentationResult]) -> Float {
        guard results.count > 1 else { return 1.0 }
        
        var totalDifference: Float = 0.0
        for i in 1..<results.count {
            let diff = abs(results[i].subjectPixelRatio - results[i-1].subjectPixelRatio)
            totalDifference += diff
        }
        
        let averageDifference = totalDifference / Float(results.count - 1)
        
        // 将差异转换为评分（差异越小，评分越高）
        let consistencyScore = max(0.0, 1.0 - (averageDifference * 10.0))
        return consistencyScore
    }
    
    // 格式化统计信息
    var formattedSummary: String {
        return """
        📊 处理统计
        • 总帧数: \(totalFrames)
        • 成功: \(completedFrames) | 失败: \(failedFrames)
        • 平均置信度: \(String(format: "%.1f%%", averageConfidence * 100))
        • 平均主体占比: \(String(format: "%.1f%%", averageSubjectRatio * 100))
        • 帧间一致性: \(String(format: "%.1f%%", consistencyScore * 100))
        • 总处理时间: \(String(format: "%.2f秒", totalProcessingTime))
        """
    }
}

// MARK: - 批量处理进度
struct BatchProcessingProgress {
    let currentIndex: Int
    let totalCount: Int
    let currentFrame: FrameSegmentationResult?
    let elapsedTime: TimeInterval
    let estimatedTimeRemaining: TimeInterval?
    
    var percentage: Float {
        guard totalCount > 0 else { return 0.0 }
        return Float(currentIndex) / Float(totalCount)
    }
    
    var formattedProgress: String {
        return "\(currentIndex)/\(totalCount) (\(Int(percentage * 100))%)"
    }
    
    var formattedTimeRemaining: String {
        guard let remaining = estimatedTimeRemaining else {
            return "计算中..."
        }
        
        if remaining < 60 {
            return String(format: "剩余 %.0f秒", remaining)
        } else {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return String(format: "剩余 %d分%d秒", minutes, seconds)
        }
    }
}

// MARK: - 分割质量等级
enum SegmentationQuality {
    case excellent  // 优秀 (>0.8)
    case good       // 良好 (0.6-0.8)
    case fair       // 一般 (0.4-0.6)  
    case poor       // 较差 (<0.4)
    
    init(confidence: Float) {
        switch confidence {
        case 0.8...1.0:
            self = .excellent
        case 0.6..<0.8:
            self = .good
        case 0.4..<0.6:
            self = .fair
        default:
            self = .poor
        }
    }
    
    var displayText: String {
        switch self {
        case .excellent:
            return "优秀"
        case .good:
            return "良好"
        case .fair:
            return "一般"
        case .poor:
            return "较差"
        }
    }
    
    var color: UIColor {
        switch self {
        case .excellent:
            return .systemGreen
        case .good:
            return .systemBlue
        case .fair:
            return .systemOrange
        case .poor:
            return .systemRed
        }
    }
    
    var emoji: String {
        switch self {
        case .excellent:
            return "🌟"
        case .good:
            return "✅"
        case .fair:
            return "⚠️"
        case .poor:
            return "❌"
        }
    }
}

// MARK: - 扩展支持
extension FrameSegmentationResult {
    var quality: SegmentationQuality {
        return SegmentationQuality(confidence: confidence)
    }
}

extension SessionStatistics {
    var overallQuality: SegmentationQuality {
        return SegmentationQuality(confidence: averageConfidence)
    }
}
