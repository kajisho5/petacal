import Foundation

/// Where the fold of a foldable screen crosses a view (x positions in the view's own coordinates).
public struct FoldRegion: Equatable, Sendable {
    public var minX: Double
    public var maxX: Double
    /// True only while the device is partly folded.
    public var isActive: Bool

    public init(minX: Double, maxX: Double, isActive: Bool) {
        self.minX = minX
        self.maxX = maxX
        self.isActive = isActive
    }
}

/// How a wide screen is shared between the month (leading) and the day's list (trailing).
/// Plain arithmetic so it can be tested without a device.
public struct PaneSplit: Equatable, Sendable {
    public var leading: Double
    public var gap: Double
    public var trailing: Double
    /// The month pane is too narrow for titled bars: use the small month instead.
    public var compactMonth: Bool

    public static let minimumWidth = 700.0
    public static let minimumPane = 280.0
    public static let barsWidth = 560.0

    /// nil means one column (narrow window, iPhone, the outer display of a foldable).
    public static func compute(width: Double, fold: FoldRegion? = nil) -> PaneSplit? {
        guard width >= minimumWidth else { return nil }
        if let fold, fold.minX > 0, fold.maxX < width, fold.maxX >= fold.minX {
            // Split at the fold in both states, so folding moves things as little as possible.
            // Partly folded: nothing may sit on the fold. Fully open: an ordinary gap around its centre.
            let centre = (fold.minX + fold.maxX) / 2
            let gap = fold.isActive ? max(fold.maxX - fold.minX, 16) : 16
            let leading = centre - gap / 2
            let trailing = width - centre - gap / 2
            if leading >= minimumPane, trailing >= minimumPane {
                return PaneSplit(leading: leading, gap: gap, trailing: trailing, compactMonth: leading < barsWidth)
            }
        }
        let gap = 16.0
        let trailing = min(max(width * 0.34, 320), 440)
        let leading = width - trailing - gap
        return PaneSplit(leading: leading, gap: gap, trailing: trailing, compactMonth: leading < barsWidth)
    }
}
