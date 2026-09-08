import Foundation

extension String {
    func write(to url: URL) throws {
        guard let data = data(using: .utf8) else {
            throw GeneratorError("Failed to convert output to a data blob")
        }
        try data.write(to: url)
    }

    var filename: String {
        URL(fileURLWithPath: self).lastPathComponent
    }
}

extension URL {
    init(filePath: String) {
        self.init(fileURLWithPath: (filePath as NSString).expandingTildeInPath)
    }

    func appending(path: String) -> URL {
        appendingPathComponent(path)
    }

    func remove() throws {
        try FileManager.default.removeItem(at: self)
    }

    func createDirectoryIfNeeded() throws {
        guard !FileManager.default.fileExists(atPath: path) else { return }
        try FileManager.default.createDirectory(at: self, withIntermediateDirectories: true, attributes: nil)
    }

    /// Returns whether this URL is the same as, or is contained by, `directory`.
    /// Comparing path components avoids treating siblings such as `OutputBackup`
    /// as children of `Output`.
    func isSameOrDescendant(of directory: URL) -> Bool {
        let candidateComponents = resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let directoryComponents = directory.resolvingSymlinksInPath().standardizedFileURL.pathComponents

        guard candidateComponents.count >= directoryComponents.count else {
            return false
        }
        return candidateComponents.prefix(directoryComponents.count).elementsEqual(directoryComponents)
    }
}
