import SwiftUI
import PocketInputKit

struct TrackpadView: View {
    let onMove: (Double, Double) -> Void
    let onLeftTap: () -> Void
    let onRightClick: () -> Void

    @State private var lastTranslation: CGSize = .zero
    @State private var didDrag = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.12))
                Text("触控板")
                    .foregroundStyle(.white.opacity(0.35))
                    .font(.title3)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard !didDrag else {
                        didDrag = false
                        return
                    }
                    onLeftTap()
                }
            )
            .padding(.horizontal)
            .padding(.top)

            Button {
                onRightClick()
            } label: {
                Text("右键")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let dx = value.translation.width - lastTranslation.width
                let dy = value.translation.height - lastTranslation.height
                lastTranslation = value.translation
                if abs(dx) > 0 || abs(dy) > 0 {
                    didDrag = true
                    onMove(Double(dx), Double(dy))
                }
            }
            .onEnded { _ in
                lastTranslation = .zero
                // Keep didDrag true until tap gesture can see it, then clear on next runloop.
                DispatchQueue.main.async {
                    didDrag = false
                }
            }
    }
}
