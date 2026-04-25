import Foundation

struct TrackState {
    var objectId: String
    var className: String
    var xCenterNorm: Double
    var yCenterNorm: Double
    var distanceM: Double
    var updatedAt: TimeInterval
    var lastSeenFrame: Int
}

/// Lightweight ID + velocity, aligned with Python `src/visual_engine/tracker.py`.
final class ObjectTracker {
    private var tracks: [String: TrackState] = [:]
    private var classCounters: [String: Int] = [:]
    private let maxGap: TimeInterval
    private let maxMatchDistanceNorm: Double
    private let highPriorityDistanceM: Double

    init(
        maxGapSeconds: TimeInterval = 1.0,
        /// Slightly loose so one person doesn’t get a new `object_id` every few frames (reduces TTS repeat labels).
        maxMatchDistanceNorm: Double = 0.24,
        highPriorityDistanceM: Double = 3.0
    ) {
        self.maxGap = maxGapSeconds
        self.maxMatchDistanceNorm = maxMatchDistanceNorm
        self.highPriorityDistanceM = highPriorityDistanceM
    }

    /// - Parameter frameIndex: monotonically increasing index for this vision update (used to prune very stale id maps).
    func update(
        detections: [RawDetection],
        now: TimeInterval,
        frameIndex: Int
    ) -> [TrackedDetection] {
        if frameIndex % 60 == 0 {
            pruneStaleObjects(currentFrame: frameIndex, maxAgeFrames: 90)
        }
        expireOldTracks(now: now)
        var usedIds = Set<String>()
        var out: [TrackedDetection] = []

        for d in detections {
            if let m = bestMatch(
                className: d.className,
                x: d.xCenterNorm,
                y: d.yCenterNorm,
                used: usedIds
            ) {
                let dt = max(now - m.updatedAt, 0.001)
                let v = abs(m.distanceM - d.distanceM) / dt
                usedIds.insert(m.objectId)
                tracks[m.objectId] = TrackState(
                    objectId: m.objectId,
                    className: d.className,
                    xCenterNorm: d.xCenterNorm,
                    yCenterNorm: d.yCenterNorm,
                    distanceM: d.distanceM,
                    updatedAt: now,
                    lastSeenFrame: frameIndex
                )
                out.append(
                    TrackedDetection(
                        className: d.className,
                        confidence: d.confidence,
                        xCenterNorm: d.xCenterNorm,
                        yCenterNorm: d.yCenterNorm,
                        widthNorm: d.widthNorm,
                        heightNorm: d.heightNorm,
                        distanceM: d.distanceM,
                        panValue: d.panValue,
                        objectId: m.objectId,
                        velocityMps: v,
                        priority: (d.distanceM.isFinite && d.distanceM < highPriorityDistanceM) ? "HIGH" : "NORMAL"
                    )
                )
            } else {
                let id = nextObjectId(for: d.className)
                let td = TrackedDetection(
                    className: d.className,
                    confidence: d.confidence,
                    xCenterNorm: d.xCenterNorm,
                    yCenterNorm: d.yCenterNorm,
                    widthNorm: d.widthNorm,
                    heightNorm: d.heightNorm,
                    distanceM: d.distanceM,
                    panValue: d.panValue,
                    objectId: id,
                    velocityMps: 0,
                    priority: (d.distanceM.isFinite && d.distanceM < highPriorityDistanceM) ? "HIGH" : "NORMAL"
                )
                usedIds.insert(id)
                tracks[id] = TrackState(
                    objectId: id,
                    className: d.className,
                    xCenterNorm: d.xCenterNorm,
                    yCenterNorm: d.yCenterNorm,
                    distanceM: d.distanceM,
                    updatedAt: now,
                    lastSeenFrame: frameIndex
                )
                out.append(td)
            }
        }
        return out
    }

    private func bestMatch(
        className: String,
        x: Double,
        y: Double,
        used: Set<String>
    ) -> TrackState? {
        var best: TrackState?
        var bestD = Double.greatestFiniteMagnitude
        for (_, s) in tracks where s.className == className && !used.contains(s.objectId) {
            let dx = s.xCenterNorm - x
            let dy = s.yCenterNorm - y
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist < bestD {
                bestD = dist
                best = s
            }
        }
        guard let b = best, bestD <= maxMatchDistanceNorm else { return nil }
        return b
    }

    private func expireOldTracks(now: TimeInterval) {
        tracks = tracks.filter { now - $0.value.updatedAt <= maxGap }
    }

    private func nextObjectId(for className: String) -> String {
        let n = (classCounters[className] ?? 0) + 1
        classCounters[className] = n
        return String(format: "%@_%03d", className, n)
    }

    private func pruneStaleObjects(currentFrame: Int, maxAgeFrames: Int) {
        let stale = tracks.filter { currentFrame - $0.value.lastSeenFrame > maxAgeFrames }
        for e in stale {
            tracks.removeValue(forKey: e.key)
        }
        if !stale.isEmpty, let onPrune = onStalePrune {
            onPrune(stale.count)
        }
    }

    /// Fires on the work queue when stale ids are removed.
    var onStalePrune: ((Int) -> Void)?
}

struct RawDetection {
    var className: String
    var confidence: Double
    var xCenterNorm: Double
    var yCenterNorm: Double
    var widthNorm: Double
    var heightNorm: Double
    var distanceM: Double
    var panValue: Double
}

struct TrackedDetection {
    var className: String
    var confidence: Double
    var xCenterNorm: Double
    var yCenterNorm: Double
    var widthNorm: Double
    var heightNorm: Double
    var distanceM: Double
    var panValue: Double
    var objectId: String
    var velocityMps: Double
    var priority: String
}
