---
title: Create particle textures
column: todo
position: zb
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, assets, shared]
---

## Description

Create or source the texture images used by the particle system. These are simple shapes that SpriteKit tints and animates. All should be white/grayscale so they can be color-tinted by the emitters.

## Acceptance Criteria

- [ ] Create spark.png (soft glowing circle for explosions)
- [ ] Create ember.png (tiny glowing dot)
- [ ] Create smoke.png (soft cloud shape)
- [ ] Create confetti.png (small rectangle)
- [ ] Create jira_logo.png (simplified/parody logo)
- [ ] All textures are white/grayscale for tinting
- [ ] All have proper alpha transparency
- [ ] Appropriate sizes (not too large for performance)
- [ ] Add to asset catalog for both platforms
- [ ] Test textures render correctly in SpriteKit

## Technical Notes

### Texture Specifications

| File | Size | Description |
|------|------|-------------|
| spark.png | 16x16 | Soft white circle, gaussian blur, centered |
| ember.png | 8x8 | Tiny bright dot, very soft edges |
| smoke.png | 32x32 | Soft cloud/blob shape, very blurred |
| confetti.png | 4x8 | Simple white rectangle |
| jira_logo.png | 16x16 | Simplified ticket icon (parody) |

### Creating in Sketch/Figma

**spark.png:**
1. 16x16 canvas, transparent background
2. White circle, 12px diameter, centered
3. Gaussian blur: 3px radius
4. Export as PNG with transparency

**ember.png:**
1. 8x8 canvas, transparent background
2. White circle, 4px diameter, centered
3. Gaussian blur: 2px radius
4. Export as PNG

**smoke.png:**
1. 32x32 canvas, transparent background
2. Irregular blob shape using multiple overlapping circles
3. Heavy gaussian blur: 6-8px
4. Reduce opacity to ~80%
5. Export as PNG

**confetti.png:**
1. 4x8 canvas, transparent background
2. White rectangle filling canvas
3. Optional: slight rounded corners
4. Export as PNG

**jira_logo.png (parody):**
1. 16x16 canvas
2. Simple geometric shape suggesting a ticket/card
3. Don't copy actual Jira logo exactly (trademark)
4. Could be: Blue gradient square with white corner fold
5. Export as PNG

### Alternative: Programmatic Generation

Can generate simple textures in code:

```swift
extension SKTexture {
    static func softCircle(diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: diameter/2, y: diameter/2)
            let gradient = CGGradient(
                colorsSpace: nil,
                colors: [UIColor.white.cgColor, UIColor.clear.cgColor] as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: diameter/2,
                options: []
            )
        }
        return SKTexture(image: image)
    }
}
```

File: Place in `Resources/Particles/`

## Platform Notes

Textures go in Asset Catalog and are shared between iOS and macOS.

Consider @2x and @3x versions for Retina displays, though for particle effects the base resolution is often sufficient.

## Quality Check

After creating:
1. Load each texture in SpriteKit test scene
2. Verify alpha channel works correctly
3. Check that white textures tint to colors properly
4. Verify performance with many particles
