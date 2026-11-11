#!/usr/bin/env swift
// Encodes a folder of PNG frames into an H.264 MP4 that link previews can play.
//
//   swift Scripts/encode-frames.swift <frames-dir> <out.mp4> [fps]
//
// The file is written with its index at the front, so a player that asks for
// byte ranges can start before it has the whole thing.

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("encode-frames: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { fail("usage: encode-frames.swift <frames-dir> <out.mp4> [fps]") }
let framesURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let fps = arguments.count > 3 ? Int32(arguments[3]) ?? 30 : 30

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("cannot read \(url.lastPathComponent)") }
    return image
}

let frames = ((try? FileManager.default.contentsOfDirectory(at: framesURL, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard let first = frames.first.map(loadImage) else { fail("no PNG frames in \(framesURL.path)") }

// H.264 wants even dimensions
let width = first.width - first.width % 2
let height = first.height - first.height % 2

// The writer leaves a scratch file beside whatever it writes, so it works in a folder of its own
let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("encode-frames-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: scratch) }
let scratchURL = scratch.appendingPathComponent("out.mp4")
guard let writer = try? AVAssetWriter(outputURL: scratchURL, fileType: .mp4) else { fail("cannot write \(scratchURL.path)") }
writer.shouldOptimizeForNetworkUse = true

let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ],
    AVVideoCompressionPropertiesKey: [
        // Mostly flat colour and a still background, so this is generous
        AVVideoAverageBitRateKey: 1_600_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoExpectedSourceFrameRateKey: fps,
        AVVideoMaxKeyFrameIntervalKey: fps * 2,
    ],
])
input.expectsMediaDataInRealTime = false

let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height,
])
writer.add(input)
guard writer.startWriting() else { fail(writer.error?.localizedDescription ?? "cannot start writing") }
writer.startSession(atSourceTime: .zero)

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

for (index, url) in frames.enumerated() {
    while !input.isReadyForMoreMediaData { usleep(2_000) }

    var buffer: CVPixelBuffer?
    guard let pool = adaptor.pixelBufferPool,
          CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
          let buffer
    else { fail("cannot allocate a frame") }

    CVPixelBufferLockBaseAddress(buffer, [])
    guard let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: colorSpace, bitmapInfo: bitmapInfo
    ) else { fail("cannot draw a frame") }
    let image = index == 0 ? first : loadImage(url)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    CVPixelBufferUnlockBaseAddress(buffer, [])

    guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: fps)) else {
        fail(writer.error?.localizedDescription ?? "cannot append frame \(index)")
    }
}

input.markAsFinished()
writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frames.count), timescale: fps))
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
guard writer.status == .completed else { fail(writer.error?.localizedDescription ?? "encoding failed") }

try? FileManager.default.removeItem(at: outputURL)
do { try FileManager.default.moveItem(at: scratchURL, to: outputURL) } catch { fail(error.localizedDescription) }
print("encoded \(frames.count) frames at \(fps) fps, \(width) x \(height)")
