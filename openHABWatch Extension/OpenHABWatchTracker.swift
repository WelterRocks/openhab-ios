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
import Network
import OpenHABCoreWatch
import os.log

protocol OpenHABWatchTrackerDelegate: AnyObject {
    func openHABTracked(_ openHABUrl: URL?)
    func openHABTrackingProgress(_ message: String?)
    func openHABTrackingError(_ error: Error)
}

protocol OpenHABWatchTrackerExtendedDelegate: OpenHABWatchTrackerDelegate {
    func openHABTrackingNetworkChange(_ networkStatus: NWPath)
}

class OpenHABWatchTracker: NSObject {
    var oldReachabilityStatus: NWPath?

    weak var delegate: OpenHABWatchTrackerDelegate?
    var netBrowser: NWBrowser?
    var pathMonitor = NWPathMonitor()
    var connectivityTask: DataRequest?

    let backgroundQueue = DispatchQueue.global(qos: .background)

    override init() {
        super.init()
    }

    func start() {
        oldReachabilityStatus = pathMonitor.currentPath
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let nStatus = path
            if nStatus != self.oldReachabilityStatus {
                if let oldReachabilityStatus = self.oldReachabilityStatus {
                    os_log("Network status changed from %{PUBLIC}@ to %{PUBLIC}@", log: OSLog.remoteAccess, type: .info, self.string(from: oldReachabilityStatus) ?? "", self.string(from: nStatus) ?? "")
                }
                self.oldReachabilityStatus = nStatus
                (self.delegate as? OpenHABWatchTrackerExtendedDelegate)?.openHABTrackingNetworkChange(nStatus)
                if self.isNetworkConnected() {
                    self.pathMonitor.cancel()
                    self.selectUrl()
                }
            }
        }
        pathMonitor.start(queue: backgroundQueue)

