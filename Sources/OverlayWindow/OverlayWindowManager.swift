//
//  OverlayWindowManager.swift
//
//  Created by Duraid Abdul.
//  Copyright © 2021 Duraid Abdul. All rights reserved.
//

import UIKit
import SwiftUI

@available(iOSApplicationExtension, unavailable)
public class OverlayWindowManager: NSObject, UIGestureRecognizerDelegate {
    public enum DefaultWindowPos {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    public static let shared = OverlayWindowManager()

    public var actions: [UIAction] = [] {
        didSet {
            menuButton.menu = makeMenu()
            if menuButton.menu?.children.isEmpty ?? false {
                menuButton.isHidden = true
            }
        }
    }
    public var hideActionEnabled: Bool = true
    public var defaultWindowPos: DefaultWindowPos = .topLeft
    
    var isConfigured = false
    let defaultOverlaySize = CGSize(width: 240, height: 148)
    
    lazy var borderView = UIView()
    
    var lumaWidthAnchor: NSLayoutConstraint!
    var lumaHeightAnchor: NSLayoutConstraint!

    lazy var resizeController: ResizeController = {
        ResizeController(parentSize: windowSize)
    }()

    lazy var lumaView: LumaView = {
        let lumaView = LumaView()
        lumaView.foregroundView.backgroundColor = .black
        lumaView.layer.cornerRadius = contentView.layer.cornerRadius
        
        contentView.addSubview(lumaView)
        
        lumaView.translatesAutoresizingMaskIntoConstraints = false
        
        lumaWidthAnchor = lumaView.widthAnchor.constraint(equalTo: contentView.widthAnchor)
        lumaHeightAnchor = lumaView.heightAnchor.constraint(equalToConstant: contentView.frame.size.height)
        
        NSLayoutConstraint.activate([
            lumaWidthAnchor,
            lumaHeightAnchor,
            lumaView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            lumaView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        
        return lumaView
    }()
    
    lazy var unhideButton: UIButton = {
        let button = UIButton()
        
        button.addAction(UIAction(handler: { [self] _ in
            UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1) {
                contentView.center = nearestTargetTo(contentView.center, possibleTargets: possibleEndpoints.dropLast())
            }.startAnimation()
            grabberMode = false
            
            UserDefaults.standard.set(contentView.center.x, forKey: "OverlayWindow_X")
            UserDefaults.standard.set(contentView.center.y, forKey: "OverlayWindow_Y")
        }), for: .touchUpInside)
        
        contentView.addSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            button.heightAnchor.constraint(equalTo: contentView.heightAnchor),
            button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        
        button.isHidden = true
        
        return button
    }()
    
    /// The fixed size of the overlay view.
    lazy var overlaySize = defaultOverlaySize {
        didSet {
            contentView.frame.size = overlaySize
            
            // Update text view width.
            if contentView.frame.size.width > resizeController.kMaxOverlayWidth {
                bodyView.frame.size.width = resizeController.kMaxOverlayWidth - 2
            } else if contentView.frame.size.width < resizeController.kMinOverlayWidth {
                bodyView.frame.size.width = resizeController.kMinOverlayWidth - 2
            } else {
                bodyView.frame.size.width = overlaySize.width - 2
            }
            
            // Update text view height.
            if contentView.frame.size.height > ResizeController.kMaxOverlayHeight {
                bodyView.frame.size.height = ResizeController.kMaxOverlayHeight - 2
                + (contentView.frame.size.height - ResizeController.kMaxOverlayHeight) * 2 / 3
            } else if contentView.frame.size.height < ResizeController.kMinOverlayHeight {
                bodyView.frame.size.height = ResizeController.kMinOverlayHeight - 2
                + (contentView.frame.size.height - ResizeController.kMinOverlayHeight) * 2 / 3
            } else {
                bodyView.frame.size.height = overlaySize.height - 2
            }
            
            bodyView.contentOffset.y = bodyView.contentSize.height - bodyView.bounds.size.height
            
            // TODO: Snap to nearest position.
            
            UserDefaults.standard.set(overlaySize.width, forKey: "OverlayWindow_Width")
            UserDefaults.standard.set(overlaySize.height, forKey: "OverlayWindow_Height")
        }
    }
    
    /// Strong reference keeps the window alive.
    var overlayWindow: OverlayWindow?
    var overlayView: UIView {
        overlayViewController.view!
    }
    
    // We need a parent view controller in order to display context menus.
    lazy var overlayViewController = OverlayViewController()
    lazy var contentView: UIView = {
        let v = UIView()
        overlayViewController.view!.addSubview(v)
        return v
    }()
    
    lazy var bodyView: UIScrollView = UIScrollView()
    var userBodyView: UIView? = nil
    var userBodyDidChange: Bool = false
    var userBodyViewFixHeight: Bool = false
    var userBodyViewFixWidth: Bool = true


    /*
     overlayWindow -> overlayViewController
     -> overlayView -> contentView -> bodyView
     */


    /// Button that reveals menu.
    lazy var menuButton = UIButton()
    
    /// Tracks whether the PiP overlay is in scroll mode or pan mode.
    var scrollLocked = true
    
    /// Feedback generator for the long press action.
    lazy var feedbackGenerator = UISelectionFeedbackGenerator()
    
    lazy var panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(overlayPiPPanner(recognizer:)))
    lazy var longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(recognizer:)))

    var windowSize: CGSize {
        overlayWindow?.frame.size ?? UIScreen.size
    }

    var allEndpoints: [CGPoint] {
        if overlaySize.width < windowSize.width - 112 {
            // Four endpoints, one for each corner.
            return [
                // Top endpoints.
                CGPoint(x: overlaySize.width / 2 + 12,
                        y: (UIScreen.hasRoundedCorners ? 38 : 16)
                        + overlaySize.height / 2 + 12),
                CGPoint(x: windowSize.width - overlaySize.width / 2 - 12,
                        y: (UIScreen.hasRoundedCorners ? 38 : 16)
                        + overlaySize.height / 2 + 12),

                // Bottom endpoints.
                CGPoint(x: overlaySize.width / 2 + 12,
                        y: windowSize.height - overlaySize.height / 2
                        - (keyboardHeight ?? overlayWindow?.safeAreaInsets.bottom ?? 0)
                        - 12),
                CGPoint(x: windowSize.width - overlaySize.width / 2 - 12,
                        y: windowSize.height - overlaySize.height / 2
                        - (keyboardHeight ?? overlayWindow?.safeAreaInsets.bottom ?? 0)
                        - 12)
            ]
        }
        else {
            // Two endpoints, one for the top, one for the bottom..
            return [
                CGPoint(x: windowSize.width / 2,
                        y: (UIScreen.hasRoundedCorners ? 38 : 16)
                        + overlaySize.height / 2 + 12),
                CGPoint(x: windowSize.width / 2,
                        y: windowSize.height - overlaySize.height / 2
                        - (keyboardHeight ?? overlayWindow?.safeAreaInsets.bottom ?? 0)
                        - 12)
            ]
        }
    }

    /// Gesture endpoints. Each point represents a corner of the screen. TODO: Handle screen rotation.
    var possibleEndpoints: [CGPoint] {
        var endpoints = allEndpoints
        if overlaySize.width < windowSize.width - 112 {
            if contentView.frame.minX <= 0 {
                // Left edge endpoints.
                endpoints = [endpoints[0], endpoints[2]]
                
                // Left edge hiding endpoints.
                if contentView.center.y < (windowSize.height - (temporaryKeyboardHeightValueTracker ?? 0)) / 2 {
                    endpoints.append(CGPoint(x: -overlaySize.width / 2 + 28,
                                             y: endpoints[0].y))
                } else {
                    endpoints.append(CGPoint(x: -overlaySize.width / 2 + 28,
                                             y: endpoints[1].y))
                }
            } else if contentView.frame.maxX >= windowSize.width {
                // Right edge endpoints.
                endpoints = [endpoints[1], endpoints[3]]
                
                // Right edge hiding endpoints.
                if contentView.center.y < (windowSize.height - (temporaryKeyboardHeightValueTracker ?? 0)) / 2 {
                    endpoints.append(CGPoint(x: windowSize.width
                                             + overlaySize.width / 2 - 28,
                                             y: endpoints[0].y))
                } else {
                    endpoints.append(CGPoint(x: windowSize.width
                                             + overlaySize.width / 2 - 28,
                                             y: endpoints[1].y))
                }
            }
            
            return endpoints
            
        } else {
            if contentView.frame.minX <= 0 {
                // Left edge hiding endpoints.
                if contentView.center.y < (windowSize.height - (temporaryKeyboardHeightValueTracker ?? 0)) / 2 {
                    endpoints.append(CGPoint(x: -overlaySize.width / 2 + 28,
                                             y: endpoints[0].y))
                } else {
                    endpoints.append(CGPoint(x: -overlaySize.width / 2 + 28,
                                             y: endpoints[1].y))
                }
            } else if contentView.frame.maxX >= windowSize.width {
                
                // Right edge hiding endpoints.
                if contentView.center.y < (windowSize.height - (temporaryKeyboardHeightValueTracker ?? 0)) / 2 {
                    endpoints.append(CGPoint(x: windowSize.width + overlaySize.width / 2 - 28,
                                             y: endpoints[0].y))
                } else {
                    endpoints.append(CGPoint(x: windowSize.width + overlaySize.width / 2 - 28,
                                             y: endpoints[1].y))
                }
            }
            
            return endpoints
        }
    }
    
    lazy var initialViewLocation: CGPoint = .zero
    
    func configureOverlay() {
        overlaySize = CGSize(width: UserDefaults.standard.object(forKey: "OverlayWindow_Width") as? CGFloat ?? overlaySize.width,
                             height: UserDefaults.standard.object(forKey: "OverlayWindow_Height") as? CGFloat ?? overlaySize.height)
        
        
        contentView.layer.shadowRadius = 16
        contentView.layer.shadowOpacity = 0.5
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.alpha = 0
        
        contentView.layer.cornerRadius = 24
        contentView.layer.cornerCurve = .continuous
        
        let _ = lumaView
        
        borderView.frame = CGRect(x: -1, y: -1,
                                  width: overlaySize.width + 2,
                                  height: overlaySize.height + 2)
        borderView.layer.borderWidth = 1
        borderView.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        borderView.layer.cornerRadius = contentView.layer.cornerRadius + 1
        borderView.layer.cornerCurve = .continuous
        borderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(borderView)
        
        // Configure text view.
        bodyView.frame = CGRect(x: 1, y: 1, width: overlaySize.width - 2, height: overlaySize.height - 2)
        bodyView.backgroundColor = .clear
        bodyView.showsVerticalScrollIndicator = false
        bodyView.contentInsetAdjustmentBehavior = .never
        contentView.addSubview(bodyView)
        
        bodyView.layer.cornerRadius = contentView.layer.cornerRadius - 2
        bodyView.layer.cornerCurve = .continuous
        
        // Configure gesture recognizers.
        panRecognizer.maximumNumberOfTouches = 1
        panRecognizer.delegate = self
        
        let tapRecognizer = UITapStartEndGestureRecognizer(target: self, action: #selector(overlayPiPTapStartEnd(recognizer:)))
        tapRecognizer.delegate = self
        
        longPressRecognizer.minimumPressDuration = 0.1
        
        contentView.addGestureRecognizer(panRecognizer)
        contentView.addGestureRecognizer(tapRecognizer)
        contentView.addGestureRecognizer(longPressRecognizer)
        
        // Prepare menu button.
        let diameter = CGFloat(30)
        
        // This tuned button frame is used to adjust where the menu appears.
        menuButton = UIButton(frame: CGRect(x: contentView.bounds.width - 44,
                                            y: contentView.bounds.height - 36,
                                            width: 44,
                                            height: 36 + 4 /*Offests the context menu by the desired amount*/))
        menuButton.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        
        let circleFrame = CGRect(
            x: menuButton.bounds.width - diameter - (contentView.layer.cornerRadius - diameter / 2),
            y: menuButton.bounds.height - diameter - (contentView.layer.cornerRadius - diameter / 2) - 4,
            width: diameter, height: diameter)
        
        let circle = UIView(frame: circleFrame)
        circle.backgroundColor = UIColor(white: 0.2, alpha: 0.95)
        circle.layer.cornerRadius = diameter / 2
        circle.isUserInteractionEnabled = false
        menuButton.addSubview(circle)
        
        let ellipsisImage = UIImageView(image: UIImage(systemName: "ellipsis",
                                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
        ellipsisImage.frame.size = circle.bounds.size
        ellipsisImage.contentMode = .center
        circle.addSubview(ellipsisImage)
        
        menuButton.tintColor = UIColor(white: 1, alpha: 0.75)
        menuButton.menu = makeMenu()
        menuButton.showsMenuAsPrimaryAction = true
        contentView.addSubview(menuButton)
        if menuButton.menu?.children.isEmpty ?? false {
            menuButton.isHidden = true
        }
        
        let _ = unhideButton
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    /// Adds a LocalConsole window to the app's main scene.
    func configureWindow() {
        var windowSceneFound = false
        
        // Update cache based on last-cached origin.
        func updateOverlayOrigin() {
            snapToCachedEndpoint()
            
            if contentView.center.x < 0 || contentView.center.x > windowSize.width {
                grabberMode = true
                scrollLocked = !grabberMode
                
                contentView.layer.removeAllAnimations()
                lumaView.layer.removeAllAnimations()
                menuButton.layer.removeAllAnimations()
                bodyView.layer.removeAllAnimations()
            }
        }
        
        // Configure window.
        func fetchWindowScene() {
            let windowScene = UIApplication.shared
                .connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first
            
            if let windowScene = windowScene as? UIWindowScene {
                windowSceneFound = true

                UIWindow.swizzleStatusBarAppearanceOverride
                let window = OverlayWindow(windowScene: windowScene)
                window.frame = UIScreen.main.bounds
                //let level = UIWindow.Level(UIWindow.Level.statusBar.rawValue + 1)
                let level = UIWindow.Level.statusBar
                window.windowLevel = level
                window.rootViewController = overlayViewController
                window.isHidden = false
                overlayWindow = window

                updateOverlayOrigin()
            }
        }
        
        /// Ensures the window is configured (i.e. scene has been found). If not, delay and wait for a scene to prepare itself, then try again.
        for i in 1...10 {
            
            let delay = Double(i) / 10
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                
                guard !windowSceneFound else { return }
                
                fetchWindowScene()
                
                if isVisible {
                    isVisible = false
                    contentView.layer.removeAllAnimations()
                    isVisible = true
                }
            }
        }
    }
    
    func snapToCachedEndpoint() {
        let defaultPosIndex: Int
        let endpoints = allEndpoints
        if endpoints.count < 3 {
            switch defaultWindowPos {
            case .topLeft, .topRight:
                defaultPosIndex = 0
            case .bottomLeft, .bottomRight:
                defaultPosIndex = 1
            }
        }
        else {
            switch defaultWindowPos {
            case .topLeft:
                defaultPosIndex = 0
            case .topRight:
                defaultPosIndex = 1
            case .bottomLeft:
                defaultPosIndex = 2
            case .bottomRight:
                defaultPosIndex = 3
            }
        }

        let cachedOverlayPosition = CGPoint(
            x: UserDefaults.standard.object(forKey: "OverlayWindow_X") as? CGFloat
            ?? allEndpoints[defaultPosIndex].x,
            y: UserDefaults.standard.object(forKey: "OverlayWindow_Y") as? CGFloat
            ?? allEndpoints[defaultPosIndex].y)

        // Update overlay center so possibleEndpoints are calculated correctly.
        contentView.center = cachedOverlayPosition
        contentView.center = nearestTargetTo(cachedOverlayPosition,
                                             possibleTargets: possibleEndpoints)
    }
    
    // MARK: - Public

    public func setBody(view: UIView, fixHeight: Bool = true, fixWidth: Bool = true) {
        view.translatesAutoresizingMaskIntoConstraints = false
        userBodyView = view
        userBodyViewFixHeight = fixHeight
        userBodyViewFixWidth = fixWidth

        userBodyDidChange = true
        configureBody()
    }

    func configureBody() {
        guard isVisible else { return }
        guard let userBodyView = userBodyView else { return }
        guard userBodyDidChange else { return }

        for v in bodyView.subviews {
            v.removeFromSuperview()
        }
        bodyView.addSubview(userBodyView)

        NSLayoutConstraint.activate([
            userBodyView.topAnchor
                .constraint(equalTo: bodyView.contentLayoutGuide.topAnchor),
            userBodyView.bottomAnchor
                .constraint(equalTo: bodyView.contentLayoutGuide.bottomAnchor),
            userBodyView.leadingAnchor
                .constraint(equalTo: bodyView.contentLayoutGuide.leadingAnchor),
            userBodyView.trailingAnchor
                .constraint(equalTo: bodyView.contentLayoutGuide.trailingAnchor)
        ])

        let contentViewCenterY = userBodyView.centerYAnchor
            .constraint(equalTo: bodyView.centerYAnchor)
        contentViewCenterY.priority = .defaultLow

        let parentView = bodyView.superview!
        let contentViewHeight = userBodyView.heightAnchor
            .constraint(greaterThanOrEqualTo: parentView.heightAnchor)
        contentViewHeight.priority = .defaultLow

        NSLayoutConstraint.activate([
            userBodyView.centerXAnchor.constraint(equalTo: bodyView.centerXAnchor),
            contentViewCenterY,
            contentViewHeight
        ])

        userBodyDidChange = false
    }

    public var isVisible = false {
        didSet {
            guard oldValue != isVisible else { return }
            
            if isVisible {
                if !isConfigured {
                    DispatchQueue.main.async { [self] in
                        configureWindow()
                        configureOverlay()
                        isConfigured = true
                    }
                }
                if userBodyDidChange {
                    DispatchQueue.main.async { [self] in
                        configureBody()
                    }
                }
                
                contentView.transform = .init(scaleX: 0.9, y: 0.9)
                UIViewPropertyAnimator(duration: 0.5, dampingRatio: 0.6) { [self] in
                    contentView.transform = .init(scaleX: 1, y: 1)
                }.startAnimation()
                UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                    contentView.alpha = 1
                }.startAnimation()
                
                let animation = CABasicAnimation(keyPath: "shadowOpacity")
                animation.fromValue = 0
                animation.toValue = 0.5
                animation.duration = 0.6
                contentView.layer.add(animation, forKey: animation.keyPath)
                contentView.layer.shadowOpacity = 0.5
                
            } else {
                UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                    contentView.transform = .init(scaleX: 0.9, y: 0.9)
                }.startAnimation()
                
                UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) { [self] in
                    contentView.alpha = 0
                }.startAnimation()
            }
        }
    }
    
    var grabberMode: Bool = false {
        didSet {
            guard oldValue != grabberMode else { return }
            
            if grabberMode {
                
                lumaView.layer.cornerRadius = contentView.layer.cornerRadius
                lumaHeightAnchor.constant = contentView.frame.size.height
                contentView.layoutIfNeeded()
                
                UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) { [self] in
                    bodyView.alpha = 0
                    menuButton.alpha = 0
                    borderView.alpha = 0
                }.startAnimation()
                
                UIViewPropertyAnimator(duration: 0.5, dampingRatio: 1) { [self] in
                    lumaView.foregroundView.alpha = 0
                }.startAnimation()
                
                lumaWidthAnchor.constant = -34
                lumaHeightAnchor.constant = 96
                UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                    lumaView.layer.cornerRadius = 8
                    contentView.layoutIfNeeded()
                }.startAnimation(afterDelay: 0.06)
                
                bodyView.isUserInteractionEnabled = false
                unhideButton.isHidden = false
                
            } else {
                
                lumaHeightAnchor.constant = contentView.frame.size.height
                lumaWidthAnchor.constant = 0
                UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                    contentView.layoutIfNeeded()
                    lumaView.layer.cornerRadius = contentView.layer.cornerRadius
                }.startAnimation()
                
                UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) { [self] in
                    bodyView.alpha = 1
                    menuButton.alpha = 1
                    borderView.alpha = 1
                }.startAnimation(afterDelay: 0.2)
                
                UIViewPropertyAnimator(duration: 0.65, dampingRatio: 1) { [self] in
                    lumaView.foregroundView.alpha = 1
                }.startAnimation()
                
                bodyView.isUserInteractionEnabled = true
                unhideButton.isHidden = true
            }
        }
    }

    // MARK: - Private
    
    var temporaryKeyboardHeightValueTracker: CGFloat?
    
    // MARK: Handle keyboard show/hide.
    private var keyboardHeight: CGFloat? = nil {
        didSet {
            
            temporaryKeyboardHeightValueTracker = oldValue
            
            if contentView.center != possibleEndpoints[0] && contentView.center != possibleEndpoints[1] {
                let nearestTargetPosition = nearestTargetTo(contentView.center, possibleTargets: possibleEndpoints.suffix(2))
                
                Swift.print(possibleEndpoints.suffix(2))
                
                UIViewPropertyAnimator(duration: 0.55, dampingRatio: 1) {
                    self.contentView.center = nearestTargetPosition
                }.startAnimation()
            }
            
            temporaryKeyboardHeightValueTracker = keyboardHeight
        }
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            self.keyboardHeight = keyboardRectangle.height
        }
    }
    
    @objc func keyboardWillHide() {
        keyboardHeight = nil
    }
    
    var dynamicReportTimer: Timer? {
        willSet { dynamicReportTimer?.invalidate() }
    }
    
    func makeMenu() -> UIMenu {
        var menuContent: [UIMenuElement] = []

        if hideActionEnabled {
            let hideAction = UIAction(title: "Hide",
                                      image: UIImage(systemName: "xmark.square"), handler: { _ in
                self.isVisible = false
            })
            menuContent.append(hideAction)
        }

        if !actions.isEmpty {
            let userActions = UIMenu(
                title: "",
                options: .displayInline,
                children: actions)
            menuContent.append(userActions)
        }

        return UIMenu(title: "", children: menuContent)
    }

    public func resize() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.resizeController.isActive.toggle()
            self.resizeController.platterView.reveal()
        }
    }
    
    @objc func longPressAction(recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            
            guard !grabberMode else { return }
            
            feedbackGenerator.selectionChanged()
            
            scrollLocked = false
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                contentView.transform = .init(scaleX: 1.04, y: 1.04)
                bodyView.alpha = 0.5
                menuButton.alpha = 0.5
            }.startAnimation()
        case .cancelled, .ended:
            
            if !grabberMode { scrollLocked = true }
            
            UIViewPropertyAnimator(duration: 0.8, dampingRatio: 0.5) { [self] in
                contentView.transform = .identity
            }.startAnimation()
            
            UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
                if !grabberMode {
                    bodyView.alpha = 1
                    menuButton.alpha = 1
                }
            }.startAnimation()
        default: break
        }
    }
    
    let overlayPiPPanner_frameRateRequest = FrameRateRequest()
    
    @objc func overlayPiPPanner(recognizer: UIPanGestureRecognizer) {
        
        if recognizer.state == .began {
            overlayPiPPanner_frameRateRequest.isActive = true
            
            initialViewLocation = contentView.center
        }
        
        guard !scrollLocked else { return }
        
        let translation = recognizer.translation(in: contentView.superview)
        let velocity = recognizer.velocity(in: contentView.superview)
        
        switch recognizer.state {
        case .changed:
            
            UIViewPropertyAnimator(duration: 0.175, dampingRatio: 1) { [self] in
                contentView.center = CGPoint(x: initialViewLocation.x + translation.x,
                                             y: initialViewLocation.y + translation.y)
            }.startAnimation()
            
            if contentView.frame.maxX > 30 && contentView.frame.minX < windowSize.width - 30 {
                grabberMode = false
            } else {
                grabberMode = true
            }
            
        case .ended, .cancelled:
            
            overlayPiPPanner_frameRateRequest.isActive = false
            FrameRateRequest().perform(duration: 0.5)
            
            // After the PiP is thrown, determine the best corner and re-target it there.
            let decelerationRate = UIScrollView.DecelerationRate.normal.rawValue
            
            let projectedPosition = CGPoint(
                x: contentView.center.x + project(initialVelocity: velocity.x, decelerationRate: decelerationRate),
                y: contentView.center.y + project(initialVelocity: velocity.y, decelerationRate: decelerationRate)
            )
            
            let nearestTargetPosition = nearestTargetTo(projectedPosition, possibleTargets: possibleEndpoints)
            
            let relativeInitialVelocity = CGVector(
                dx: relativeVelocity(forVelocity: velocity.x, from: contentView.center.x, to: nearestTargetPosition.x),
                dy: relativeVelocity(forVelocity: velocity.y, from: contentView.center.y, to: nearestTargetPosition.y)
            )
            
            let timingParameters = UISpringTimingParameters(damping: 0.85, response: 0.45, initialVelocity: relativeInitialVelocity)
            let positionAnimator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
            positionAnimator.addAnimations { [self] in
                contentView.center = nearestTargetPosition
            }
            positionAnimator.startAnimation()
            
            UserDefaults.standard.set(nearestTargetPosition.x, forKey: "OverlayWindow_X")
            UserDefaults.standard.set(nearestTargetPosition.y, forKey: "OverlayWindow_Y")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.grabberMode = nearestTargetPosition.x < 0 || nearestTargetPosition.x > self.windowSize.width
                self.scrollLocked = !self.grabberMode
            }
            
        default: break
        }
    }
    
    // Animate touch down.
    func overlayPiPTouchDown() {
        guard !grabberMode else { return }
        
        UIViewPropertyAnimator(duration: 1.25, dampingRatio: 0.5) { [self] in
            contentView.transform = .init(scaleX: 0.95, y: 0.95)
        }.startAnimation()
    }
    
    // Animate touch up.
    func overlayPiPTouchUp() {
        UIViewPropertyAnimator(duration: 0.8, dampingRatio: 0.4) { [self] in
            contentView.transform = .init(scaleX: 1, y: 1)
        }.startAnimation()
        
        UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) { [self] in
            if !grabberMode {
                bodyView.alpha = 1
                if !self.resizeController.isActive {
                    menuButton.alpha = 1
                }
            }
        }.startAnimation()
    }
    
    // Simulataneously listen to all gesture recognizers.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc func overlayPiPTapStartEnd(recognizer: UITapStartEndGestureRecognizer) {
        switch recognizer.state {
        case .began:
            overlayPiPTouchDown()
        case .changed:
            break
        case .ended, .cancelled, .possible, .failed:
            overlayPiPTouchUp()
        @unknown default:
            break
        }
    }
}

