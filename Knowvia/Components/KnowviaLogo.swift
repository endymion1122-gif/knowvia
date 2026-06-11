import SwiftUI

struct KnowviaLogo: View {
    var markSize: CGFloat = 34
    var showsWordmark = true

    var body: some View {
        HStack(spacing: 10) {
            LogoMark()
                .frame(width: markSize, height: markSize)

            if showsWordmark {
                VStack(alignment: .leading, spacing: 1) {
                    Text("知径")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(AppTheme.deepIndigo)
                    Text("Knowvia")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.slateBlue)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("知径 Knowvia")
    }
}

struct LogoMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height)
            let lineWidth = scale * 0.105
            let center = point(0.47, 0.43, in: size)
            let topLeft = point(0.22, 0.12, in: size)
            let bottomLeft = point(0.22, 0.73, in: size)
            let topRight = point(0.78, 0.15, in: size)
            let bottomRight = point(0.79, 0.82, in: size)

            var leftPath = Path()
            leftPath.move(to: topLeft)
            leftPath.addLine(to: bottomLeft)
            leftPath.addLine(to: center)
            context.stroke(
                leftPath,
                with: .linearGradient(
                    Gradient(colors: [AppTheme.deepIndigo, AppTheme.softViolet]),
                    startPoint: topLeft,
                    endPoint: center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            var upperPath = Path()
            upperPath.move(to: center)
            upperPath.addLine(to: topRight)
            context.stroke(
                upperPath,
                with: .linearGradient(
                    Gradient(colors: [AppTheme.softViolet, AppTheme.deepIndigo]),
                    startPoint: center,
                    endPoint: topRight
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            var lowerPath = Path()
            lowerPath.move(to: center)
            lowerPath.addLine(to: bottomRight)
            context.stroke(
                lowerPath,
                with: .linearGradient(
                    Gradient(colors: [AppTheme.softViolet, AppTheme.pathTeal]),
                    startPoint: center,
                    endPoint: bottomRight
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            fillCircle(at: topRight, radius: lineWidth / 2, color: AppTheme.deepIndigo, context: &context)
            fillCircle(at: topLeft, radius: scale * 0.105, color: AppTheme.deepIndigo, context: &context)
            fillCircle(at: center, radius: scale * 0.112, color: AppTheme.softViolet, context: &context)
            fillCircle(at: bottomRight, radius: scale * 0.108, color: AppTheme.pathTeal, context: &context)
        }
        .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    private func fillCircle(
        at point: CGPoint,
        radius: CGFloat,
        color: Color,
        context: inout GraphicsContext
    ) {
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
}

#Preview {
    KnowviaLogo(markSize: 52)
        .padding()
}
