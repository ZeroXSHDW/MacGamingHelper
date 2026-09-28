import AppKit
import Darwin
import Foundation
import IOKit

/// Live system telemetry for the Gaming Performance Overlay.
/// Never invents FPS for other apps. GPU is best-effort IOKit; may be nil.
@MainActor
final class PerfSampler: ObservableObject {
    static let shared = PerfSampler()

    struct Snapshot: Equatable {
        var cpuPercent: Double?
        var memoryUsedGB: Double?
        var memoryPressurePercent: Double?
        var gpuPercent: Double?
        var gpuAvailable: Bool
        var gpuNote: String
        var pingMs: Double?
        var pingOK: Bool
        var panelHz: Int?
        var frontmostCPU: Double?
        var frontmostName: String
        var sampledAt: Date
    }

    @Published private(set) var snap = Snapshot(
        cpuPercent: nil, memoryUsedGB: nil, memoryPressurePercent: nil,
        gpuPercent: nil, gpuAvailable: false, gpuNote: "unavailable",
        pingMs: nil, pingOK: false, panelHz: nil,
        frontmostCPU: nil, frontmostName: "", sampledAt: .distantPast
    )

    private var timer: Timer?
    private var prevCPU: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var pingTask: Task<Void, Never>?
    private var lastPingAt: Date = .distantPast
    private var pingHostCached = "1.1.1.1"
    private var pingEnabled = true
    private var active = false

    func start(pingHost: String, pingEnabled: Bool) {
        self.pingHostCached = pingHost
        self.pingEnabled = pingEnabled
        active = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    func stop() {
        active = false
        timer?.invalidate()
        timer = nil
        pingTask?.cancel()
        pingTask = nil
    }

    func updatePingConfig(host: String, enabled: Bool) {
        pingHostCached = host
        pingEnabled = enabled
        if !enabled {
            var s = snap
            s.pingMs = nil
            s.pingOK = false
            snap = s
        }
    }

    /// One-shot sample for self-test (does not require overlay visible).
    func sampleOnce() -> Snapshot {
        var s = snap
        s.cpuPercent = Self.readCPU(&prevCPU)
        let mem = Self.readMemory()
        s.memoryUsedGB = mem.usedGB
        s.memoryPressurePercent = mem.pressure
        let gpu = Self.readGPU()
        s.gpuPercent = gpu.percent
        s.gpuAvailable = gpu.available
        s.gpuNote = gpu.note
        s.panelHz = Self.readPanelHz()
        let front = Self.readFrontmostCPU()
        s.frontmostCPU = front.cpu
        s.frontmostName = front.name
        s.sampledAt = Date()
        snap = s
        return s
    }

    private func tick() {
        guard active else { return }
        var s = sampleOnce()
        if pingEnabled {
            // Ping at most every 2s to stay light
            if Date().timeIntervalSince(lastPingAt) >= 2.0 {
                lastPingAt = Date()
                let host = pingHostCached
                pingTask?.cancel()
                pingTask = Task { [weak self] in
                    let ms = await Self.measureLatency(host: host)
                    await MainActor.run {
                        guard let self, self.active, self.pingEnabled else { return }
                        var cur = self.snap
                        if let ms {
                            cur.pingMs = ms
                            cur.pingOK = true
                        } else {
                            cur.pingOK = false
                        }
                        self.snap = cur
                    }
                }
            }
        } else {
            s.pingMs = nil
            s.pingOK = false
            snap = s
        }
    }

    // MARK: - CPU

    private static func readCPU(_ prev: inout (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?) -> Double? {
        var numCPU: natural_t = 0
        var info: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPU,
            &info,
            &numCPUInfo
        )
        guard kr == KERN_SUCCESS, let info else { return nil }
        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        var user: UInt32 = 0, system: UInt32 = 0, idle: UInt32 = 0, nice: UInt32 = 0
        let loadCount = Int(CPU_STATE_MAX)
        for i in 0..<Int(numCPU) {
            let base = i * loadCount
            user += UInt32(info[base + Int(CPU_STATE_USER)])
            system += UInt32(info[base + Int(CPU_STATE_SYSTEM)])
            idle += UInt32(info[base + Int(CPU_STATE_IDLE)])
            nice += UInt32(info[base + Int(CPU_STATE_NICE)])
        }

        defer { prev = (user, system, idle, nice) }
        guard let p = prev else { return nil }
        let dUser = Double(user &- p.user)
        let dSystem = Double(system &- p.system)
        let dIdle = Double(idle &- p.idle)
        let dNice = Double(nice &- p.nice)
        let total = dUser + dSystem + dIdle + dNice
        guard total > 0 else { return nil }
        let busy = (dUser + dSystem + dNice) / total * 100.0
        return min(100, max(0, busy))
    }

    // MARK: - Memory

    private static func readMemory() -> (usedGB: Double?, pressure: Double?) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (nil, nil) }
        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        let usedGB = used / 1_073_741_824.0

