import Foundation
import Testing
@testable import Restless

@Test("Shared stays free of SwiftData and SwiftUI outside Theme")
func sharedStaysPure() throws {
    let shared = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Shared")
    guard FileManager.default.fileExists(atPath: shared.path) else { return }

    let files = try FileManager.default.contentsOfDirectory(at: shared, includingPropertiesForKeys: nil)
    for file in files where file.pathExtension == "swift" && file.lastPathComponent != "Theme.swift" {
        let body = try String(contentsOf: file, encoding: .utf8)
        #expect(!body.contains("import SwiftData"), "\(file.lastPathComponent) imports SwiftData")
        #expect(!body.contains("import SwiftUI"), "\(file.lastPathComponent) imports SwiftUI")
    }
}
