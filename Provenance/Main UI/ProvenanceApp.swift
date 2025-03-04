import SwiftUI
import Foundation
import PVLogging
import PVSwiftUI
import PVFeatureFlags
#if canImport(FreemiumKit)
import FreemiumKit
#endif

@main
struct ProvenanceApp: App {
    @StateObject private var appState = AppState.shared
    @UIApplicationDelegateAdaptor(PVAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView(appDelegate: appDelegate)
                .environmentObject(appState)
                .environmentObject(featureFlags)
                .task {
                    try? await featureFlags.loadConfiguration(
                        from: URL(string: "https://data.provenance-emu.com/features/features.json")!
                    )
                }
            #if canImport(FreemiumKit)
                .environmentObject(FreemiumKit.shared)
            #endif
                .onAppear {
                    ILOG("ProvenanceApp: onAppear called, setting `appDelegate.appState = appState`")
                    appDelegate.appState = appState

                    // Initialize the settings factory and import presenter
                    #if os(tvOS)
                    appState.settingsFactory = SwiftUISettingsViewControllerFactory()
                    appState.importOptionsPresenter = SwiftUIImportOptionsPresenter()
                    #endif

            #if canImport(FreemiumKit)
                #if targetEnvironment(simulator) || DEBUG
                    FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
                #else
                    if !appDelegate.isAppStore {
                        FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
                    }
                #endif
            #endif
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                appState.startBootupSequence()

                /// Swizzle sendEvent(UIEvent)
                if !appState.sendEventWasSwizzled {
                    UIApplication.swizzleSendEvent()
                    appState.sendEventWasSwizzled = true
                }
            }
        }
    }
}

/// Hack to get touches send to RetroArch

extension UIApplication {

    /// Swap implipmentations of sendEvent() while
    /// maintaing a reference back to the original
    @objc static func swizzleSendEvent() {
            let originalSelector = #selector(UIApplication.sendEvent(_:))
            let swizzledSelector = #selector(UIApplication.pv_sendEvent(_:))
            let orginalStoreSelector = #selector(UIApplication.originalSendEvent(_:))
            guard let originalMethod = class_getInstanceMethod(self, originalSelector),
                let swizzledMethod = class_getInstanceMethod(self, swizzledSelector),
                  let orginalStoreMethod = class_getInstanceMethod(self, orginalStoreSelector)
            else { return }
            method_exchangeImplementations(originalMethod, orginalStoreMethod)
            method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /// Placeholder for storing original selector
    @objc func originalSendEvent(_ event: UIEvent) { }

    /// The sendEvent that will be called
    @objc func pv_sendEvent(_ event: UIEvent) {
//        print("Handling touch event: \(event.type.rawValue ?? -1)")
        if let core = AppState.shared.emulationState.core {
            core.sendEvent(event)
        }

        originalSendEvent(event)
    }
}
