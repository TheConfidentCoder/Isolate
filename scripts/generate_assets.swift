import Cocoa

func createDMGBackground() {
    let width: CGFloat = 660
    let height: CGFloat = 420
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
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.04))
    for x in stride(from: 20.0, through: width - 20.0, by: 16.0) {
        for y in stride(from: 20.0, through: height - 20.0, by: 16.0) {
            context.fill(CGRect(x: x, y: y, width: 2, height: 2))
        }
    }
    
    // Outer Subtle Border
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    context.setLineWidth(1.0)
    context.stroke(CGRect(x: 20, y: 20, width: width - 40, height: height - 40))
    
    // Red Corner Brackets
    let bracketLen: CGFloat = 16.0
    context.setStrokeColor(CGColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 0.9))
    context.setLineWidth(2.0)
    
    // Bottom-Left
    context.strokeLineSegments(between: [
        CGPoint(x: 18, y: 18 + bracketLen), CGPoint(x: 18, y: 18),
        CGPoint(x: 18, y: 18), CGPoint(x: 18 + bracketLen, y: 18)
    ])
    // Bottom-Right
    context.strokeLineSegments(between: [
        CGPoint(x: width - 18 - bracketLen, y: 18), CGPoint(x: width - 18, y: 18),
        CGPoint(x: width - 18, y: 18), CGPoint(x: width - 18, y: 18 + bracketLen)
    ])
    // Top-Left
    context.strokeLineSegments(between: [
        CGPoint(x: 18, y: height - 18 - bracketLen), CGPoint(x: 18, y: height - 18),
        CGPoint(x: 18, y: height - 18), CGPoint(x: 18 + bracketLen, y: height - 18)
    ])
    // Top-Right
    context.strokeLineSegments(between: [
        CGPoint(x: width - 18 - bracketLen, y: height - 18), CGPoint(x: width - 18, y: height - 18),
        CGPoint(x: width - 18, y: height - 18), CGPoint(x: width - 18, y: height - 18 - bracketLen)
    ])
    
    // Center Hardware Directional Arrow (Y inverted in CG: 210 is center)
    let centerY: CGFloat = 200
    context.setStrokeColor(CGColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.85))
    context.setLineWidth(2.5)
    context.setLineDash(phase: 0, lengths: [6, 4])
    context.strokeLineSegments(between: [
        CGPoint(x: 250, y: centerY), CGPoint(x: 390, y: centerY)
    ])
    context.setLineDash(phase: 0, lengths: []) // reset
    
    // Arrow Head
    context.setFillColor(CGColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.95))
    let arrowPath = CGMutablePath()
    arrowPath.move(to: CGPoint(x: 402, y: centerY))
    arrowPath.addLine(to: CGPoint(x: 388, y: centerY + 8))
    arrowPath.addLine(to: CGPoint(x: 388, y: centerY - 8))
    arrowPath.closeSubpath()
    context.addPath(arrowPath)
    context.fillPath()
    
    // Left Slot Target Box (Isolate.app at x: 160)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
    context.setLineWidth(1.0)
    let leftBox = CGRect(x: 100, y: 120, width: 120, height: 160)
    let leftPath = CGPath(roundedRect: leftBox, cornerWidth: 12, cornerHeight: 12, transform: nil)
    context.addPath(leftPath)
    context.strokePath()
    
    // Right Slot Target Box (/Applications at x: 500)
    let rightBox = CGRect(x: 440, y: 120, width: 120, height: 160)
    let rightPath = CGPath(roundedRect: rightBox, cornerWidth: 12, cornerHeight: 12, transform: nil)
    context.addPath(rightPath)
    context.strokePath()
    
    // Typography
    let fontName = "Courier-Bold"
    let headerFont = NSFont(name: fontName, size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
    let titleFont = NSFont(name: fontName, size: 16) ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
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
        .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
    ]
    let actionStr = NSAttributedString(string: "[ DRAG TO INSTALL ]", attributes: actionAttr)
    actionStr.draw(at: NSPoint(x: (width - actionStr.size().width) / 2, y: centerY + 18))
    
    // Left Label
    let leftAttr: [NSAttributedString.Key: Any] = [
        .font: headerFont,
        .foregroundColor: NSColor.lightGray
    ]
    let leftStr = NSAttributedString(string: "ISOLATE.APP", attributes: leftAttr)
    leftStr.draw(at: NSPoint(x: 160 - leftStr.size().width / 2, y: 92))
    
    // Right Label
    let rightStr = NSAttributedString(string: "APPLICATIONS", attributes: leftAttr)
    rightStr.draw(at: NSPoint(x: 500 - rightStr.size().width / 2, y: 92))
    
    // Bottom Telemetry
    let footAttr: [NSAttributedString.Key: Any] = [
        .font: telemetryFont,
        .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1.0)
    ]
    let footStr = NSAttributedString(string: "DEMUCS V4 COREML • APPLE SILICON NEURAL ENGINE ACCELERATED", attributes: footAttr)
    footStr.draw(at: NSPoint(x: (width - footStr.size().width) / 2, y: 32))
    
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
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    let iconsetDir = URL(fileURLWithPath: "Assets/AppIcon.iconset")
    try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
    
    for s in sizes {
        let size = NSSize(width: s, height: s)
        let img = NSImage(size: size)
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else { continue }
        
        let bounds = CGRect(x: 0, y: 0, width: s, height: s)
        
        // Dark Rounded Squircle Bezel
        let corner = CGFloat(s) * 0.22
        let path = CGPath(roundedRect: bounds, cornerWidth: corner, cornerHeight: corner, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0))
        ctx.fillPath()
        
        // Border
        ctx.addPath(path)
        ctx.setStrokeColor(CGColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0))
        ctx.setLineWidth(max(1.0, CGFloat(s) * 0.015))
        ctx.strokePath()
        
        // Center Hardware Graphic: 4 Isolated Stem Bars (Vocals, Drums, Bass, Other)
        let barWidth = max(2.0, CGFloat(s) * 0.08)
        let barSpacing = max(2.0, CGFloat(s) * 0.06)
        let heights: [CGFloat] = [0.45, 0.75, 0.9, 0.55]
        let totalW = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * barSpacing
        let startX = (CGFloat(s) - totalW) / 2.0
        let maxHeight = CGFloat(s) * 0.45
        let startY = (CGFloat(s) - maxHeight) / 2.0
        
        for (i, hFactor) in heights.enumerated() {
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let h = maxHeight * hFactor
            let y = startY + (maxHeight - h) / 2.0
            
            // Vocals (Red), others White/Gray
            let color = (i == 1 || i == 2) ? CGColor(red: 1.0, green: 0.18, blue: 0.18, alpha: 1.0) : CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
            ctx.setFillColor(color)
            let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
            let barPath = CGPath(roundedRect: barRect, cornerWidth: barWidth * 0.4, cornerHeight: barWidth * 0.4, transform: nil)
            ctx.addPath(barPath)
            ctx.fillPath()
        }
        
        // Red corner LED dot
        let dotSize = max(3.0, CGFloat(s) * 0.06)
        ctx.setFillColor(CGColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 1.0))
        ctx.fillEllipse(in: CGRect(x: CGFloat(s) - corner - dotSize, y: CGFloat(s) - corner - dotSize, width: dotSize, height: dotSize))
        
        img.unlockFocus()
        
        if let tiffData = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiffData),
           let png = rep.representation(using: .png, properties: [:]) {
            let filename = "icon_\(s)x\(s).png"
            try? png.write(to: iconsetDir.appendingPathComponent(filename))
            if s <= 512 {
                let filename2x = "icon_\(s)x\(s)@2x.png"
                // For @2x, write next size or same
            }
        }
    }
    
    // Generate .icns using iconutil
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    proc.arguments = ["-c", "icns", "Assets/AppIcon.iconset", "-o", "Assets/AppIcon.icns"]
    try? proc.run()
    proc.waitUntilExit()
    
    // Copy to Sources/Resources
    try? FileManager.default.copyItem(atPath: "Assets/AppIcon.icns", toPath: "Sources/Resources/AppIcon.icns")
    print("Generated AppIcon.icns")
}

createDMGBackground()
createAppIcon()
