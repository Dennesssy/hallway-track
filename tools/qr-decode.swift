import Vision
import Foundation
let u = URL(fileURLWithPath: CommandLine.arguments[1])
let r = VNDetectBarcodesRequest()
let h = VNImageRequestHandler(url: u)
try h.perform([r])
for o in r.results ?? [] { print(o.payloadStringValue ?? "nil") }
