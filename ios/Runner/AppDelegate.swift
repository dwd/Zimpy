import Flutter
import UIKit
import dnssd

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "zimpy/dns"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "resolveSrv" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let args = call.arguments as? [String: Any],
              let name = args["name"] as? String,
              !name.isEmpty else {
          result([])
          return
        }
        self?.resolveSrv(name: name, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func resolveSrv(name: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .utility).async {
      var records = [[String: Any]]()
      var serviceRef: DNSServiceRef?
      let semaphore = DispatchSemaphore(value: 0)
      var finished = false

      let callback: DNSServiceQueryRecordReply = { _, flags, _, errorCode, _, rrtype, _, rdlen, rdata, _, _ in
        if errorCode == kDNSServiceErr_NoError && rrtype == kDNSServiceType_SRV,
           let data = rdata {
          if let record = Self.parseSrvRecord(rdata: data, length: Int(rdlen)) {
            records.append(record)
          }
        }
        if flags & kDNSServiceFlagsMoreComing == 0 {
          finished = true
        }
        semaphore.signal()
      }

      let error = DNSServiceQueryRecord(&serviceRef, 0, 0, name, UInt16(kDNSServiceType_SRV), UInt16(kDNSServiceClass_IN), callback, nil)
      if error == kDNSServiceErr_NoError, let ref = serviceRef {
        let timeout = DispatchTime.now() + .seconds(3)
        while !finished {
          DNSServiceProcessResult(ref)
          _ = semaphore.wait(timeout: timeout)
          if DispatchTime.now() >= timeout {
            break
          }
        }
        DNSServiceRefDeallocate(ref)
      }

      DispatchQueue.main.async {
        result(records)
      }
    }
  }

  private static func parseSrvRecord(rdata: UnsafeRawPointer, length: Int) -> [String: Any]? {
    if length < 7 {
      return nil
    }
    let bytes = rdata.bindMemory(to: UInt8.self, capacity: length)
    let priority = Int(bytes[0]) << 8 | Int(bytes[1])
    let weight = Int(bytes[2]) << 8 | Int(bytes[3])
    let port = Int(bytes[4]) << 8 | Int(bytes[5])
    var offset = 6
    var labels = [String]()
    while offset < length {
      let labelLength = Int(bytes[offset])
      if labelLength == 0 {
        break
      }
      let start = offset + 1
      let end = start + labelLength
      if end > length {
        break
      }
      let labelBytes = Array(UnsafeBufferPointer(start: bytes + start, count: labelLength))
      labels.append(String(bytes: labelBytes, encoding: .utf8) ?? "")
      offset = end
    }
    let host = labels.joined(separator: ".")
    if host.isEmpty {
      return nil
    }
    return [
      "host": host,
      "port": port,
      "priority": priority,
      "weight": weight
    ]
  }
}
