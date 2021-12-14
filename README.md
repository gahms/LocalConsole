# **OverlayWindow**

This Swift Package makes PiP-style window that can display any UIView.

This package was created as a fork of https://github.com/duraidabdul/LocalConsole.

I have removed a lot from LocalConsole and added support for landscape device 
orientation.

I have added a way to supply your own UIView for the content of the window.

I have added a way to supply your own `UIAction`s as menu items.

## **Setup**

1. In your Xcode project, navigate to File > Swift Packages > Add Package Dependancy...

2. Paste the following into the URL field: https://github.com/gahms/OverlayWIndow

3. Once the package dependancy has been added, import LocalConsole and create an easily accessible global instance of ```OverlayWindowManager.shared```.
```swift
import OverlayWindow

let overlayManager = OverlayWindowManager.shared
```

## **Usage**
Once prepared, the overlayManager can be used throughout your project.
```swift

// Activate the overlay view.
overlayManager.isVisible = true

// Deactivate the overlay view.
overlayManager.isVisible = false

// Set default position
overlayManager.defaultWindowPos = .bottomLeft

// Remove the "Hide" action from menu
overlayManager.hideActionEnabled = false

// Create our own "hide" functionality
let hideAction = UIAction(
    title: "Hide",
    image: UIImage(systemName: "arrow.left.and.right.square"), handler: { [self] _ in
        overlayManager.isVisible = false
    })
overlayManager.actions = [hideAction]

// Add our own view as body of the overlay
let label = UILabel()
label.text = "Hello World"
overlayManager.setBody(view: label)
```
