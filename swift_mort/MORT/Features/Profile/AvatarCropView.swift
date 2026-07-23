import SwiftUI
import UIKit

struct AvatarCropView: View {
    let image: UIImage
    let onComplete: (Data) -> Void
    let onCancel: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var settledZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero
    @State private var viewportEdge: CGFloat = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: MortSpacing.lg) {
                cropViewport

                HStack(spacing: MortSpacing.md) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundStyle(MortColors.textMuted)
                    Slider(value: zoomBinding, in: 1 ... 4)
                        .tint(MortColors.neon)
                        .accessibilityLabel("Crop zoom")
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundStyle(MortColors.textMuted)
                }

                Button("Reset crop") { reset() }
                    .buttonStyle(.bordered)
                    .tint(MortColors.safetyBlue)

                Text("Move and zoom the photo inside the circle. The saved image is re-encoded to remove embedded metadata.")
                    .font(MortTypography.caption)
                    .foregroundStyle(MortColors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(MortSpacing.lg)
            .navigationTitle("Crop photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use photo") { complete() }
                        .disabled(viewportEdge <= 0)
                }
            }
            .alert("Crop unavailable", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .mortScreen()
        }
    }

    private var cropViewport: some View {
        GeometryReader { proxy in
            let edge = min(proxy.size.width, proxy.size.height)
            let displaySize = AvatarCropGeometry.displaySize(
                imageSize: image.size,
                viewport: edge,
                zoom: zoom
            )

            ZStack {
                Color.black
                Image(uiImage: image)
                    .resizable()
                    .frame(width: displaySize.width, height: displaySize.height)
                    .offset(offset)
                AvatarCropGuide()
            }
            .frame(width: edge, height: edge)
            .clipShape(Rectangle())
            .contentShape(Rectangle())
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .simultaneousGesture(dragGesture(viewport: edge))
            .simultaneousGesture(magnificationGesture(viewport: edge))
            .onAppear { updateViewport(edge) }
            .onChange(of: edge) { _, value in updateViewport(value) }
            .accessibilityLabel("Avatar crop preview")
            .accessibilityHint("Drag to reposition the image and pinch to zoom")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var zoomBinding: Binding<CGFloat> {
        Binding(
            get: { zoom },
            set: { value in
                zoom = min(max(value, 1), 4)
                settledZoom = zoom
                offset = clamped(offset, viewport: viewportEdge)
                settledOffset = offset
            }
        )
    }

    private func dragGesture(viewport: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
                offset = clamped(proposed, viewport: viewport)
            }
            .onEnded { _ in settledOffset = offset }
    }

    private func magnificationGesture(viewport: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(settledZoom * value, 1), 4)
                offset = clamped(offset, viewport: viewport)
            }
            .onEnded { _ in
                settledZoom = zoom
                settledOffset = offset
            }
    }

    private func clamped(_ value: CGSize, viewport: CGFloat) -> CGSize {
        AvatarCropGeometry.clampedOffset(
            value,
            imageSize: image.size,
            viewport: viewport,
            zoom: zoom
        )
    }

    private func updateViewport(_ edge: CGFloat) {
        viewportEdge = edge
        offset = clamped(offset, viewport: edge)
        settledOffset = offset
    }

    private func reset() {
        zoom = 1
        settledZoom = 1
        offset = .zero
        settledOffset = .zero
    }

    private func complete() {
        do {
            let data = try ImageProcessingService.renderAvatarCrop(
                image,
                viewport: viewportEdge,
                zoom: zoom,
                offset: offset
            )
            onComplete(data)
        } catch {
            errorMessage = mortMessage(error)
        }
    }
}

private struct AvatarCropGuide: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let third = proxy.size.width / 3
                path.move(to: CGPoint(x: third, y: 0))
                path.addLine(to: CGPoint(x: third, y: proxy.size.height))
                path.move(to: CGPoint(x: third * 2, y: 0))
                path.addLine(to: CGPoint(x: third * 2, y: proxy.size.height))
                path.move(to: CGPoint(x: 0, y: third))
                path.addLine(to: CGPoint(x: proxy.size.width, y: third))
                path.move(to: CGPoint(x: 0, y: third * 2))
                path.addLine(to: CGPoint(x: proxy.size.width, y: third * 2))
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 1)

            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .padding(2)
        }
        .allowsHitTesting(false)
    }
}