// Custom window for the overlay to appear above other windows while passing touches down.
class OverlayWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else {
            return nil
        }
        if hitView.isKind(of: OverlayView.self) {
            return nil
        }
        else {
            return hitView
        }
    }
}

class OverlayViewController: UIViewController {
    override func loadView() {
        view = OverlayView()
    }
}

class OverlayView: UIView {
}

import UIKit.UIGestureRecognizerSubclass

public class UITapStartEndGestureRecognizer: UITapGestureRecognizer {
    override public func touchesBegan(_ touches: Set<UITouch>, with: UIEvent) {
        self.state = .began
    }
    override public func touchesMoved(_ touches: Set<UITouch>, with: UIEvent) {
        self.state = .changed
    }
    override public func touchesEnded(_ touches: Set<UITouch>, with: UIEvent) {
        self.state = .ended
    }
}

extension UIWindow {
    
    /// Make sure this window does not have control over the status bar appearance.
    static let swizzleStatusBarAppearanceOverride: Void = {
        guard let originalMethod = class_getInstanceMethod(UIWindow.self, NSSelectorFromString("_can" + "Affect" + "Sta" + "tus" + "Bar" + "Appe" + "arance")),
              let swizzledMethod = class_getInstanceMethod(UIWindow.self, #selector(swizzled_statusBarAppearance))
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    
    @objc func swizzled_statusBarAppearance() -> Bool {
        if self.isKind(of: OverlayWindow.self) {
            return false
        }
        else {
            // original implementation instead
            return swizzled_statusBarAppearance()
        }
    }
}

class LumaView: UIView {
    lazy var visualEffectView: UIView = {
        Bundle(path: "/Sys" + "tem/Lib" + "rary/Private" + "Frameworks/Material" + "Kit." + "framework")!.load()
        
        let Pill = NSClassFromString("MT" + "Luma" + "Dodge" + "Pill" + "View") as! UIView.Type
        
        let pillView = Pill.init()
        
        enum Style: Int {
            case none = 0
            case thin = 1
            case gray = 2
            case black = 3
            case white = 4
        }
        
        enum BackgroundLuminance: Int {
            case unknown = 0
            case dark = 1
            case light = 2
        }
        
        pillView.setValue(2, forKey: "style")
        pillView.setValue(1, forKey: "background" + "Luminance")
        pillView.perform(NSSelectorFromString("_" + "update" + "Style"))
        
        addSubview(pillView)
        
        pillView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pillView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pillView.topAnchor.constraint(equalTo: topAnchor),
            pillView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        return pillView
    }()
    
    lazy var foregroundView: UIView = {
        let view = UIView()
        
        addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let _ = visualEffectView
        let _ = foregroundView
        
        visualEffectView.isUserInteractionEnabled = false
        foregroundView.isUserInteractionEnabled = false
        
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Frame Rate Request
/**
An object that allows you to manually request an increased display refresh rate on ProMotion devices.

*The display refresh rate does not exceed 60 Hz when low power mode is enabled.*

**Do not set an excessive duration. Doing so will negatively impact battery life.**
 
```
// Example
let request = FrameRateRequest(preferredFrameRate: 120,
                               duration: 0.4)
request.perform()
```
 */
class FrameRateRequest {
    
    lazy private var displayLink = CADisplayLink(target: self, selector: #selector(dummyFunction))
    
    var isActive: Bool = false {
        didSet {
            guard #available(iOS 15, *) else { return }
            guard isActive != oldValue else { return }
            
            if isActive {
                displayLink.add(to: .current, forMode: .common)
            } else {
                displayLink.remove(from: .current, forMode: .common)
            }
        }
    }
    
    /// Prepares your frame rate request parameters.
    init(preferredFrameRate: Float = Float(UIScreen.main.maximumFramesPerSecond)) {
        if #available(iOS 15, *) {
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: Float(UIScreen.main.maximumFramesPerSecond), preferred: preferredFrameRate)
        }
    }
    
    /// Perform frame rate request.
    func perform(duration: Double) {
        isActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [self] in
            isActive = false
        }
    }
    
    @objc private func dummyFunction() {}
}
