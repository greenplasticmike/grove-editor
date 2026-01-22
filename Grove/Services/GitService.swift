import Foundation

struct Commit: Identifiable {
    let id: String
    let message: String
    let date: Date
}

class GitService {
    func commit(message: String, in directory: URL) async throws {
        _ = try await shell("git", "add", ".", in: directory)
        _ = try await shell("git", "commit", "-m", message, in: directory)
    }

    func log(for file: URL) async throws -> [Commit] {
        let output = try await shell("git", "log", "--pretty=format:%h|%s|%ad", "--date=iso", "--", file.lastPathComponent, in: file.deletingLastPathComponent())
        
        return output.components(separatedBy: .newlines).compactMap { line in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { return nil }
            // Basic parsing, would need real date parsing
            return Commit(id: parts[0], message: parts[1], date: Date())
        }
    }
    
    func initRepo(in directory: URL) async throws {
        _ = try await shell("git", "init", in: directory)
    }
}
