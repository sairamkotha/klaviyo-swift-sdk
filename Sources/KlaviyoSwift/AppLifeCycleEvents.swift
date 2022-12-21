//
//  AppLifeCycleEvents.swift
//  
//
//  Created by Noah Durell on 12/13/22.
//

import Foundation
import Combine
import UIKit

enum LifeCycleErrors: Error {
    case invalidReachaibilityStatus
}

struct AppLifeCycleEvents {
    var lifeCycleEvents: () -> any Publisher<KlaviyoAction, Never> = {
        let terminated = environment
            .notificationCenterPublisher(UIApplication.willTerminateNotification)
            .handleEvents(receiveOutput: { _ in
                environment.stopReachability()
            })
            .map { _ in return KlaviyoAction.stop }
        let foregrounded =  environment
            .notificationCenterPublisher(UIApplication.didBecomeActiveNotification)
            .handleEvents(receiveOutput: { _ in
                do {
                    try environment.startReachability()
                } catch {
                    runtimeWarn("failure to start reachability notifier")
                }
            })
            .map { _ in KlaviyoAction.start }
        let backgrounded = environment
            .notificationCenterPublisher(UIApplication.didEnterBackgroundNotification)
            .handleEvents(receiveOutput: { _ in
                environment.stopReachability()
            })
            .map { _ in KlaviyoAction.stop }
        // The below is a bit convoluted since network status can be nil.
        let reachability = environment
            .notificationCenterPublisher(ReachabilityChangedNotification)
            .compactMap { notification -> KlaviyoAction? in
                guard let status = environment.reachabilityStatus() else {
                    return nil
                }
                return KlaviyoAction.networkConnectivityChanged(status)
            }
            .eraseToAnyPublisher()
            
        return terminated
            .merge(with: reachability)
            .merge(with: foregrounded, backgrounded)
            .handleEvents(receiveSubscription: { _ in
                do {
                    try environment.startReachability()
                } catch {
                    runtimeWarn("failure to start reachability notifier")
                }
            })
            .receive(on: RunLoop.main)
    }
    
    static let production = Self()
}
