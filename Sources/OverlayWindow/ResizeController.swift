//
//  ResizeController.swift
//
//  Created by Duraid Abdul.
//  Copyright © 2021 Duraid Abdul. All rights reserved.
//

import UIKit

@available(iOSApplicationExtension, unavailable)
class ResizeController {
    var parentSize: CGSize
    init(parentSize: CGSize) {
        self.parentSize = parentSize
    }
    
    lazy var platterView: PlatterView = PlatterView(frame: CGRect(origin: CGPoint.zero, size: self.parentSize), resizeController: self)

    lazy var overlayCenterPoint = CGPoint(x: (parentSize.width / 2).rounded(),
                                          y: (parentSize.height / 2).rounded()
                                            + (UIScreen.hasRoundedCorners ? 0 : 24))
    
    lazy var overlayOutlineView: UIView = {
        
        let overlayViewReference = OverlayWindowManager.shared.overlayView
        
        let view = UIView()
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.systemGreen.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).cgColor
        view.layer.cornerRadius = overlayViewReference.layer.cornerRadius + 6
        view.layer.cornerCurve = .continuous
        view.alpha = 0
        
        overlayViewReference.addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: overlayViewReference.leadingAnchor, constant: -6),
            view.trailingAnchor.constraint(equalTo: overlayViewReference.trailingAnchor, constant: 6),
            view.topAnchor.constraint(equalTo: overlayViewReference.topAnchor, constant: -6),
            view.bottomAnchor.constraint(equalTo: overlayViewReference.bottomAnchor, constant: 6)
        ])
        
        return view
    }()
    
    lazy var bottomGrabberPillView = UIView()
    
    lazy var bottomGrabber: UIView = {
        let view = UIView()
        OverlayWindowManager.shared.contentView.addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 116),
            view.heightAnchor.constraint(equalToConstant: 46),
            view.centerXAnchor.constraint(equalTo: overlayOutlineView.centerXAnchor),
            view.topAnchor.constraint(equalTo: overlayOutlineView.bottomAnchor, constant: -18)
        ])
        
        bottomGrabberPillView.frame = CGRect(x: 58 - 18, y: 25, width: 36, height: 5)
        bottomGrabberPillView.backgroundColor = UIColor.label
        bottomGrabberPillView.alpha = 0.3
        bottomGrabberPillView.layer.cornerRadius = 2.5
        bottomGrabberPillView.layer.cornerCurve = .continuous
        view.addSubview(bottomGrabberPillView)
        
        let verticalPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(verticalPanner(recognizer:)))
        verticalPanGestureRecognizer.maximumNumberOfTouches = 1
        view.addGestureRecognizer(verticalPanGestureRecognizer)
        
        view.alpha = 0
        
        return view
    }()
    
    lazy var rightGrabberPillView = UIView()
    
    lazy var rightGrabber: UIView = {
        let view = UIView()
        OverlayWindowManager.shared.contentView.addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 46),
            view.heightAnchor.constraint(equalToConstant: 116),
            view.centerYAnchor.constraint(equalTo: overlayOutlineView.centerYAnchor),
            view.leftAnchor.constraint(equalTo: overlayOutlineView.rightAnchor, constant: -18)
        ])
        
        rightGrabberPillView.frame = CGRect(x: 25, y: 58 - 18, width: 5, height: 36)
        rightGrabberPillView.backgroundColor = UIColor.label
        rightGrabberPillView.alpha = 0.3
        rightGrabberPillView.layer.cornerRadius = 2.5
        rightGrabberPillView.layer.cornerCurve = .continuous
        view.addSubview(rightGrabberPillView)
        
        let horizontalPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(horizontalPanner(recognizer:)))
        horizontalPanGestureRecognizer.maximumNumberOfTouches = 1
        view.addGestureRecognizer(horizontalPanGestureRecognizer)
        
        view.alpha = 0
        
        return view
    }()
    
    var isActive: Bool = false {
        didSet {
            guard isActive != oldValue else { return }
            
            // Initialize views outside of animation.
            _ = platterView
            _ = overlayOutlineView
            _ = bottomGrabber
            _ = rightGrabber
            
            // Ensure initial autolayout is performed unanimated.
            OverlayWindowManager.shared.overlayWindow?.layoutIfNeeded()
            
            FrameRateRequest().perform(duration: 1.5)
            
            if isActive {
                
                UIViewPropertyAnimator(duration: 0.75, dampingRatio: 1) {
                    
                    let textView = OverlayWindowManager.shared.bodyView
                    
                    textView.contentOffset.y = textView.contentSize.height - textView.bounds.size.height
                }.startAnimation()
                
                
                if OverlayWindowManager.shared.overlayView.traitCollection.userInterfaceStyle == .light {
                    OverlayWindowManager.shared.overlayView.layer.shadowOpacity = 0.25
                }
                
                // Ensure background color animates in right the first time.
                OverlayWindowManager.shared.contentView.backgroundColor = .clear
                
                UIViewPropertyAnimator(duration: 0.6, dampingRatio: 1) {
                    OverlayWindowManager.shared.overlayView.center = self.overlayCenterPoint
                    
                    // Update grabbers (layout constraints)
                    OverlayWindowManager.shared.overlayWindow?.layoutIfNeeded()
                    
                    OverlayWindowManager.shared.menuButton.alpha = 0
                    
                    OverlayWindowManager.shared.contentView.backgroundColor = UIColor(dynamicProvider: { traitCollection in
                        UIColor(white: 0, alpha: traitCollection.userInterfaceStyle == .light ? 0.1 : 0.3)
                    })
                }.startAnimation()
                
                UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                    overlayOutlineView.alpha = 1
                }.startAnimation(afterDelay: 0.3)
                
                bottomGrabber.transform = .init(translationX: 0, y: -5)
                rightGrabber.transform = .init(translationX: -5, y: 0)
                
                UIViewPropertyAnimator(duration: 1, dampingRatio: 1) { [self] in
                    bottomGrabber.alpha = 1
                    rightGrabber.alpha = 1
                    
                    bottomGrabber.transform = .identity
                    rightGrabber.transform = .identity
                }.startAnimation(afterDelay: 0.3)
                
                OverlayWindowManager.shared.panRecognizer.isEnabled = false
                OverlayWindowManager.shared.longPressRecognizer.isEnabled = false
                
                // Activate full screen button.
                overlayOutlineView.isUserInteractionEnabled = true
            } else {
                
                OverlayWindowManager.shared.overlayView.layer.shadowOpacity = 0.5
                
                UIViewPropertyAnimator(duration: 0.6, dampingRatio: 1) {
                    OverlayWindowManager.shared.snapToCachedEndpoint()
                    
                    // Update grabbers (layout constraints)
                    OverlayWindowManager.shared.overlayWindow?.layoutIfNeeded()
                    
                    OverlayWindowManager.shared.menuButton.alpha = 1
                    
                    OverlayWindowManager.shared.contentView.backgroundColor = .clear
                }.startAnimation()
                
                UIViewPropertyAnimator(duration: 0.2, dampingRatio: 1) { [self] in
                    overlayOutlineView.alpha = 0
                    
                    bottomGrabber.alpha = 0
                    rightGrabber.alpha = 0
                }.startAnimation()
                
                OverlayWindowManager.shared.panRecognizer.isEnabled = true
                OverlayWindowManager.shared.longPressRecognizer.isEnabled = true
                
                // Deactivate full screen button.
                overlayOutlineView.isUserInteractionEnabled = false
            }
        }
    }
    
    var initialHeight = CGFloat.zero
    
    static let kMinOverlayHeight: CGFloat = 108
    static let kMaxOverlayHeight: CGFloat = 346
    
    let verticalPanner_frameRateRequest = FrameRateRequest()
    
    @objc func verticalPanner(recognizer: UIPanGestureRecognizer) {
        
        let translation = recognizer.translation(in: bottomGrabber.superview)
        
        let minHeight = Self.kMinOverlayHeight
        let maxHeight = Self.kMaxOverlayHeight
        
        switch recognizer.state {
        case .began:
            verticalPanner_frameRateRequest.isActive = true
            
            initialHeight = OverlayWindowManager.shared.overlaySize.height
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                bottomGrabberPillView.alpha = 0.6
            }.startAnimation()
            
        case .changed:
            
            let resolvedHeight: CGFloat = {
                let initialEstimate = initialHeight + 2 * translation.y
                if initialEstimate <= maxHeight && initialEstimate > minHeight {
                    return initialEstimate
                } else if initialEstimate > maxHeight {
                    
                    var excess = initialEstimate - maxHeight
                    excess = 25 * log(1/25 * excess + 1)
                    
                    return maxHeight + excess
                } else {
                    var excess = minHeight - initialEstimate
                    excess = 7 * log(1/7 * excess + 1)
                    
                    return minHeight - excess
                }
            }()
            
            OverlayWindowManager.shared.lumaHeightAnchor.constant = resolvedHeight
            OverlayWindowManager.shared.overlaySize.height = resolvedHeight
            OverlayWindowManager.shared.overlayView.center.y = overlayCenterPoint.y
            
        case .ended, .cancelled:
            verticalPanner_frameRateRequest.isActive = false
            
            FrameRateRequest().perform(duration: 0.4)
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 0.7) {
                if OverlayWindowManager.shared.overlaySize.height > maxHeight {
                    OverlayWindowManager.shared.overlaySize.height = maxHeight
                    OverlayWindowManager.shared.lumaHeightAnchor.constant = maxHeight
                }
                if OverlayWindowManager.shared.overlaySize.height < minHeight {
                    OverlayWindowManager.shared.overlaySize.height = minHeight
                    OverlayWindowManager.shared.lumaHeightAnchor.constant = minHeight
                }
                
                OverlayWindowManager.shared.overlayView.center.y = self.overlayCenterPoint.y
                
                // Animate autolayout updates.
                OverlayWindowManager.shared.overlayWindow?.layoutIfNeeded()
            }.startAnimation()
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                bottomGrabberPillView.alpha = 0.3
            }.startAnimation()
            
        default: break
        }
    }
    
    var initialWidth = CGFloat.zero
    
    var kMinOverlayWidth: CGFloat = 112
    var kMaxOverlayWidth: CGFloat {
        parentSize.width - 56
    }
    
    let horizontalPanner_frameRateRequest = FrameRateRequest()
    
    @objc func horizontalPanner(recognizer: UIPanGestureRecognizer) {
        
        let translation = recognizer.translation(in: bottomGrabber.superview)
        
        let minWidth = kMinOverlayWidth
        let maxWidth = kMaxOverlayWidth
        
        switch recognizer.state {
        case .began:
            horizontalPanner_frameRateRequest.isActive = true
            
            initialWidth = OverlayWindowManager.shared.overlaySize.width
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                rightGrabberPillView.alpha = 0.6
            }.startAnimation()
            
        case .changed:
            
            let resolvedWidth: CGFloat = {
                let initialEstimate = initialWidth + 2 * translation.x
                if initialEstimate <= maxWidth && initialEstimate > minWidth {
                    return initialEstimate
                } else if initialEstimate > maxWidth {
                    
                    var excess = initialEstimate - maxWidth
                    excess = 25 * log(1/25 * excess + 1)
                    
                    return maxWidth + excess
                } else {
                    var excess = minWidth - initialEstimate
                    excess = 7 * log(1/7 * excess + 1)
                    
                    return minWidth - excess
                }
            }()
            
            OverlayWindowManager.shared.overlaySize.width = resolvedWidth
            OverlayWindowManager.shared.overlayView.center.x = (parentSize.width * 1/2).rounded()
            
        case .ended, .cancelled:
            
            horizontalPanner_frameRateRequest.isActive = false
            
            FrameRateRequest().perform(duration: 0.4)
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 0.7) {
                if OverlayWindowManager.shared.overlaySize.width > maxWidth {
                    OverlayWindowManager.shared.overlaySize.width = maxWidth
                }
                if OverlayWindowManager.shared.overlaySize.width < minWidth {
                    OverlayWindowManager.shared.overlaySize.width = minWidth
                }
                
                OverlayWindowManager.shared.overlayView.center.x = (self.parentSize.width * 1/2).rounded()
                
                // Animate autolayout updates.
                OverlayWindowManager.shared.overlayWindow?.layoutIfNeeded()
            }.startAnimation()
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                rightGrabberPillView.alpha = 0.3
            }.startAnimation()
            
        default: break
        }
    }
}

