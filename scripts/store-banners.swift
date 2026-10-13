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

struct Header: View {
    var body: some View {
        ZStack(alignment: .leading) {
            bg
            Title(scale: 0.74).padding(.leading, 200)
            HStack(alignment: .top, spacing: 60) {
                Phone(name: "01-game-live-scoring.png", width: 520).offset(y: 300)
                Phone(name: "07-season.png", width: 520).offset(y: 140)
                Phone(name: "04-following-game.png", width: 520).offset(y: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 140)
        }
        .frame(width: 3840, height: 1646)
        .clipped()
    }
}

struct Search: View {
    var body: some View {
        ZStack(alignment: .top) {
            bg
            Title(scale: 1).padding(.top, 170).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 240)
            HStack(alignment: .top, spacing: 120) {
                Phone(name: "01-game-live-scoring.png", width: 620).offset(y: 120)
                Phone(name: "05-game-summary.png", width: 620)
                Phone(name: "07-season.png", width: 620).offset(y: 120)
                Phone(name: "04-following-game.png", width: 620).offset(y: 240)
            }
            .padding(.top, 1020)
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
