import Foundation
let str = """
{
  "media_id": "reel_6eecbe081ab2",
  "title": "Cooking Reel",
  "caption": "Cook cook",
  "author": "chef",
  "thumbnail": null,
  "download_url": "/reels/media/reel_6eecbe081ab2.mp4"
}
"""
struct ReelDownloadResult: Decodable {
    let mediaId: String
    let title: String?
    let caption: String?
    let author: String?
    let thumbnail: String?
    let downloadUrl: String
}
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
do {
    let res = try decoder.decode(ReelDownloadResult.self, from: str.data(using: .utf8)!)
    print("Decoded: \(res)")
} catch {
    print("Error: \(error)")
}
