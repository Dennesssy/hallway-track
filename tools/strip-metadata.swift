// Re-encode an image without EXIF/GPS/device metadata.
// Usage: swift tools/strip-metadata.swift <in.png> <out.png>
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3,
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
      let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { FileHandle.standardError.write(Data("usage: strip-metadata <in> <out>\n".utf8)); exit(2) }
CGImageDestinationAddImage(dst, img, nil)   // nil properties: no EXIF, GPS, make or model
exit(CGImageDestinationFinalize(dst) ? 0 : 1)
