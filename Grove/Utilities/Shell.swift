import Foundation

func shell(_ args: String..., in directory: URL? = nil) async throws -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    task.arguments = args
    
    if let directory = directory {
        task.currentDirectoryURL = directory
    }
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    try task.run()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    
    guard let output = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "ShellError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode output"])
    }
    
    if task.terminationStatus != 0 {
        throw NSError(domain: "ShellError", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
    }
    
    return output.trimmingCharacters(in: .newlines)
}
