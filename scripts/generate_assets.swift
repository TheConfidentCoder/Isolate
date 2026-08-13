import Cocoa

func createDMGBackground() {
    let width: CGFloat = 660
    let height: CGFloat = 440
    let scale: CGFloat = 2.0
    let size = NSSize(width: width * scale, height: height * scale)
    
    let image = NSImage(size: size)
    image.lockFocus()
    
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.scaleBy(x: scale, y: scale)
    
    // Background: Pitch Black OLED
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    
    // Dot Matrix Pattern
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.05))
    for x in stride(from: 18.0, through: width - 18.0, by: 16.0) {
        for y in stride(from: 18.0, through: height - 18.0, by: 16.0) {
            context.fill(CGRect(x: x, y: y, width: 2, height: 2))
        }
    }
    
    // Outer Subtle Border
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
    context.setLineWidth(1.0)
    context.stroke(CGRect(x: 18, y: 18, width: width - 36, height: height - 36))
    
    // Red Corner Brackets
    let bracketLen: CGFloat = 20.0
    context.setStrokeColor(CGColor(red: 1.0, green: 0.18, blue: 0.18, alpha: 1.0))
    context.setLineWidth(2.5)
    
    // Bottom-Left
    context.strokeLineSegments(between: [
        CGPoint(x: 16, y: 16 + bracketLen), CGPoint(x: 16, y: 16),
        CGPoint(x: 16, y: 16), CGPoint(x: 16 + bracketLen, y: 16)
    ])
    // Bottom-Right
    context.strokeLineSegments(between: [
        CGPoint(x: width - 16 - bracketLen, y: 16), CGPoint(x: width - 16, y: 16),
        CGPoint(x: width - 16, y: 16), CGPoint(x: width - 16, y: 16 + bracketLen)
    ])
    // Top-Left
    context.strokeLineSegments(between: [
        CGPoint(x: 16, y: height - 16 - bracketLen), CGPoint(x: 16, y: height - 16),
        CGPoint(x: 16, y: height - 16), CGPoint(x: 16 + bracketLen, y: height - 16)
    ])
    // Top-Right
    context.strokeLineSegments(between: [
        CGPoint(x: width - 16 - bracketLen, y: height - 16), CGPoint(x: width - 16, y: height - 16),
        CGPoint(x: width - 16, y: height - 16), CGPoint(x: width - 16, y: height - 16 - bracketLen)
    ])
    
    // Coordinate Mapping:
    // In Finder (top-down, height=440):
    // Isolate.app icon is at (165, 195).
    // Applications icon is at (495, 195).
    // In AppKit (bottom-up): Y_appkit = 440 - Y_finder = 245.
    let iconCenterY: CGFloat = 245.0
    let leftCenterX: CGFloat = 165.0
    let rightCenterX: CGFloat = 495.0
    
    // Left Slot Drop-Target Box for Isolate.app
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
    context.setLineWidth(1.2)
    let boxW: CGFloat = 140
    let boxH: CGFloat = 160
    let leftBox = CGRect(x: leftCenterX - boxW / 2, y: iconCenterY - boxH / 2 - 8, width: boxW, height: boxH)
    let leftPath = CGPath(roundedRect: leftBox, cornerWidth: 14, cornerHeight: 14, transform: nil)
    context.addPath(leftPath)
    context.strokePath()
    
    // Right Slot Drop-Target Box for Applications
    let rightBox = CGRect(x: rightCenterX - boxW / 2, y: iconCenterY - boxH / 2 - 8, width: boxW, height: boxH)
    let rightPath = CGPath(roundedRect: rightBox, cornerWidth: 14, cornerHeight: 14, transform: nil)
    context.addPath(rightPath)
    context.strokePath()
    
    // Center Hardware Directional Arrow
    context.setStrokeColor(CGColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.9))
    context.setLineWidth(3.0)
    context.setLineDash(phase: 0, lengths: [6, 4])
    context.strokeLineSegments(between: [
        CGPoint(x: 250, y: iconCenterY), CGPoint(x: 395, y: iconCenterY)
    ])
    context.setLineDash(phase: 0, lengths: []) // reset
    
    // Arrow Head
    context.setFillColor(CGColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0))
    let arrowPath = CGMutablePath()
    arrowPath.move(to: CGPoint(x: 410, y: iconCenterY))
    arrowPath.addLine(to: CGPoint(x: 394, y: iconCenterY + 9))
    arrowPath.addLine(to: CGPoint(x: 394, y: iconCenterY - 9))
    arrowPath.closeSubpath()
    context.addPath(arrowPath)
    context.fillPath()
    
    // Typography
    let fontName = "Courier-Bold"
    let headerFont = NSFont(name: fontName, size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    let titleFont = NSFont(name: fontName, size: 18) ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
    let hintFont = NSFont(name: fontName, size: 10.5) ?? NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
    let telemetryFont = NSFont(name: fontName, size: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    
    // App Title Top
    let titleAttr: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor.white
    ]
    let titleStr = NSAttributedString(string: "ISOLATE INSTALLER", attributes: titleAttr)
    titleStr.draw(at: NSPoint(x: (width - titleStr.size().width) / 2, y: height - 52))
    
    // Action Label Center
    let actionAttr: [NSAttributedString.Key: Any] = [
        .font: headerFont,
        .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)
    ]
    let actionStr = NSAttributedString(string: "[ DRAG TO INSTALL ]", attributes: actionAttr)
    actionStr.draw(at: NSPoint(x: (width - actionStr.size().width) / 2, y: iconCenterY + 20))
    
    // Target Box Labels
    let boxLabelAttr: [NSAttributedString.Key: Any] = [
        .font: headerFont,
        .foregroundColor: NSColor.lightGray
    ]
    let leftStr = NSAttributedString(string: "ISOLATE.APP", attributes: boxLabelAttr)
    leftStr.draw(at: NSPoint(x: leftCenterX - leftStr.size().width / 2, y: leftBox.minY - 24))
    
    let rightStr = NSAttributedString(string: "APPLICATIONS", attributes: boxLabelAttr)
    rightStr.draw(at: NSPoint(x: rightCenterX - rightStr.size().width / 2, y: rightBox.minY - 24))
    
    // First Run Gatekeeper Helper Banner
    let hintAttr: [NSAttributedString.Key: Any] = [
        .font: hintFont,
        .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
    ]
    let hintStr = NSAttributedString(string: "FIRST LAUNCH: Right-click Isolate.app → Open (or double-click 'Open Isolate')", attributes: hintAttr)
    hintStr.draw(at: NSPoint(x: (width - hintStr.size().width) / 2, y: 52))
    
    // Bottom Telemetry
    let footAttr: [NSAttributedString.Key: Any] = [
        .font: telemetryFont,
        .foregroundColor: NSColor(calibratedWhite: 0.45, alpha: 1.0)
    ]
    let footStr = NSAttributedString(string: "DEMUCS V4 COREML • APPLE SILICON NEURAL ENGINE ACCELERATED", attributes: footAttr)
    footStr.draw(at: NSPoint(x: (width - footStr.size().width) / 2, y: 26))
    
    image.unlockFocus()
    
    if let tiffData = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiffData),
       let pngData = rep.representation(using: .png, properties: [:]) {
        let outDir = URL(fileURLWithPath: "Assets")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let outURL = outDir.appendingPathComponent("dmg_background.png")
        try? pngData.write(to: outURL)
        print("Generated DMG background at \(outURL.path)")
    }
}

