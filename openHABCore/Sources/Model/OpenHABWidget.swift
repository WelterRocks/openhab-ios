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

import Alamofire
import Foundation
import Fuzi
import MapKit
import os.log

protocol Widget: AnyObject {
    //  Recursive constraints possible as of Swift 4.1
    associatedtype ChildWidget: Widget

    var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)? { get set }
    var widgetId: String { get set }
    var label: String { get set }
    var icon: String { get set }
    var type: String { get set }
    var url: String { get set }
    var period: String { get set }
    var minValue: Double { get set }
    var maxValue: Double { get set }
    var step: Double { get set }
    var refresh: Int { get set }
    var height: Double { get set }
    var isLeaf: Bool { get set }
    var iconColor: String { get set }
    var labelcolor: String { get set }
    var valuecolor: String { get set }
    var service: String { get set }
    var state: String { get set }
    var text: String { get set }
    var legend: Bool { get set }
    var encoding: String { get set }
    var item: OpenHABItem? { get set }
    var linkedPage: OpenHABLinkedPage? { get set }
    var mappings: [OpenHABWidgetMapping] { get set }
    var image: UIImage? { get set }
    var widgets: [ChildWidget] { get set }

    func flatten(_: [ChildWidget])
}

public class OpenHABWidget: NSObject, MKAnnotation, Identifiable {
    public var id: String = ""

    public var sendCommand: ((_ item: OpenHABItem, _ command: String?) -> Void)?
    public var widgetId = ""
    public var label = ""
    public var icon = ""
    public var type = ""
    public var url = ""
    public var period = ""
    public var minValue = 0.0
    public var maxValue = 100.0
    public var step = 1.0
    public var refresh = 0
    public var height = ""
    public var isLeaf = false
    public var iconColor = ""
    public var labelcolor = ""
    public var valuecolor = ""
    public var service = ""
    public var state = ""
    public var text = ""
    public var legend: Bool?
    public var encoding = ""
    public var item: OpenHABItem?
    public var linkedPage: OpenHABLinkedPage?
    public var mappings: [OpenHABWidgetMapping] = []
    public var image: UIImage?
    public var widgets: [OpenHABWidget] = []

    // Text prior to "["
    public var labelText: String? {
        let array = label.components(separatedBy: "[")
        return array[0].trimmingCharacters(in: .whitespaces)
    }

    // Text between square brackets
    public var labelValue: String? {
        // Swift 5 raw strings
        let regex = try? NSRegularExpression(pattern: #"\[(.*?)\]"#, options: [])
        guard let match = regex?.firstMatch(in: label, options: [], range: NSRange(location: 0, length: (label as NSString).length)) else { return nil }
        guard let range = Range(match.range(at: 1), in: label) else { return nil }
        return String(label[range])
    }

    public var coordinate: CLLocationCoordinate2D {
        item?.stateAsLocation()?.coordinate ?? kCLLocationCoordinate2DInvalid
    }

    public var mappingsOrItemOptions: [OpenHABWidgetMapping] {
        if mappings.isEmpty, let itemOptions = item?.stateDescription?.options {
            return itemOptions.map { OpenHABWidgetMapping(command: $0.value, label: $0.label) }
        } else {
            return mappings
        }
    }

    public func sendCommandDouble(_ command: Double) {
        sendCommand(String(command))
    }

    public func sendCommand(_ command: String?) {
        guard let item = item else {
            os_log("Command for Item = nil", log: .default, type: .info)
            return
        }
        guard let sendCommand = sendCommand else {
            os_log("sendCommand closure not set", log: .default, type: .info)
            return
        }
        sendCommand(item, command)
    }

    public func mappingIndex(byCommand command: String?) -> Int? {
        mappingsOrItemOptions.firstIndex { $0.command == command }
    }
}

extension OpenHABWidget {
    // This is an ugly initializer
    convenience init(widgetId: String, label: String, icon: String, type: String, url: String?, period: String?, minValue: Double?, maxValue: Double?, step: Double?, refresh: Int?, height: Double?, isLeaf: Bool?, iconColor: String?, labelColor: String?, valueColor: String?, service: String?, state: String?, text: String?, legend: Bool?, encoding: String?, item: OpenHABItem?, linkedPage: OpenHABLinkedPage?, mappings: [OpenHABWidgetMapping], widgets: [OpenHABWidget]) {
        func toString(_ with: Double?) -> String {
            guard let double = with else { return "" }
            return String(format: "%.1f", double)
        }
        self.init()
        id = widgetId
        self.widgetId = widgetId
        self.label = label
        self.type = type
        self.icon = icon
        self.url = url ?? ""
        self.period = period ?? ""
        self.minValue = minValue ?? 0.0
        self.maxValue = maxValue ?? 100.0
        self.step = step ?? 1.0
        // Consider a minimal refresh rate of 100 ms, but 0 is special and means 'no refresh'
        if let refreshVal = refresh, refreshVal > 0 {
            self.refresh = max(100, refreshVal)
        } else {
            self.refresh = 0
        }
        self.height = toString(height)
        self.isLeaf = isLeaf ?? false
        self.iconColor = iconColor ?? ""
        labelcolor = labelColor ?? ""
        valuecolor = valueColor ?? ""
        self.service = service ?? ""
        self.state = state ?? ""
        self.text = text ?? ""
        self.legend = legend
        self.encoding = encoding ?? ""
        self.item = item
        self.linkedPage = linkedPage
        self.mappings = mappings
        self.widgets = widgets

        // Sanitize minValue, maxValue and step: min <= max, step >= 0
        self.maxValue = max(self.minValue, self.maxValue)
        self.step = abs(self.step)
    }

