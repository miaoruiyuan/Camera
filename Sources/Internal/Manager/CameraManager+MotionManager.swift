//
//  CameraManager+MotionManager.swift of MijickCamera
//
//  Created by Tomasz Kurylik. Sending ❤️ from Kraków!
//    - Mail: tomasz.kurylik@mijick.com
//    - GitHub: https://github.com/FulcrumOne
//    - Medium: https://medium.com/@mijick
//
//  Copyright ©2024 Mijick. All rights reserved.


import CoreMotion
import AVKit

@MainActor class CameraManagerMotionManager {
    private weak var _parent: CameraManager?
    private var parent: CameraManager? { _parent }
    private(set) var manager: CMMotionManager = .init()
}

// MARK: Setup
extension CameraManagerMotionManager {
    func setup(parent: CameraManager) {
        self._parent = parent
        manager.accelerometerUpdateInterval = 0.05
        manager.startAccelerometerUpdates(to: .current ?? .init()) { [weak self] data, error in
            self?.handleAccelerometerUpdates(data, error)
        }
    }
}
private extension CameraManagerMotionManager {
    func handleAccelerometerUpdates(_ data: CMAccelerometerData?, _ error: Error?) {
        guard let data, error == nil, parent != nil else { return }

        let newDeviceOrientation = getDeviceOrientation(data.acceleration)
        updateDeviceOrientation(newDeviceOrientation)
        updateUserBlockedScreenRotation()
        updateFrameOrientation()
        redrawGrid()
    }
}
private extension CameraManagerMotionManager {
    func getDeviceOrientation(_ acceleration: CMAcceleration) -> AVCaptureVideoOrientation { switch acceleration {
        case let acceleration where acceleration.x >= 0.75: .landscapeLeft
        case let acceleration where acceleration.x <= -0.75: .landscapeRight
        case let acceleration where acceleration.y <= -0.75: .portrait
        case let acceleration where acceleration.y >= 0.75: .portraitUpsideDown
        default: parent?.attributes.deviceOrientation ?? .portrait
    }}
    func updateDeviceOrientation(_ newDeviceOrientation: AVCaptureVideoOrientation) { if let parent, newDeviceOrientation != parent.attributes.deviceOrientation {
        parent.attributes.deviceOrientation = newDeviceOrientation
    }}
    func updateUserBlockedScreenRotation() {
        guard let parent else { return }
        let newUserBlockedScreenRotation = getNewUserBlockedScreenRotation()
        if newUserBlockedScreenRotation != parent.attributes.userBlockedScreenRotation { parent.attributes.userBlockedScreenRotation = newUserBlockedScreenRotation }
    }
    func updateFrameOrientation() { if UIDevice.current.orientation != .portraitUpsideDown {
        guard let parent else { return }
        let newFrameOrientation = getNewFrameOrientation(parent.attributes.orientationLocked ? .portrait : UIDevice.current.orientation)
        updateFrameOrientation(newFrameOrientation)
    }}
    func redrawGrid() { if let parent, !parent.attributes.orientationLocked {
        parent.cameraGridView.draw(.zero)
    }}
}
private extension CameraManagerMotionManager {
    func getNewUserBlockedScreenRotation() -> Bool {
        guard let parent else { return false }
        switch parent.attributes.deviceOrientation.rawValue == UIDevice.current.orientation.rawValue {
        case true: false
        case false: !parent.attributes.orientationLocked
    }}
    func getNewFrameOrientation(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        guard let parent else { return .right }
        switch parent.attributes.cameraPosition {
        case .back: getNewFrameOrientationForBackCamera(orientation)
        case .front: getNewFrameOrientationForFrontCamera(orientation)
    }}
    func updateFrameOrientation(_ newFrameOrientation: CGImagePropertyOrientation) { if let parent, newFrameOrientation != parent.attributes.frameOrientation {
        let shouldAnimate = shouldAnimateFrameOrientationChange(newFrameOrientation)
        updateFrameOrientation(withAnimation: shouldAnimate, newFrameOrientation: newFrameOrientation)
    }}
}
private extension CameraManagerMotionManager {
    func getNewFrameOrientationForBackCamera(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        guard let parent else { return .right }
        switch orientation {
        case .portrait: parent.attributes.mirrorOutput ? .leftMirrored : .right
        case .landscapeLeft: parent.attributes.mirrorOutput ? .upMirrored : .up
        case .landscapeRight: parent.attributes.mirrorOutput ? .downMirrored : .down
        default: parent.attributes.mirrorOutput ? .leftMirrored : .right
    }}
    func getNewFrameOrientationForFrontCamera(_ orientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        guard let parent else { return .leftMirrored }
        switch orientation {
        case .portrait: parent.attributes.mirrorOutput ? .right : .leftMirrored
        case .landscapeLeft: parent.attributes.mirrorOutput ? .down : .downMirrored
        case .landscapeRight: parent.attributes.mirrorOutput ? .up : .upMirrored
        default: parent.attributes.mirrorOutput ? .right : .leftMirrored
    }}
    func shouldAnimateFrameOrientationChange(_ newFrameOrientation: CGImagePropertyOrientation) -> Bool {
        guard let parent else { return false }
        let backCameraOrientations: [CGImagePropertyOrientation] = [.left, .right, .up, .down],
            frontCameraOrientations: [CGImagePropertyOrientation] = [.leftMirrored, .rightMirrored, .upMirrored, .downMirrored]

        return (backCameraOrientations.contains(newFrameOrientation) && backCameraOrientations.contains(parent.attributes.frameOrientation)) ||
        (frontCameraOrientations.contains(parent.attributes.frameOrientation) && frontCameraOrientations.contains(newFrameOrientation))
    }
    func updateFrameOrientation(withAnimation shouldAnimate: Bool, newFrameOrientation: CGImagePropertyOrientation) { Task { [weak self] in
        guard let self, let parent = self.parent else { return }
        await parent.cameraMetalView.beginCameraOrientationAnimation(if: shouldAnimate)
        parent.attributes.frameOrientation = newFrameOrientation
        parent.cameraMetalView.finishCameraOrientationAnimation(if: shouldAnimate)
    }}
}

// MARK: Reset
extension CameraManagerMotionManager {
    func reset() {
        manager.stopAccelerometerUpdates()
        _parent = nil
    }
}
