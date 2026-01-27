import Foundation

func shell(_ args: String..., in directory: URL? = nil) async throws -> String {
    let task = Process()

    // For git commands, use the direct path to avoid xcrun issues
    let executable: String
    var arguments = Array(args)

    if let first = args.first, first == "git" {
        executable = "/usr/bin/git"
        arguments = Array(args.dropFirst())
    } else {
        executable = "/usr/bin/env"
        arguments = Array(args)
    }

    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = arguments
    
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
