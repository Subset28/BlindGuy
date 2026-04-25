import Foundation

struct FramePayload: Decodable {
    let frame_id: Int
    let timestamp_ms: Int64
    let vision_duration_ms: Int
    let objects: [ObjectPayload]
}

struct ObjectPayload: Decodable {
    let object_id: String
    let `class`: String
    let confidence: Float
    let bbox: BBox
    let distance_m: Float
    let pan_value: Float
    let velocity_mps: Float?
    let priority: String?
}

struct BBox: Decodable {
    let x_center_norm: Float
    let y_center_norm: Float
    let width_norm: Float
    let height_norm: Float
}
