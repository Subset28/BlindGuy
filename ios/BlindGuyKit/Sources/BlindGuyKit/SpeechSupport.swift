import Foundation

public enum TTSVerbosityMode: String, CaseIterable, Sendable {
    case lowNoise
    case normal
    case criticalOnly
}

public enum DistanceConfidence: String, Sendable, Codable {
    case high
    case medium
    case low
    case unavailable
}

public struct DistanceAssessment: Sendable, Codable {
    public let meters: Double?
    public let confidence: DistanceConfidence
    public let wasDampened: Bool

    public init(meters: Double?, confidence: DistanceConfidence, wasDampened: Bool) {
        self.meters = meters
        self.confidence = confidence
        self.wasDampened = wasDampened
    }
}

public struct DistanceFrameSample: Sendable {
    public let objectID: String
    public let className: String
    public let bbox: BBoxNorm
    public let rawDistanceM: Double
    public let timestamp: Date

    public init(objectID: String, className: String, bbox: BBoxNorm, rawDistanceM: Double, timestamp: Date) {
        self.objectID = objectID
        self.className = className
        self.bbox = bbox
        self.rawDistanceM = rawDistanceM
        self.timestamp = timestamp
    }
}

public protocol DistanceConfidenceAssessing: Sendable {
    mutating func assess(_ sample: DistanceFrameSample, hasKnownHeight: Bool) -> DistanceAssessment
}

private struct DistanceHistory: Sendable {
    var previous: DistanceFrameSample?
    var areaHistory: [Double] = []
    var smoothedDistance: Double?
}

public struct DistanceConfidenceAssessor: DistanceConfidenceAssessing, Sendable {
    private var byID: [String: DistanceHistory] = [:]
    private let alpha: Double

    public init(alpha: Double = 0.3) {
        self.alpha = alpha
    }

    public mutating func assess(_ sample: DistanceFrameSample, hasKnownHeight: Bool) -> DistanceAssessment {
        var hist = byID[sample.objectID] ?? DistanceHistory()
        let area = max(1e-6, sample.bbox.widthNorm * sample.bbox.heightNorm)
        hist.areaHistory.append(area)
        if hist.areaHistory.count > 3 {
            hist.areaHistory.removeFirst(hist.areaHistory.count - 3)
        }

        if sample.bbox.heightNorm < 0.02 || occlusionRatio(sample.bbox) >= 0.8 {
            hist.previous = sample
            byID[sample.objectID] = hist
            return DistanceAssessment(meters: nil, confidence: .unavailable, wasDampened: false)
        }

        var outDistance = sample.rawDistanceM
        var dampened = false
        var iouStable = false
        if let prev = hist.previous {
            let iou = iouNorm(prev.bbox, sample.bbox)
            iouStable = iou > 0.7
            if prev.rawDistanceM > 1e-6 {
                let jump = abs(sample.rawDistanceM - prev.rawDistanceM) / prev.rawDistanceM
                if jump > 0.4 {
                    let base = hist.smoothedDistance ?? prev.rawDistanceM
                    outDistance = alpha * sample.rawDistanceM + (1.0 - alpha) * base
                    dampened = true
                    hist.smoothedDistance = outDistance
                } else {
                    hist.smoothedDistance = sample.rawDistanceM
                }
            }
        } else {
            hist.smoothedDistance = sample.rawDistanceM
        }

        let variance = areaVariance(hist.areaHistory)
        var conf: DistanceConfidence = .low
        if dampened {
            conf = .medium
        } else if iouStable && hasKnownHeight && variance < 0.0012 {
            conf = .high
        } else if (iouStable && hasKnownHeight) || variance < 0.003 {
            conf = .medium
        } else {
            conf = .low
        }

        hist.previous = sample
        byID[sample.objectID] = hist
        return DistanceAssessment(
            meters: min(max(outDistance, 0.1), 60.0),
            confidence: conf,
            wasDampened: dampened
        )
    }