        selectUrl()
    }

    func start(URL: URL?) {
        trackedUrl(URL)
    }

    func selectUrl() {
        // Check if any network is available
        if isNetworkConnected() {
            // Check if network is WiFi. If not, go for remote URL
            if !isNetworkWiFi() {
                os_log("OpenHABWatchTracker network is not WiFi", log: .default, type: .info)
                trackedRemoteUrl()
                // If it is WiFi
            } else {
                os_log("OpenHABWatchTracker network is Wifi", log: .default, type: .info)
                // Check if local URL is configured
                if ObservableOpenHABDataObject.shared.localUrl.isEmpty {
                    startDiscovery()
                } else {
                    if let connectivityTask = connectivityTask {
                        connectivityTask.cancel()
                    }
                    let request = URLRequest(url: URL(string: ObservableOpenHABDataObject.shared.localUrl)!, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 2.0)
                    connectivityTask = NetworkConnection.shared.manager.request(request)
                        .validate(statusCode: 200 ..< 300)
                        .responseData { response in
                            switch response.result {
                            case .success:
                                self.trackedLocalUrl()
                            case .failure:
                                self.trackedRemoteUrl()
                            }
                        }
                    connectivityTask?.resume()
                }
            }
        } else {
            var errorDetail: [AnyHashable: Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = "Network is not available."
            let trackingError = NSError(domain: "openHAB", code: 100, userInfo: errorDetail as? [String: Any])
            delegate?.openHABTrackingError(trackingError)
        }
    }

    func trackedLocalUrl() {
        delegate?.openHABTrackingProgress("Connecting to local URL")
        let openHABUrl = normalizeUrl(ObservableOpenHABDataObject.shared.localUrl)
        trackedUrl(URL(string: openHABUrl!))
    }

    func trackedRemoteUrl() {
        let openHABUrl = normalizeUrl(ObservableOpenHABDataObject.shared.remoteUrl)
        if (openHABUrl?.count ?? 0) > 0 {
            // delegate?.openHABTrackingProgress("Connecting to remote URL")
            trackedUrl(URL(string: openHABUrl!))
        } else {
            var errorDetail: [AnyHashable: Any] = [:]
            errorDetail[NSLocalizedDescriptionKey] = "Remote URL is not configured."
            let trackingError = NSError(domain: "openHAB", code: 101, userInfo: errorDetail as? [String: Any])
            delegate?.openHABTrackingError(trackingError)
        }
    }

    func trackedDiscoveryUrl(_ discoveryUrl: URL?) {
        delegate?.openHABTrackingProgress("Connecting to discovered URL")
        trackedUrl(discoveryUrl)
    }

    func trackedDemoMode() {
        delegate?.openHABTrackingProgress("Running in demo mode. Check settings to disable demo mode.")
        trackedUrl(URL(staticString: "http://demo.openhab.org:8080"))
    }

    func trackedUrl(_ trackedUrl: URL?) {
        delegate?.openHABTracked(trackedUrl)
    }

    func startDiscovery() {
        os_log("OpenHABTracking starting Bonjour discovery", log: .default, type: .info)

        delegate?.openHABTrackingProgress("Discovering openHAB")
        let parameters = NWParameters()
        netBrowser = NWBrowser(for: .bonjour(type: "_openhab-server-ssl._tcp.", domain: "local."), using: parameters)
        netBrowser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                os_log("OpenHABWatchTracker discovery ready", log: .default, type: .info)
            case let .failed(error):
                os_log("OpenHABWatchTracker discovery failed: %{PUBLIC}@", log: .default, type: .info, error.localizedDescription)
                self.trackedRemoteUrl()
            default:
                break
            }
        }
        netBrowser?.browseResultsChangedHandler = { results, _ in
            guard !results.isEmpty else { return }
            guard let result = results.first else { return }

            switch result.endpoint {
            case let .service(name, type, domain, interface):
                os_log("OpenHABWatchTracker discovered service: name=%{PUBLIC}@ type=%{PUBLIC}@ domain=%{PUBLIC}@", log: OSLog.remoteAccess, type: .info, name, type, domain)
                let params = NWParameters.tcp
                let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: interface)
                let connection = NWConnection(to: endpoint, using: params)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let path = connection.currentPath!
                        switch path.remoteEndpoint {
                        case let .hostPort(host, port):
                            var components = URLComponents()
                            components.scheme = "https"
                            components.port = Int(port.rawValue)
                            switch host {
                            case let .name(name, _):
                                components.host = name
                            case let .ipv4(ipv4):
                                components.host = self.getStringIp(addressFamily: AF_INET, fromAddressData: ipv4.rawValue)
                            case let .ipv6(ipv6):
                                components.host = self.getStringIp(addressFamily: AF_INET6, fromAddressData: ipv6.rawValue)
                            default:
                                components.host = nil
                            }
                            if components.host == nil {
                                os_log("OpenHABWatchTracker unable to build URL from discovered endpoint, using remote URL instead", log: OSLog.remoteAccess, type: .info)
                                self.trackedRemoteUrl()
                            } else {
                                os_log("OpenHABWatchTracker discovered: %{PUBLIC}@ ", log: OSLog.remoteAccess, type: .info, components.url?.description ?? "")
                                self.trackedDiscoveryUrl(components.url)
                            }
                            return
                        default:
                            os_log("OpenHABWatchTracker unhandled endpoint type", log: OSLog.remoteAccess, type: .info)
                            connection.cancel()
                        }
                    case .preparing, .setup, .waiting:
                        break
                    default:
                        // Error establishing the connection or other unknown condition
                        connection.cancel()
                        os_log("OpenHABWatchTracker unable establish connection to discovered endpoint, using remote URL instead", log: OSLog.remoteAccess, type: .info)
                        self.trackedRemoteUrl()
                    }
                }
                self.netBrowser!.cancel()
                connection.start(queue: .main)
                return
            default:
                os_log("OpenHABWatchTracker discovered unhandled endpoint type", log: OSLog.remoteAccess, type: .info)
            }

            self.netBrowser!.cancel()

            // Unable to discover local endpoint
            os_log("OpenHABWatchTracker unable to discover local server, using remote URL", log: OSLog.remoteAccess, type: .info)
            self.trackedRemoteUrl()
        }
        netBrowser?.start(queue: .main)
    }

    func getStringIp(addressFamily: Int32, fromAddressData dataIn: Data?) -> String? {
        let data = dataIn! as NSData
        var sockAddr: in_addr = data.castToCPointer()
        var ipAddressString: [CChar] = Array(repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(addressFamily,
                  &sockAddr,
                  &ipAddressString,
                  socklen_t(INET_ADDRSTRLEN))

        return String(cString: ipAddressString)
    }

    func normalizeUrl(_ url: String?) -> String? {
        if let url = url, url.hasSuffix("/") {
            return String(url.dropLast())
        }
        return url
    }

    func validateUrl(_ url: String?) -> Bool {
        let theURL = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        let urlTest = NSPredicate(format: "SELF MATCHES %@", theURL)
        return urlTest.evaluate(with: url)
    }

    func isNetworkConnected() -> Bool {
        pathMonitor.currentPath.status == .satisfied
    }

    func isNetworkWiFi() -> Bool {
        (pathMonitor.currentPath.status == .satisfied && !pathMonitor.currentPath.isExpensive)
    }

    func string(from path: NWPath) -> String? {
        switch path.status {
        case .unsatisfied, .requiresConnection:
            return "unreachable"
        case .satisfied:
            var str = "reachable:"
            for interface in path.availableInterfaces {
                switch interface.type {
                case .wifi:
                    str += " wifi"
                case .cellular:
                    str += " cellular"
                case .wiredEthernet:
                    str += " wiredEthernet"
                case .loopback:
                    str += " loopback"
                case .other:
                    str += " other"
                default:
                    str += " (unknown)"
                }
            }
            return str
        default:
            return "(unknown)"
        }
    }
}

extension NSData {
    func castToCPointer<T>() -> T {
        let mem = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T.Type>.size)
        getBytes(mem, length: MemoryLayout<T.Type>.size)
        return mem.move()
    }
}