func createAppIcon() {
    let iconSpecs: [(name: String, pixelSize: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]
    
    let iconsetDir = URL(fileURLWithPath: "Assets/AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconsetDir)
    try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
    
    for spec in iconSpecs {
        let s = CGFloat(spec.pixelSize)
        let size = NSSize(width: s, height: s)
        let img = NSImage(size: size)
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else { continue }
        
        let bounds = CGRect(x: 0, y: 0, width: s, height: s)
        
        // Dark Rounded Squircle Bezel
        let corner = s * 0.2237 // Apple standard macOS squircle proportion
        let path = CGPath(roundedRect: bounds, cornerWidth: corner, cornerHeight: corner, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0))
        ctx.fillPath()
        
        // Subtle Faint Dot Grid Texture
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        
        let dotStep = max(3.0, s * 0.05)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.035))
        for gx in stride(from: dotStep, through: s - dotStep, by: dotStep) {
            for gy in stride(from: dotStep, through: s - dotStep, by: dotStep) {
                let dotW = max(1.0, s * 0.012)
                ctx.fill(CGRect(x: gx, y: gy, width: dotW, height: dotW))
            }
        }
        ctx.restoreGState()
        
        // Subtle Inner Bezel Border
        ctx.addPath(path)
        ctx.setStrokeColor(CGColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0))
        ctx.setLineWidth(max(1.0, s * 0.015))
        ctx.strokePath()
        
        // Center Hardware Graphic: 4 Dot-Matrix Pixel Stems (Vocals, Drums, Bass, Other)
        // Dot counts per stem: 5, 8, 10, 6 square pixels
        let stemPixelCounts = [5, 8, 10, 6]
        let maxDots = 10
        
        let pixelSize = max(2.0, s * 0.075)
        let pixelGap = max(1.0, s * 0.02)
        let colSpacing = max(2.0, s * 0.05)
        
        let totalW = CGFloat(4) * pixelSize + CGFloat(3) * colSpacing
        let startX = (s - totalW) / 2.0
        
        let totalMaxH = CGFloat(maxDots) * pixelSize + CGFloat(maxDots - 1) * pixelGap
        let startY = (s - totalMaxH) / 2.0
        
        for (colIndex, count) in stemPixelCounts.enumerated() {
            let colX = startX + CGFloat(colIndex) * (pixelSize + colSpacing)
            let colH = CGFloat(count) * pixelSize + CGFloat(count - 1) * pixelGap
            let colStartY = startY + (totalMaxH - colH) / 2.0 // vertically centered
            
            // Stem Colors: Bar 1 (White), Bar 2 (Red), Bar 3 (Red), Bar 4 (White)
            let color: CGColor
            if colIndex == 1 || colIndex == 2 {
                color = CGColor(red: 1.0, green: 0.18, blue: 0.18, alpha: 1.0)
            } else {
                color = CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
            }
            ctx.setFillColor(color)
            
            for dotIndex in 0..<count {
                let dotY = colStartY + CGFloat(dotIndex) * (pixelSize + pixelGap)
                let dotRect = CGRect(x: colX, y: dotY, width: pixelSize, height: pixelSize)
                let dotRadius = max(0.5, pixelSize * 0.18) // subtle rounded square pixel
                let dotPath = CGPath(roundedRect: dotRect, cornerWidth: dotRadius, cornerHeight: dotRadius, transform: nil)
                ctx.addPath(dotPath)
                ctx.fillPath()
            }
        }
        
        // Red corner LED status indicator dot (Top-Right)
        let dotSize = max(3.0, s * 0.07)
        let dotX = s - corner - dotSize * 0.6
        let dotY = s - corner - dotSize * 0.6
        
        // Outer faint glow
        ctx.setFillColor(CGColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 0.25))
        ctx.fillEllipse(in: CGRect(x: dotX - dotSize * 0.25, y: dotY - dotSize * 0.25, width: dotSize * 1.5, height: dotSize * 1.5))
        
        // Solid LED
        ctx.setFillColor(CGColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 1.0))
        ctx.fillEllipse(in: CGRect(x: dotX, y: dotY, width: dotSize, height: dotSize))
        
        img.unlockFocus()
        
        if let tiffData = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiffData),
           let png = rep.representation(using: .png, properties: [:]) {
            let outURL = iconsetDir.appendingPathComponent(spec.name)
            try? png.write(to: outURL)
        }
    }
    
    // Generate AppIcon.icns using iconutil
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    proc.arguments = ["-c", "icns", "Assets/AppIcon.iconset", "-o", "Assets/AppIcon.icns"]
    try? proc.run()
    proc.waitUntilExit()
    
    // Copy to Sources/Resources/AppIcon.icns
    try? FileManager.default.removeItem(atPath: "Sources/Resources/AppIcon.icns")
    try? FileManager.default.copyItem(atPath: "Assets/AppIcon.icns", toPath: "Sources/Resources/AppIcon.icns")
    print("Generated complete Nothing dot-matrix AppIcon.icns")
}

createDMGBackground()
createAppIcon()
