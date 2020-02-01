// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import os.log
import SwiftUI

/// Drag State describing the combination of a long press and drag gesture.
///  - seealso:
///  [Reference]: https://developer.apple.com/documentation/swiftui/gestures/composing_swiftui_gestures "Composing SwiftUI Gestures "
enum DragState {
    case inactive
    case pressing
    case dragging(translation: CGSize)

    var translation: CGSize {
        switch self {
        case .inactive, .pressing:
            return .zero
        case let .dragging(translation):
            return translation
        }
    }

    var isActive: Bool {
        switch self {
        case .inactive:
            return false
        case .pressing, .dragging:
            return true
        }
    }

    var isDragging: Bool {
        switch self {
        case .inactive, .pressing:
            return false
        case .dragging:
            return true
        }
    }
}

// swiftlint:disable file_types_order
struct ColorSelection: View {
    @GestureState var satBrightState: DragState = .inactive

    @State var hue: Double = 0.5
    @State var saturation: Double = 0.5
    @State var brightness: Double = 0.5

    var body: some View {
        let spectrum = Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red])

        let conic = AngularGradient(gradient: spectrum, center: .center, angle: .degrees(0))

        return
            GeometryReader { (geometry: GeometryProxy) in
                    Circle()
                        .size(geometry.size)
                        .fill(conic)
                        .overlay(self.generateHandle(geometry: geometry))
                }
    }

    /// Prevent values like hue, saturation and brightness from being greater than 1 or less than 0
    func limitValue(_ value: Double, _ limit: CGFloat, _ state: CGFloat) -> Double {
        max(0, min(1, value + Double(state / limit)))
    }

    /// Prevent the draggable element from going over its limit
    func limitDisplacement(_ value: Double, _ limit: CGFloat, _ state: CGFloat) -> CGFloat {
        max(0, min(limit, CGFloat(value) * limit + state))
    }

    /// Prevent the draggable element from going beyond the circle
    func limitCircle(_ point: CGPoint, _ limit: CGSize, _ state: CGSize) -> (CGPoint) {
        let newx = point.x * limit.width + state.width
        let newy = point.y * limit.height + state.height

        let x1 = newx - limit.width / 2
        let y1 = -newy + limit.height / 2
        let theta = atan2(x1, y1)
        // Circle limit.width = limit.height
        let radius = min(sqrt(x1 * x1 + y1 * y1), limit.width / 2)

        os_log("Slider new x1, x2 = %g, %g", log: .default, type: .info, x1, y1)

        return CGPoint(x: cos(theta) * radius + limit.width / 2, y: -sin(theta) * radius + limit.width / 2)
    }

    /// Creates the `Handle` and adds the drag gesture to it.
    func generateHandle(geometry: GeometryProxy) -> some View {
        ///  [Reference]: https://developer.apple.com/documentation/swiftui/gestures/composing_swiftui_gestures "Composing SwiftUI Gestures "
        let longPressDrag = LongPressGesture(minimumDuration: 0.05)
            .sequenced(before: DragGesture())
            .updating($satBrightState) { value, state, _ in
                switch value {
                // Long press begins.
                case .first(true):
                    state = .pressing
                // Long press confirmed, dragging may begin.
                case .second(true, let drag):
                    state = .dragging(translation: drag?.translation ?? .zero)
                // Dragging ended or the long press cancelled.
                default:
                    state = .inactive
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                self.saturation = self.limitValue(self.saturation, geometry.size.width, drag.translation.width)
                self.brightness = self.limitValue(self.brightness, geometry.size.height, drag.translation.height)
            }

        // MARK: Customize Handle Here

        // Add the gestures and visuals to the handle
        return Circle()
            .overlay(satBrightState.isDragging ? Circle().stroke(Color.white, lineWidth: 2) : nil)
            .foregroundColor(.white)
            .frame(width: 25, height: 25, alignment: .center)
            .position(limitCircle(CGPoint(x: saturation, y: brightness), geometry.size, satBrightState.translation))
            .animation(.interactiveSpring())
            .gesture(longPressDrag)
    }
}

struct ColorSelection_Previews: PreviewProvider {
    static var previews: some View {
        ColorSelection()
    }
}