        var total: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &size, nil, 0)
        let pressure: Double? = total > 0 ? min(100, used / Double(total) * 100.0) : nil
        return (usedGB, pressure)
    }

    // MARK: - GPU (IOKit PerformanceStatistics — real or unavailable, never faked)

    private static func readGPU() -> (percent: Double?, available: Bool, note: String) {
        guard let matching = IOServiceMatching("IOAccelerator") else {
            return (nil, false, "IOAccelerator matching failed")
        }
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            return (nil, false, "needs permission/unavailable")
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any]
            else { continue }

            if let perf = dict["PerformanceStatistics"] as? [String: Any] {
                if let util = number(perf["Device Utilization %"]) {
                    return (min(100, max(0, util)), true, "IOKit Device Utilization %")
                }
                if let util = number(perf["Renderer Utilization %"]) {
                    return (min(100, max(0, util)), true, "IOKit Renderer Utilization %")
                }
                if let util = number(perf["GPU Busy"]) {
                    return (min(100, max(0, util)), true, "IOKit GPU Busy")
                }
            }
        }
        return (nil, false, "needs permission/unavailable")
    }

    private static func number(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        return nil
    }

    // MARK: - Panel Hz (not game FPS)

    static func readPanelHz() -> Int? {
        guard let screen = NSScreen.main else { return nil }
        let hz = screen.maximumFramesPerSecond
        return hz > 0 ? hz : nil
    }

    // MARK: - Frontmost app CPU (honest “Game CPU” proxy)

    private static func readFrontmostCPU() -> (cpu: Double?, name: String) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return (nil, "")
        }
        let name = app.localizedName ?? app.bundleIdentifier ?? "App"
        let pid = app.processIdentifier
        // Sample via `ps` once — lightweight enough at 1 Hz for overlay.
        // Avoid inventing FPS; this is process CPU % only.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)", "-o", "%cpu="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let v = Double(str) {
                return (min(999, max(0, v)), name)
            }
        } catch {}
        return (nil, name)
    }

    // MARK: - Ping (TCP connect latency — no root)

    static func measureLatency(host: String) async -> Double? {
        let cleaned = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Prefer HTTPS HEAD timing (works for domains); fall back to TCP :443 / :80
        if cleaned.contains(".") && !cleaned.contains("/") {
            if let ms = await httpLatency(host: cleaned) { return ms }
            if let ms = await tcpLatency(host: cleaned, port: 443) { return ms }
            if let ms = await tcpLatency(host: cleaned, port: 80) { return ms }
        }
        return await tcpLatency(host: cleaned, port: 443)
    }

    private static func httpLatency(host: String) async -> Double? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = host
        comps.path = "/"
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 2.5)
        req.httpMethod = "HEAD"
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<500).contains(http.statusCode) else {
                return nil
            }
            return (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        } catch {
            return nil
        }
    }

    private static func tcpLatency(host: String, port: UInt16) async -> Double? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                var result: UnsafeMutablePointer<addrinfo>?
                let portStr = String(port)
                guard getaddrinfo(host, portStr, &hints, &result) == 0, let first = result else {
                    cont.resume(returning: nil)
                    return
                }
                defer { freeaddrinfo(result) }
                let fd = socket(first.pointee.ai_family, first.pointee.ai_socktype, first.pointee.ai_protocol)
                guard fd >= 0 else {
                    cont.resume(returning: nil)
                    return
                }
                defer { close(fd) }
                // Non-blocking connect with short timeout
                let flags = fcntl(fd, F_GETFL, 0)
                _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
                let start = CFAbsoluteTimeGetCurrent()
                let rc = connect(fd, first.pointee.ai_addr, first.pointee.ai_addrlen)
                if rc == 0 {
                    cont.resume(returning: (CFAbsoluteTimeGetCurrent() - start) * 1000.0)
                    return
                }
                if errno != EINPROGRESS {
                    cont.resume(returning: nil)
                    return
                }
                var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                let pr = poll(&pfd, 1, 2500)
                if pr > 0 && (pfd.revents & Int16(POLLOUT)) != 0 {
                    var err: Int32 = 0
                    var len = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len)
                    if err == 0 {
                        cont.resume(returning: (CFAbsoluteTimeGetCurrent() - start) * 1000.0)
                        return
                    }
                }
                cont.resume(returning: nil)
            }
        }
    }
}
