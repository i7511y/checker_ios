import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var manager = SystemInfoManager()
    @State private var showFileImporter = false
    @State private var showScreenTest = false
    @State private var screenColorIndex = 0
    let testColors: [Color] = [.red, .green, .blue, .white, .black]
    
    var body: some View {
        NavigationView {
            List {
                // قسم التشغيل والبطارية
                Section(header: Text("حالة التشغيل والطاقة")) {
                    InfoRow(title: "موديل الجهاز", value: manager.deviceModel)
                    InfoRow(title: "إصدار النظام", value: manager.osVersion)
                    InfoRow(title: "مدة التشغيل المتواصل", value: manager.uptime)
                    InfoRow(title: "آخر إعادة تشغيل", value: manager.bootDate)
                    InfoRow(title: "نسبة الشحن الحالية", value: "\(manager.batteryLevel)% (\(manager.batteryState))")
                    InfoRow(title: "حرارة المعالج", value: manager.thermalState)
                }
                
                // قسم العتاد والذاكرة
                Section(header: Text("المعالج والذاكرة")) {
                    InfoRow(title: "أنوية المعالج", value: "\(manager.processorCores) أنوية")
                    InfoRow(title: "إجمالي الرام (RAM)", value: manager.totalRAM)
                    InfoRow(title: "استهلاك التطبيق للرام", value: manager.usedRAM)
                    InfoRow(title: "المساحة الكلية", value: manager.totalStorage)
                    InfoRow(title: "المساحة المتاحة", value: manager.freeStorage)
                }
                
                // قسم الفحص العميق عبر ملف Analytics
                Section(header: Text("الفحص العميق (صحة البطارية والأعطال)"),
                        footer: Text("للحصول على صحة البطارية وعدد الدورات: اذهب إلى الإعدادات > الخصوصية والأمن > التحليلات والتحسينات > بيانات التحليلات، واختر أحدث ملف يبدأ بـ Analytics ثم شاركه واحفظه في الملفات وارفعه هنا.")) {
                    
                    InfoRow(title: "صحة البطارية الفعلية", value: manager.analyticsBatteryHealth)
                    InfoRow(title: "دورات الشحن", value: manager.analyticsCycleCount)
                    InfoRow(title: "تاريخ السجل المفحوص", value: manager.analyticsFirstLogDate)
                    
                    ForEach(manager.analyticsIssuesFound, id: \.self) { issue in
                        Text(issue)
                            .font(.footnote)
                            .foregroundColor(issue.contains("✅") ? .green : .orange)
                    }
                    
                    Button(action: { showFileImporter = true }) {
                        Label("استيراد ملف Analytics للفحص", systemImage: "doc.text.magnifyingglass")
                            .foregroundColor(.blue)
                    }
                }
                
                // قسم اختبارات الهاردوير
                Section(header: Text("اختبارات الهاردوير اليدوية")) {
                    Button(action: { manager.triggerVibrationTest() }) {
                        Label("فحص محرك الاهتزاز (Taptic Engine)", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    
                    Button(action: { showScreenTest = true }) {
                        Label("فحص بكسلات الشاشة والألوان", systemImage: "display")
                    }
                }
            }
            .navigationTitle("فاحص الآيفون الشامل")
            .toolbar {
                Button(action: { manager.refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.data, .json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    manager.parseAnalyticsFile(url: url)
                }
            }
            .fullScreenCover(isPresented: $showScreenTest) {
                ZStack {
                    testColors[screenColorIndex]
                        .ignoresSafeArea()
                    VStack {
                        Spacer()
                        Text("المس الشاشة لتغيير اللون • اسحب للأسفل للإغلاق")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .padding(.bottom, 30)
                    }
                }
                .onTapGesture {
                    screenColorIndex = (screenColorIndex + 1) % testColors.count
                }
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}
