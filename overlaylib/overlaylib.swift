import Foundation
import AppKit
import Cocoa

class OverlayView: NSView
{
	var borderColor: NSColor
	var borderWidth: CGFloat
	var cornerRadius: CGFloat

	init(frame: NSRect, borderColor: NSColor, borderWidth: CGFloat, cornerRadius: CGFloat)
	{
		self.borderColor = borderColor
		self.borderWidth = borderWidth
		self.cornerRadius = cornerRadius

		super.init(frame: frame)
	}

	required init?(coder: NSCoder)
	{
		fatalError("init(coder:) has not been implemented")
	}

	override func draw(_ rect: NSRect)
	{
		let bpath:NSBezierPath = NSBezierPath(roundedRect: borderRect, xRadius:cornerRadius, yRadius:cornerRadius)

		borderColor.set()
		bpath.lineWidth = borderWidth
		bpath.stroke()
	}

	var borderRect: NSRect {
		return bounds.insetBy(dx: borderWidth/2, dy: borderWidth/2)
	}
}

class OverlayWindow
{
	private let window: NSWindow
	private let overlayView: OverlayView

	private var _borderColor: NSColor
	private var _borderWidth: CGFloat
	private var _cornerRadius: CGFloat
	private var _nodeFrame = NSRect(x:0,y:0,width:0,height:0)

	init(frame: NSRect, borderColor: NSColor, borderWidth: CGFloat, cornerRadius: CGFloat)
	{
		_nodeFrame = frame
		_borderColor = borderColor
		_borderWidth = borderWidth
		_cornerRadius = cornerRadius

		window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: true)
		window.isOpaque = false
		window.backgroundColor = NSColor.clear
		window.ignoresMouseEvents = true
		window.level = Int(CGWindowLevelForKey(.floatingWindow))
		window.hasShadow = false
		window.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]
		window.isReleasedWhenClosed = false

		overlayView = OverlayView(frame: window.contentView!.bounds, borderColor: borderColor, borderWidth: borderWidth, cornerRadius: cornerRadius)
		overlayView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
		window.contentView!.addSubview(overlayView)

		updateFrame()
		window.makeKeyAndOrderFront(nil)

	}

	func hide()
		{ window.close() }

	var grownFrame: NSRect
		{ return nodeFrame.insetBy(dx: -self.borderWidth, dy: -self.borderWidth) }

	func updateFrame()
	{
		window.setFrame(grownFrame, display: true)
		overlayView.needsDisplay = true
	}

	func showWindow()
	{
		window.makeKeyAndOrderFront(nil)
	}

	var nodeFrame: NSRect
	{
		get { return _nodeFrame }
		set(newFrame) { self._nodeFrame = newFrame }
	}

	var borderColor: NSColor
	{
		get { return _borderColor }
		set(newBorderColor) {
			_borderColor = newBorderColor
			self.overlayView.borderColor = newBorderColor
		}
	}

	var borderWidth: CGFloat
	{
		get { return _borderWidth }
		set(newBorderWidth)
		{
			_borderWidth = newBorderWidth
			self.overlayView.borderWidth = newBorderWidth
		}
	}

	var cornerRadius: CGFloat {
		get { return _cornerRadius }
		set(newRadius) {
			_cornerRadius = newRadius
			self.overlayView.cornerRadius = newRadius
		}
	}
}


class OverlayController: NSObject, NSApplicationDelegate
{
	private var borders: [UInt32: OverlayWindow] = [:]
	private var lastIndex: UInt32 = 0

	func createBorder(frame: NSRect, borderColor: NSColor, borderWidth: CGFloat, cornerRadius: CGFloat)  -> UInt32
	{
		let windowIndex = lastIndex

		DispatchQueue.main.async
		{
			let newWindow = OverlayWindow(
				frame: frame,
				borderColor: borderColor,
				borderWidth: borderWidth,
				cornerRadius: cornerRadius
			)
			self.borders[windowIndex] = newWindow
		}

		lastIndex += 1
		return windowIndex
	}

	func updateBorderFrame(id borderId: UInt32, frame: NSRect, borderColor: NSColor, borderWidth: CGFloat, cornerRadius: CGFloat)
	{
		DispatchQueue.main.async
		{
			guard let border = self.borders[borderId] else
				{ return }

			border.nodeFrame = frame
			border.borderColor = borderColor
			border.borderWidth = borderWidth
			border.cornerRadius = cornerRadius
			border.updateFrame()
			border.showWindow()
		}
	}

	func removeBorder(id borderId: UInt32)
	{
		DispatchQueue.main.async
		{
			let overlayWindow = self.borders.removeValue(forKey: borderId)
			overlayWindow?.hide()
		}
	}
}


@objc public class CBridge : NSObject {

	static var overlayController: OverlayController! = nil

	class func invertY(y: Double, height: Double) -> Double
	{
		let scrns: Array<NSScreen> = NSScreen.screens()!
		let scrn: NSScreen = scrns[0]
		let scrnHeight: Double = Double(scrn.frame.size.height)
		let invertedY = scrnHeight - (y + height)
		return invertedY
	}

	class func initializeOverlay()
	{ overlayController = OverlayController() }

	class func createBorder(
		x: Double, y: Double, width: Double, height: Double,
		r: Double, g: Double, b: Double, a: Double,
		borderWidth: Double, cornerRadius: Double) -> UInt32
	{
		return overlayController.createBorder(
			frame: NSRect(x:x, y:invertY(y:y, height:height), width:width, height:height),
			borderColor: NSColor(red: CGFloat(r),
			                     green: CGFloat(g),
			                     blue: CGFloat(b),
			                     alpha: CGFloat(a)),
			borderWidth: CGFloat(borderWidth),
			cornerRadius: CGFloat(cornerRadius)
		)
	}

	class func updateBorder(
		id borderId: UInt32,
		x: Double, y: Double, width: Double, height: Double,
		r: Double, g: Double, b: Double, a: Double,
		borderWidth: Double, cornerRadius: Double)
	{
		return overlayController.updateBorderFrame(
			id: borderId,
			frame: NSRect(x:x, y:invertY(y:y, height:height), width:width, height:height),
			borderColor: NSColor(red: CGFloat(r),
			                     green: CGFloat(g),
			                     blue: CGFloat(b),
			                     alpha: CGFloat(a)),
			borderWidth: CGFloat(borderWidth), cornerRadius: CGFloat(cornerRadius)
		)
	}

	class func removeBorder(id borderId: UInt32)
		{ return overlayController.removeBorder(id: borderId) }
}
