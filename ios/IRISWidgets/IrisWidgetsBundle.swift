import WidgetKit
import SwiftUI

#if canImport(ActivityKit) && canImport(WidgetKit)
@main
struct IrisWidgetsBundle: WidgetBundle {
    var body: some Widget {
        IrisLiveActivity()
    }
}
#endif

