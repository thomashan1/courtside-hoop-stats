// App Store product page header + search results banners, built from the
// promoted screenshots in docs/img. Re-run after re-promoting screenshots.
import SwiftUI
import AppKit

// Run from the repo root: swift scripts/store-banners.swift
let img = "docs/img/"
func load(_ n: String) -> NSImage { NSImage(contentsOfFile: img + n)! }
let navy = Color(red: 0x0C/255, green: 0x2C/255, blue: 0x5E/255)
let blue = Color(red: 0x1E/255, green: 0x5F/255, blue: 0xCF/255)

struct Phone: View {
    let name: String; let width: CGFloat
    var body: some View {
        Image(nsImage: load(name)).resizable().interpolation(.high)
            .aspectRatio(1284/2778, contentMode: .fit)
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: width * 0.12, style: .continuous))
            .padding(width * 0.025)
            .background(RoundedRectangle(cornerRadius: width * 0.14, style: .continuous).fill(Color.black))
            .shadow(color: .black.opacity(0.45), radius: width * 0.06, y: width * 0.04)
    }
}

struct Title: View {
    let scale: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 28 * scale) {
            HStack(spacing: 32 * scale) {
                Image(nsImage: load("app-icon.png")).resizable()
                    .frame(width: 150 * scale, height: 150 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 34 * scale, style: .continuous))
                Text("Courtside Hoop Stats")
                    .font(.system(size: 92 * scale, weight: .heavy, design: .rounded))
            }
            Text("Every basket, every player,\nright from the sideline.")
                .font(.system(size: 150 * scale, weight: .bold, design: .rounded))
                .lineSpacing(6 * scale)
            Text("Live scoring · Season averages · Box-score PDFs · Family following")
                .font(.system(size: 64 * scale, weight: .medium, design: .rounded))
                .opacity(0.8)
        }
        .foregroundStyle(.white)
    }
}

let bg = LinearGradient(colors: [navy, blue], startPoint: .bottomLeading, endPoint: .topTrailing)

/// Faint half-court lines: the centre circle and the line through it, so the
/// space above the title that some devices crop isn't just empty gradient.
struct Court: View {
    let centerY: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let style = StrokeStyle(lineWidth: 14)
            let c = CGPoint(x: size.width / 2, y: centerY)
            for r in [260.0, 640.0] {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                           with: .color(.white.opacity(0.07)), style: style)
            }
            var line = Path(); line.move(to: CGPoint(x: 0, y: c.y)); line.addLine(to: CGPoint(x: size.width, y: c.y))
            ctx.stroke(line, with: .color(.white.opacity(0.07)), style: style)
        }
    }
}

// The header is cropped differently on every device; only a centred
// 1646 × 661 box (x 1097–2743, y 493–1154, from Apple's template) is always
// shown. Text lives inside it, centred; the phones are decoration either side
// and may be cut.
struct Header: View {
    var body: some View {
        ZStack {
            bg
            HStack(alignment: .top, spacing: 0) {
                Phone(name: "02-game-live-scoring.png", width: 470).offset(y: 360)
                Phone(name: "06-game-summary.png", width: 470).offset(x: -40, y: 560)
                Spacer()
                Phone(name: "08-season.png", width: 470).offset(x: 40, y: 560)
                Phone(name: "05-following-game.png", width: 470).offset(y: 360)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 120)
            VStack(spacing: 30) {
                HStack(spacing: 26) {
                    Image(nsImage: load("app-icon.png")).resizable()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    Text("Courtside Hoop Stats")
                        .font(.system(size: 66, weight: .heavy, design: .rounded))
                }
                Text("Every basket, every player,\nright from the sideline.")
                    .font(.system(size: 104, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                Text("Live scoring · Season averages · Box-score PDFs · Family following")
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(width: 1646, height: 661)
            .offset(y: (493 + 661 / 2) - 1646 / 2)
        }
        .frame(width: 3840, height: 1646)
        .clipped()
    }
}

// Search results: always-shown box is x 836–3004, y 765–1795. The title sits
// centred at its top, the phones rise into it from below.
struct Search: View {
    var body: some View {
        ZStack(alignment: .top) {
            bg
            Court(centerY: 330)
            HStack(alignment: .top, spacing: 110) {
                Phone(name: "02-game-live-scoring.png", width: 600).offset(y: 120)
                Phone(name: "06-game-summary.png", width: 600)
                Phone(name: "08-season.png", width: 600).offset(y: 120)
                Phone(name: "05-following-game.png", width: 600).offset(y: 240)
            }
            .padding(.top, 1330)
            VStack(spacing: 30) {
                HStack(spacing: 28) {
                    Image(nsImage: load("app-icon.png")).resizable()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    Text("Courtside Hoop Stats")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                }
                Text("Every basket, every player,\nright from the sideline.")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                Text("Live scoring · Season averages · Box-score PDFs · Family following")
                    .font(.system(size: 52, weight: .medium, design: .rounded))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(width: 2168)
            .padding(.top, 800)
        }
        .frame(width: 3840, height: 2560)
        .clipped()
    }
}

@MainActor func save<V: View>(_ v: V, _ path: String) {
    let r = ImageRenderer(content: v); r.scale = 1
    let cg = r.cgImage!
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print(path, cg.width, cg.height)
}
MainActor.assumeIsolated {
    save(Header(), "docs/img/store-header-3840x1646.png")
    save(Search(), "docs/img/store-search-results-3840x2560.png")
}
