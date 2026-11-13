import Foundation
import UIKit
import CoreHaptics

class SystemInfoManager: ObservableObject {
    @Published var deviceModel: String = ""
    @Published var osVersion: String = ""
    @Published var uptime: String = ""
    @Published var bootDate: String = ""
    @Published var batteryLevel: Int = 0
    @Published var batteryState: String = ""
    @Published var totalStorage: String = ""
    @Published var freeStorage: String = ""
    @Published var totalRAM: String = ""
    @Published var usedRAM: String = ""
    @Published var processorCores: Int = 0
    @Published var thermalState: String = ""
    
    // نتائج تحليل ملف التحليلات (Analytics)
    @Published var analyticsBatteryHealth: String = "غير مفحوص (ارفع ملف التحليلات)"
    @Published var analyticsCycleCount: String = "غير معروف"
    @Published var analyticsFirstLogDate: String = "غير معروف"
    @Published var analyticsIssuesFound: [String] = []
    
    init() {
        refreshData()
    }
    
    func refreshData() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // معلومات النظام والموديل
        deviceModel = getModelIdentifier()
        osVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        processorCores = ProcessInfo.processInfo.processorCount
        
        // مدة التشغيل ووقت آخر إقلاع
        let uptimeSeconds = ProcessInfo.processInfo.systemUptime
        uptime = formatUptime(uptimeSeconds)
        let bootTime = Date().addingTimeInterval(-uptimeSeconds)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd - hh:mm a"
        bootDate = formatter.string(from: bootTime)
        
        // البطارية الحالية
        let level = UIDevice.current.batteryLevel
        batteryLevel = level >= 0 ? Int(level * 100) : 100
        switch UIDevice.current.batteryState {
        case .charging: batteryState = "قيد الشحن ⚡"
        case .full: batteryState = "ممتلئة 🔋"
        case .unplugged: batteryState = "غير متصل بالشاحن"
        default: batteryState = "غير معروف"
        }
        
        // حالة الحرارة
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = "طبيعية (ممتازة) ❄️"
        case .fair: thermalState = "دافئة قليلاً"
        case .serious: thermalState = "مرتفعة ⚠️"
        case .critical: thermalState = "حرجة جداً 🔥"
        @unknown default: thermalState = "غير معروف"
        }
        
        // الذاكرة العشوائية RAM
        let totalMem = ProcessInfo.processInfo.physicalMemory
        totalRAM = ByteCountFormatter.string(fromByteCount: Int64(totalMem), countStyle: .memory)
        usedRAM = getUsedMemory()
        
        // المساحة التخزينية
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let total = attrs[.systemSize] as? Int64,
           let free = attrs[.systemFreeSize] as? Int64 {
            totalStorage = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            freeStorage = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
        }
    }
    
    // قراءة وتحليل ملف Analytics-xxxx.ips أو .json
    func parseAnalyticsFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            var issues: [String] = []
            
            // استخراج دورات الشحن
            if let cycleMatch = extractRegex(pattern: "\"com\\.apple\\.ioreport\\.BatteryCycleCount\"\\s*:\\s*(\\d+)", from: content) ??
                                extractRegex(pattern: "\"CycleCount\"\\s*:\\s*(\\d+)", from: content) {
                analyticsCycleCount = "\(cycleMatch) دورة شحن"
            }
            
            // استخراج السعة القصوى للبطارية (صحة البطارية)
            if let healthMatch = extractRegex(pattern: "\"MaximumCapacityPercent\"\\s*:\\s*(\\d+)", from: content) ??
                                 extractRegex(pattern: "\"NominalChargeCapacity\"\\s*:\\s*(\\d+)", from: content) {
                if let val = Int(healthMatch), val <= 100 {
                    analyticsBatteryHealth = "\(val)%"
                } else {
                    analyticsBatteryHealth = "\(healthMatch) mAh (سعة فعلية)"
                }
            }
            
            // استخراج تاريخ السجل
            if let dateMatch = extractRegex(pattern: "\"timestamp\"\\s*:\\s*\"([^\"]+)\"", from: content) {
                analyticsFirstLogDate = String(dateMatch.prefix(10))
            }
            
            // البحث عن مؤشرات الأعطال في الملف
            if content.contains("panic") || content.contains("Panic") {
                issues.append("⚠️ تم رصد سجل إعادة تشغيل مفاجئة (Kernel Panic)")
            }
            if content.contains("Thermal") && content.contains("mitigation") {
                issues.append("🌡️ تم رصد سجل ارتفاع حرارة أثر على الأداء")
            }
            if content.contains("JetsamEvent") {
                issues.append("🧠 إغلاق تطبيقات بسبب امتلاء الذاكرة العشوائية (RAM)")
            }
            
            if issues.isEmpty {
                issues.append("✅ السجل سليم ولم يتم رصد أعطال حرجة")
            }
            analyticsIssuesFound = issues
            
        } catch {
            analyticsIssuesFound = ["❌ تعذر قراءة الملف: \(error.localizedDescription)"]
        }
    }
    
    private func extractRegex(pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
    
    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(days) يوم، \(hours) ساعة، \(minutes) دقيقة"
    }
    
    private func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "iPhone"
            }
        }
    }
    
    private func getUsedMemory() -> String {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return ByteCountFormatter.string(fromByteCount: Int64(taskInfo.resident_size), countStyle: .memory)
        }
        return "غير متاح"
    }
    
    func triggerVibrationTest() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
