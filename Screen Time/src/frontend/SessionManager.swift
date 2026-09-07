import Foundation
import Combine

class SessionManager: ObservableObject {
    @Published var isSessionActive: Bool = false
    @Published var timeRemaining: Int = 0
    
    @Published var isShowingAlert: Bool = false
    @Published var alertMessage: String = ""
    
    // Timer for UI updates (Main Queue)
    private var uiTimer: Timer?
    
    // Background timer for low-level C execution
    private var monitoringTimer: DispatchSourceTimer?
    private let monitoringQueue = DispatchQueue(label: "com.screentime.monitoring", qos: .userInitiated)

    func startSession(hoursStr: String, minutesStr: String, secondsStr: String, allowedApps: [AppItem],
                      onError: @escaping (_ title: String, _ message: String) -> Void)
    {
        let h = Int(hoursStr) ?? 0
        let m = Int(minutesStr) ?? 0
        let s = Int(secondsStr) ?? 0
        let totalSeconds = (h * 3600) + (m * 60) + s
        
        guard totalSeconds > 0 else { return }
        
        let pathStrings = allowedApps.map { $0.bundlePath }
        
        monitoringQueue.async { [weak self] in
            guard let self = self else {return}
            let ret = self.withCArrayOfStrings(pathStrings) { cPathsArray in
                start_blocking_session(Int32(totalSeconds), cPathsArray, Int32(pathStrings.count))
            }
            
            if ret != 0 {
                DispatchQueue.main.async {
                    onError("Session Error", "List of allowed apps is empty")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.timeRemaining = totalSeconds
                self.isSessionActive = true
                self.startBackgroundMonitoring(paths: pathStrings)
                
                self.uiTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if self.timeRemaining > 0 {
                        self.timeRemaining -= 1
                    } else {
                        self.stopSession()
                    }
                }
            }
        }
    }

    func stopSession() {
        // Stop UI Timer
        uiTimer?.invalidate()
        uiTimer = nil
        
        // Stop C Background Monitoring Timer
        monitoringTimer?.cancel()
        monitoringTimer = nil
        
        monitoringQueue.async {
            stop_blocking_session()
        }
        
        isSessionActive = false
    }

    // MARK: - Idiomatic C Polling Bridge
    private func startBackgroundMonitoring(paths: [String]) {
        let timer = DispatchSource.makeTimerSource(queue: monitoringQueue)
        
        // Poll every 1.0 second (adjust frequency as needed)
        timer.schedule(deadline: .now(), repeating: 1.0)
        
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // Bridge [String] to `const char **` safely on each tick
            self.withCArrayOfStrings(paths) { cPathsArray in
                check_and_enforce_rules(cPathsArray, Int32(paths.count))
            }
        }
        
        monitoringTimer = timer
        timer.resume()
    }

    // MARK: - String Array Helper
    private func withCArrayOfStrings<R>(_ strings: [String], _ body: (UnsafeMutablePointer<UnsafePointer<CChar>?>) -> R) -> R {
        let cStrings = strings.map { strdup($0) }
        defer {
            for ptr in cStrings {
                free(ptr)
            }
        }
        
        var constPtrs = cStrings.map { UnsafePointer($0) }
        return constPtrs.withUnsafeMutableBufferPointer { buffer in
            body(buffer.baseAddress!)
        }
    }
}