    private func areaVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = values.reduce(0, +) / Double(values.count)
        return values.reduce(0) { $0 + pow($1 - m, 2) } / Double(values.count)
    }

    private func iouNorm(_ a: BBoxNorm, _ b: BBoxNorm) -> Double {
        let aX0 = a.xCenterNorm - a.widthNorm * 0.5
        let aX1 = a.xCenterNorm + a.widthNorm * 0.5
        let aY0 = a.yCenterNorm - a.heightNorm * 0.5
        let aY1 = a.yCenterNorm + a.heightNorm * 0.5
        let bX0 = b.xCenterNorm - b.widthNorm * 0.5
        let bX1 = b.xCenterNorm + b.widthNorm * 0.5
        let bY0 = b.yCenterNorm - b.heightNorm * 0.5
        let bY1 = b.yCenterNorm + b.heightNorm * 0.5
        let ix0 = max(aX0, bX0)
        let iy0 = max(aY0, bY0)
        let ix1 = min(aX1, bX1)
        let iy1 = min(aY1, bY1)
        let iw = max(0, ix1 - ix0)
        let ih = max(0, iy1 - iy0)
        let inter = iw * ih
        let aArea = max(1e-9, a.widthNorm * a.heightNorm)
        let bArea = max(1e-9, b.widthNorm * b.heightNorm)
        return inter / max(1e-9, aArea + bArea - inter)
    }

    private func occlusionRatio(_ b: BBoxNorm) -> Double {
        let x0 = b.xCenterNorm - b.widthNorm * 0.5
        let x1 = b.xCenterNorm + b.widthNorm * 0.5
        let y0 = b.yCenterNorm - b.heightNorm * 0.5
        let y1 = b.yCenterNorm + b.heightNorm * 0.5
        let ix0 = max(0, min(1, x0))
        let iy0 = max(0, min(1, y0))
        let ix1 = max(0, min(1, x1))
        let iy1 = max(0, min(1, y1))
        let visible = max(0, ix1 - ix0) * max(0, iy1 - iy0)
        let total = max(1e-9, b.widthNorm * b.heightNorm)
        return max(0, min(1, 1.0 - (visible / total)))
    }
}

public enum SpeechPriority: Sendable {
    case high
    case normal
}

public enum SpeechFlushMode: Sendable {
    case all
    case normalOnly
}

public protocol SpeechScheduling: Sendable {
    func enqueue(_ text: String, priority: SpeechPriority, ttl: TimeInterval, objectID: String?)
    func flush(_ mode: SpeechFlushMode)
    var currentDepth: Int { get }
    var highDepth: Int { get }
    var normalDepth: Int { get }
    func popNext() -> String?
    func sceneDropFlush(previousCount: Int, newCount: Int)
}

public final class SpeechScheduler: SpeechScheduling, @unchecked Sendable {
    private struct Item: Sendable {
        let id: String
        let text: String
        let expiresAt: Date
    }

    private var high: [Item] = []
    private var normal: [Item] = []
    private let lock = NSLock()
    private let capPerTier: Int

    public init(capPerTier: Int = 16) {
        self.capPerTier = capPerTier
    }

    public var currentDepth: Int { highDepth + normalDepth }
    public var highDepth: Int { lock.withLock { high.count } }
    public var normalDepth: Int { lock.withLock { normal.count } }

    public func enqueue(_ text: String, priority: SpeechPriority, ttl: TimeInterval, objectID: String?) {
        let id = objectID ?? UUID().uuidString
        let item = Item(id: id, text: text, expiresAt: Date().addingTimeInterval(ttl))
        lock.withLock {
            switch priority {
            case .high:
                high.append(item)
                if high.count > capPerTier { high.removeFirst(high.count - capPerTier) }
            case .normal:
                normal.append(item)
                if normal.count > capPerTier { normal.removeFirst(normal.count - capPerTier) }
            }
        }
    }

