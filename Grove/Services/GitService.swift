import Foundation

struct Commit: Identifiable {
    let id: String
    let message: String
    let date: Date
}

class GitService {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        // git log --date=iso output is like "2023-10-27 10:00:00 -0700"
        // ISO8601DateFormatter expects "2023-10-27T10:00:00-0700"
        // We might need a custom formatter or adjust the git log format.
        // Let's use --date=iso8601-strict if available, or just strict ISO.
        return formatter
    }()
    
    func commit(message: String, in directory: URL) async throws {
        _ = try await shell("git", "add", ".", in: directory)
        _ = try await shell("git", "commit", "-m", message, in: directory)
    }

    func log(for file: URL) async throws -> [Commit] {
        // Use ISO 8601 strict format for easier parsing
        let output = try await shell("git", "log", "--pretty=format:%h|%s|%aI", "--", file.lastPathComponent, in: file.deletingLastPathComponent())
        
        return output.components(separatedBy: .newlines).compactMap { line in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { return nil }
            
            let date = ISO8601DateFormatter().date(from: parts[2]) ?? Date()
            return Commit(id: parts[0], message: parts[1], date: date)
        }
    }
    
    func initRepo(in directory: URL) async throws {
        _ = try await shell("git", "init", in: directory)
    }
    
    func status(in directory: URL) async throws -> String {
        return try await shell("git", "status", "--short", in: directory)
    }
    
    func hasChanges(in directory: URL) async -> Bool {
        do {
            let status = try await status(in: directory)
            return !status.isEmpty
        } catch {
            return false
        }
    }
}