@available(iOSApplicationExtension, unavailable)
class PlatterView: UIView {
    weak var resizeController: ResizeController?
    private let parentSize: CGSize

    init(frame: CGRect, resizeController: ResizeController) {
        parentSize = frame.size
        self.resizeController = resizeController

        super.init(frame: frame)

        // Make sure bottom doesn't show on upwards pan.
        self.frame.size.height += 50
        self.frame.origin = possibleEndpoints[1]
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        layer.shadowRadius = 10
        layer.shadowOpacity = 0.125
        layer.shadowOffset = CGSize(width: 0, height: 0)
        
        layer.borderColor = dynamicBorderColor.cgColor
        layer.borderWidth = 1 / UIScreen.main.scale
        layer.cornerRadius = 30
        layer.cornerCurve = .continuous
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        
        blurView.layer.cornerRadius = 30
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        
        blurView.frame = bounds
        
        addSubview(blurView)
        
        OverlayWindowManager.shared.contentView.addSubview(self)
        OverlayWindowManager.shared.contentView.sendSubviewToBack(self)
        
        _ = backgroundButton
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(platterPanner(recognizer:)))
        panRecognizer.maximumNumberOfTouches = 1
        addGestureRecognizer(panRecognizer)
        
        let grabber = UIView()
        grabber.frame.size = CGSize(width: 36, height: 5)
        grabber.frame.origin.y = 10
        grabber.center.x = bounds.width / 2
        grabber.backgroundColor = .label
        grabber.alpha = 0.1
        grabber.layer.cornerRadius = 2.5
        grabber.layer.cornerCurve = .continuous
        addSubview(grabber)
        
