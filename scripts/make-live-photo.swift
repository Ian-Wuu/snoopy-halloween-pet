import Foundation
import AVFoundation
import ImageIO
import Photos
import AppKit
let dir = URL(fileURLWithPath: CommandLine.arguments[1])
let ident = UUID().uuidString
let jpg = dir.appendingPathComponent("Snoopy-Halloween-Live.JPG")
let mov = dir.appendingPathComponent("Snoopy-Halloween-Live.MOV")
try? FileManager.default.removeItem(at: mov)
let source = CGImageSourceCreateWithURL(dir.appendingPathComponent("cover.png") as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let dest = CGImageDestinationCreateWithURL(jpg as CFURL, "public.jpeg" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, [kCGImagePropertyMakerAppleDictionary: ["17": ident],kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
guard CGImageDestinationFinalize(dest) else { fatalError("JPEG failed") }
let asset = AVURLAsset(url: dir.appendingPathComponent("video.mp4"))
let track = asset.tracks(withMediaType: .video)[0]
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
reader.add(output)
let writer = try AVAssetWriter(outputURL: mov, fileType: .mov)
let cid = AVMutableMetadataItem()
cid.keySpace = .quickTimeMetadata
cid.key = "com.apple.quicktime.content.identifier" as NSString
cid.value = ident as NSString
cid.dataType = "com.apple.metadata.datatype.UTF-8"
writer.metadata = [cid]
let video = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: track.formatDescriptions[0] as! CMFormatDescription)
video.transform = track.preferredTransform
writer.add(video)
var desc: CMFormatDescription?
let specs: [String:Any] = [kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:"mdta/com.apple.quicktime.still-image-time", kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:"com.apple.metadata.datatype.int8"]
let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator:kCFAllocatorDefault,metadataType:kCMMetadataFormatType_Boxed,metadataSpecifications:[specs] as CFArray,formatDescriptionOut:&desc)
guard status == noErr else { fatalError("metadata format failed") }
let meta = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint:desc)
let adaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: meta)
writer.add(meta)
writer.startWriting();writer.startSession(atSourceTime:.zero);reader.startReading()
let still = AVMutableMetadataItem();still.keySpace = .quickTimeMetadata;still.key = "com.apple.quicktime.still-image-time" as NSString;still.value = NSNumber(value:Int8(0));still.dataType = "com.apple.metadata.datatype.int8"
let group = AVTimedMetadataGroup(items:[still],timeRange:CMTimeRange(start:CMTime(seconds:0.5,preferredTimescale:600),duration:CMTime(value:1,timescale:30)))
guard adaptor.append(group) else {fatalError("append metadata failed")};meta.markAsFinished()
while let sample = output.copyNextSampleBuffer() {
 while !video.isReadyForMoreMediaData { Thread.sleep(forTimeInterval:0.005) }
 guard video.append(sample) else { fatalError("video append failed \(String(describing:writer.error))") }
}
video.markAsFinished()
let done = DispatchSemaphore(value:0)
writer.finishWriting {done.signal()};done.wait()
guard writer.status == .completed else {fatalError("MOV failed \(String(describing:writer.error))")}
print("Pair written; identifier: \(ident)")
var finished = false
var valid = false
PHLivePhoto.request(withResourceFileURLs:[jpg,mov],placeholderImage:nil,targetSize:.zero,contentMode:.aspectFit) { photo,info in
 if (info[PHLivePhotoInfoIsDegradedKey] as? Bool) == true {return}
 valid = photo != nil
 print("PHLivePhoto valid: \(valid); info: \(info)")
 finished = true
}
let deadline = Date().addingTimeInterval(40)
while !finished && Date() < deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.1)) }
let result:[String:Any] = ["identifier":ident,"photos_framework_valid":valid,"validation_finished":finished,"duration_seconds":CMTimeGetSeconds(asset.duration)]
try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:dir.appendingPathComponent("LivePhoto-validation.json"))