    convenience init(xml xmlElement: XMLElement) {
        self.init()
        id = widgetId

        for child in xmlElement.children {
            switch child.tag {
            case "widgetId": widgetId = child.stringValue
            case "label": label = child.stringValue
            case "type": type = child.stringValue
            case "icon": icon = child.stringValue
            case "url": url = child.stringValue
            case "period": period = child.stringValue
            case "iconColor": iconColor = child.stringValue
            case "labelcolor": labelcolor = child.stringValue
            case "valuecolor": valuecolor = child.stringValue
            case "service": service = child.stringValue
            case "state": state = child.stringValue
            case "text": text = child.stringValue
            case "height": height = child.stringValue
            case "encoding": encoding = child.stringValue
            // Double
            case "minValue": minValue = Double(child.stringValue) ?? 0.0
            case "maxValue": maxValue = Double(child.stringValue) ?? 0.0
            case "step": step = Double(child.stringValue) ?? 0.0
            // Bool
            case "isLeaf": isLeaf = child.stringValue == "true" ? true : false
            case "legend": legend = child.stringValue == "true" ? true : false
            // Int
            case "refresh": refresh = Int(child.stringValue) ?? 0
            // Embedded
            case "widget": widgets.append(OpenHABWidget(xml: child))
            case "item": item = OpenHABItem(xml: child)
            case "mapping": mappings.append(OpenHABWidgetMapping(xml: child))
            case "linkedPage": linkedPage = OpenHABLinkedPage(xml: child)
            default:
                break
            }
        }
    }
}

extension OpenHABWidget {
    public struct CodingData: Decodable {
        let widgetId: String
        let label: String
        let type: String
        let icon: String
        let url: String?
        let period: String?
        let minValue: Double?
        let maxValue: Double?
        let step: Double?
        let refresh: Int?
        let height: Double?
        let isLeaf: Bool?
        let iconColor: String?
        let labelcolor: String?
        let valuecolor: String?
        let service: String?
        let state: String?
        let text: String?
        let legend: Bool?
        let encoding: String?
        let groupType: String?
        let item: OpenHABItem.CodingData?
        let linkedPage: OpenHABLinkedPage?
        let mappings: [OpenHABWidgetMapping]
        let widgets: [OpenHABWidget.CodingData]
    }
}

// swiftlint:disable line_length
extension OpenHABWidget.CodingData {
    var openHABWidget: OpenHABWidget {
        let mappedWidgets = widgets.map { $0.openHABWidget }
        return OpenHABWidget(widgetId: widgetId, label: label, icon: icon, type: type, url: url, period: period, minValue: minValue, maxValue: maxValue, step: step, refresh: refresh, height: height, isLeaf: isLeaf, iconColor: iconColor, labelColor: labelcolor, valueColor: valuecolor, service: service, state: state, text: text, legend: legend, encoding: encoding, item: item?.openHABItem, linkedPage: linkedPage, mappings: mappings, widgets: mappedWidgets)
    }
}

//  Recursive parsing of nested widget structure
extension Array where Element == OpenHABWidget {
    mutating func flatten(_ widgets: [Element]) {
        for widget in widgets {
            append(widget)
            flatten(widget.widgets)
        }
    }
}