        let titleLabel = UILabel()
        titleLabel.text = "Resize"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.sizeToFit()
        titleLabel.center.x = bounds.width / 2
        titleLabel.frame.origin.y = 28
        titleLabel.roundOriginToPixel()
        addSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Use the grabbers to resize"
        subtitleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        subtitleLabel.sizeToFit()
        subtitleLabel.alpha = 0.5
        subtitleLabel.center.x = bounds.width / 2
        subtitleLabel.frame.origin.y = titleLabel.frame.maxY + 8
        subtitleLabel.roundOriginToPixel()
        addSubview(subtitleLabel)
        
        addSubview(resetButton)
        resetButton.center = CGPoint(x: parentSize.width / 2 - 74,
                                     y: parentSize.height - possibleEndpoints[0].y * 2)
        resetButton.roundOriginToPixel()
        
        addSubview(doneButton)
        doneButton.center = CGPoint(x: parentSize.width / 2 + 74,
                                    y: parentSize.height - possibleEndpoints[0].y * 2)
        doneButton.roundOriginToPixel()
    }
    
    lazy var backgroundButton: UIButton = {
        let backgroundButton = UIButton(primaryAction: UIAction(handler: { _ in
            self.resizeController?.isActive = false
            self.dismiss()
        }))
        backgroundButton.frame.size = CGSize(width: self.frame.size.width, height: possibleEndpoints[0].y + 30)
        OverlayWindowManager.shared.contentView.addSubview(backgroundButton)
        OverlayWindowManager.shared.contentView.sendSubviewToBack(backgroundButton)
        return backgroundButton
    }()
    
    lazy var doneButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.systemBlue.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        button.setTitle("Done", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.frame.size = CGSize(width: 116, height: 52)
        button.layer.cornerRadius = 20
        button.layer.cornerCurve = .continuous
        
        button.addAction(UIAction(handler: { _ in
            self.resizeController?.isActive = false
            self.dismiss()
        }), for: .touchUpInside)
        
        button.addActions(highlightAction: UIAction(handler: { _ in
            UIViewPropertyAnimator(duration: 0.25, dampingRatio: 1) {
                button.alpha = 0.6
            }.startAnimation()
        }), unhighlightAction: UIAction(handler: { _ in
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) {
                button.alpha = 1
            }.startAnimation()
        }))
        
        return button
    }()
    
    lazy var resetButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(white: 1, alpha: 0.125)
            } else {
                return UIColor(white: 0, alpha: 0.1)
            }
        })
        
        button.setTitle("Reset", for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.frame.size = CGSize(width: 116, height: 52)
        button.layer.cornerRadius = 20
        button.layer.cornerCurve = .continuous
        
        button.addAction(UIAction(handler: { _ in
            
            // Resolves a text view frame animation bug that occurs when *decreasing* text view width.
            if OverlayWindowManager.shared.overlaySize.width > OverlayWindowManager.shared.defaultOverlaySize.width {
                OverlayWindowManager.shared.bodyView.frame.size.width = OverlayWindowManager.shared.defaultOverlaySize.width - 4
            }
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) {
                OverlayWindowManager.shared.overlaySize = OverlayWindowManager.shared.defaultOverlaySize
                OverlayWindowManager.shared.lumaHeightAnchor.constant = OverlayWindowManager.shared.defaultOverlaySize.height
                OverlayWindowManager.shared.overlayView.center = self.resizeController?.overlayCenterPoint ?? CGPoint.zero
                OverlayWindowManager.shared.overlayWindow?.layoutIfNeeded()
            }.startAnimation()
            
        }), for: .touchUpInside)
        
        button.addActions(highlightAction: UIAction(handler: { _ in
            UIViewPropertyAnimator(duration: 0.25, dampingRatio: 1) {
                button.alpha = 0.6
            }.startAnimation()
        }), unhighlightAction: UIAction(handler: { _ in
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) {
                button.alpha = 1
            }.startAnimation()
        }))
        
        return button
    }()
    
    func reveal() {
        UIViewPropertyAnimator(duration: 0.6, dampingRatio: 1) {
            self.frame.origin = self.possibleEndpoints[0]
        }.startAnimation()
        
        backgroundButton.isHidden = false
    }
    
    func dismiss() {
        UIViewPropertyAnimator(duration: 0.6, dampingRatio: 1) {
            self.frame.origin = self.possibleEndpoints[1]
        }.startAnimation()
        
        backgroundButton.isHidden = true
    }
    
    let dynamicBorderColor = UIColor(dynamicProvider: { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(white: 1, alpha: 0.075)
        } else {
            return UIColor(white: 0, alpha: 0.125)
        }
    })
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        layer.borderColor = dynamicBorderColor.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var possibleEndpoints = [CGPoint(x: 0, y: (UIScreen.hasRoundedCorners ? 44 : -8) + 63), CGPoint(x: 0, y: parentSize.height + 5)]
    
    var initialPlatterOriginY = CGFloat.zero
    
    @objc func platterPanner(recognizer: UIPanGestureRecognizer) {
        
        let translation = recognizer.translation(in: superview)
        let velocity = recognizer.velocity(in: superview)
        
        switch recognizer.state {
        case .began:
            initialPlatterOriginY = frame.origin.y
        case .changed:
            
            let resolvedOriginY: CGFloat = {
                let initialEstimate = initialPlatterOriginY + translation.y
                if initialEstimate >= possibleEndpoints[0].y {
                    
                    // Stick buttons to bottom.
                    [doneButton, resetButton,
                     resizeController?.bottomGrabber, resizeController?.rightGrabber,
                     OverlayWindowManager.shared.overlayView
                    ].compactMap { $0 }.forEach {
                        $0.transform = .identity
                    }
                    
                    return initialEstimate
                } else {
                    var excess = possibleEndpoints[0].y - initialEstimate
                    excess = 10 * log(1/10 * excess + 1)
                    
                    // Stick buttons to bottom.
                    doneButton.transform = .init(translationX: 0, y: excess)
                    resetButton.transform = .init(translationX: 0, y: excess)
                    
                    resizeController?.bottomGrabber.transform = .init(translationX: 0, y: -excess / 2.5)
                    resizeController?.rightGrabber.transform = .init(translationX: 0, y: -excess / 2)
                    OverlayWindowManager.shared.overlayView.transform = .init(translationX: 0, y: -excess / 2)
                    
                    return possibleEndpoints[0].y - excess
                }
            }()
            
            if frame.origin.y > possibleEndpoints[0].y + 40 {
                resizeController?.isActive = false
            } else {
                resizeController?.isActive = true
            }
            
            frame.origin.y = resolvedOriginY
            
        case .ended, .cancelled:
            
            // After the PiP is thrown, determine the best corner and re-target it there.
            let decelerationRate = UIScrollView.DecelerationRate.normal.rawValue
            
            let projectedPosition = CGPoint(
                x: 0,
                y: frame.origin.y + project(initialVelocity: velocity.y, decelerationRate: decelerationRate)
            )
            
            let nearestTargetPosition = nearestTargetTo(projectedPosition, possibleTargets: possibleEndpoints)
            
            let relativeInitialVelocity = CGVector(
                dx: 0,
                dy: frame.origin.y >= possibleEndpoints[0].y
                    ? relativeVelocity(forVelocity: velocity.y, from: frame.origin.y, to: nearestTargetPosition.y)
                    : 0
            )
            
            let timingParameters = UISpringTimingParameters(damping: 1, response: 0.4, initialVelocity: relativeInitialVelocity)
            let positionAnimator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
            positionAnimator.addAnimations { [self] in
                frame.origin = nearestTargetPosition
                
                [doneButton, resetButton,
                 resizeController?.bottomGrabber, resizeController?.rightGrabber,
                 OverlayWindowManager.shared.overlayView
                ].compactMap { $0 }.forEach {
                    $0.transform = .identity
                }
            }
            positionAnimator.startAnimation()
            
            if nearestTargetPosition == possibleEndpoints[1] {
                resizeController?.isActive = false
                backgroundButton.isHidden = true
            } else {
                resizeController?.isActive = true
            }
            
        default: break
        }
    }
}