    public func popNext() -> String? {
        lock.withLock {
            pruneExpiredLocked()
            if let i = high.popLast() { return i.text } // stack / LIFO
            if !normal.isEmpty { return normal.removeFirst().text } // queue / FIFO
            return nil
        }
    }

    public func flush(_ mode: SpeechFlushMode) {
        lock.withLock {
            switch mode {
            case .all:
                high.removeAll()
                normal.removeAll()
            case .normalOnly:
                normal.removeAll()
            }
        }
    }

    public func sceneDropFlush(previousCount: Int, newCount: Int) {
        guard previousCount > 0 else { return }
        // Requirement: if object count drops by >50% in one frame, flush normal queue immediately.
        if newCount * 2 < previousCount {
            flush(.normalOnly)
        }
    }

    private func pruneExpiredLocked() {
        let now = Date()
        high = high.filter { $0.expiresAt > now }
        normal = normal.filter { $0.expiresAt > now }
    }
}

public protocol PhraseBuilding: Sendable {
    func phrase(
        objectClass: String,
        panValue: Double,
        distance: DistanceAssessment,
        units: String
    ) -> String
}

public struct PhraseBuilder: PhraseBuilding, Sendable {
    public init() {}

    public func phrase(objectClass: String, panValue: Double, distance: DistanceAssessment, units: String) -> String {
        let base = "\(humanize(objectClass)) \(direction(panValue))"
        switch distance.confidence {
        case .high:
            if let m = distance.meters { return "\(base), about \(unitsValue(meters: m, units: units))" }
            return base
        case .medium:
            if let m = distance.meters { return "\(base), roughly \(unitsValue(meters: m, units: units))" }
            return base
        case .low:
            if let m = distance.meters {
                if m <= 2.2 { return "\(base), nearby" }
                return "\(base), farther ahead"
            }
            return base
        case .unavailable:
            return "\(humanize(objectClass)) detected"
        }
    }

    private func direction(_ pan: Double) -> String {
        switch pan {
        case ..<(-0.45): return "to the left"
        case 0.45...: return "to the right"
        default: return "ahead"
        }
    }

    private func unitsValue(meters: Double, units: String) -> String {
        let m = min(max(0.1, meters), 60.0)
        if units == "imperial" {
            let feet = Int(round(m * 3.28084))
            return "\(feet) feet"
        }
        return "\(Int(round(m))) meters"
    }

    private func humanize(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "Object" }
        return t.prefix(1).uppercased() + t.dropFirst().lowercased()
    }
}

public protocol DedupePolicyProtocol: Sendable {
    mutating func shouldSpeak(objectID: String, objectClass: String, distance: Double) -> Bool
    mutating func recordSpoken(objectID: String, objectClass: String)
    mutating func reset()
}

public struct DedupePolicy: DedupePolicyProtocol, Sendable {
    private var lastByID: [String: Date] = [:]
    private var lastByClass: [String: Date] = [:]
    private let idCooldown: TimeInterval
    private let classCooldown: TimeInterval

    public init(idCooldown: TimeInterval = 6.0, classCooldown: TimeInterval = 3.0) {
        self.idCooldown = idCooldown
        self.classCooldown = classCooldown
    }

    public mutating func shouldSpeak(objectID: String, objectClass: String, distance _: Double) -> Bool {
        let now = Date()
        if let t = lastByID[objectID], now.timeIntervalSince(t) < idCooldown { return false }
        let c = objectClass.lowercased()
        if let t = lastByClass[c], now.timeIntervalSince(t) < classCooldown { return false }
        return true
    }

    public mutating func recordSpoken(objectID: String, objectClass: String) {
        let now = Date()
        lastByID[objectID] = now
        lastByClass[objectClass.lowercased()] = now
    }

    public mutating func reset() {
        lastByID.removeAll()
        lastByClass.removeAll()
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
