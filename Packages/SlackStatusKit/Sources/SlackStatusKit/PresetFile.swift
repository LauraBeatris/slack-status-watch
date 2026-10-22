import Foundation

/*
 JSON file holding the preset list. The phone's copy is the source of truth,
 the watch keeps a cache so it works with the phone out of range
 */
public struct PresetFile: Sendable {
  private let url: URL

  public init(url: URL) {
    self.url = url
  }

  public init(directory: FileManager.SearchPathDirectory = .applicationSupportDirectory) {
    let base = FileManager.default.urls(for: directory, in: .userDomainMask)[0]
    self.init(url: base.appendingPathComponent("presets.json"))
  }

  public func load() -> [StatusPreset] {
    guard let data = try? Data(contentsOf: url),
      let presets = try? JSONDecoder().decode([StatusPreset].self, from: data)
    else { return StatusPreset.defaults }
    return presets
  }

  public func save(_ presets: [StatusPreset]) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(presets).write(to: url, options: .atomic)
  }
}

extension [StatusPreset] {
  public func encodedForSync() throws -> Data {
    try JSONEncoder().encode(self)
  }

  public static func decodedFromSync(_ data: Data) throws -> [StatusPreset] {
    try JSONDecoder().decode([StatusPreset].self, from: data)
  }
}
