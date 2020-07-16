import SwiftUI

struct PairCell: View {
    enum Form {
        case lecture
        case practice
        case lab
        case exam
        case unknown
    }

    var from: String
    var to: String
    var subject: String
    var weeks: String?
    var note: String
    var form: Form
    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        HStack() {

            if sizeCategory.isAccessibility {

                PairFormIndicator(form: form)

                VStack(alignment: .leading) {
                    Text("\(from)-\(to)").font(.system(.callout, design: .monospaced))
                    Text(subject).font(.headline).bold()
                    weeks.map { Text($0).font(.caption) }
                    Text(note).font(.caption)
                }
            } else {

                VStack(alignment: .trailing) {
                    Text(from).font(.system(.callout, design: .monospaced))
                    Text(to).font(.system(.footnote, design: .monospaced))
                }

                PairFormIndicator(form: form)

                VStack(alignment: .leading) {
                    HStack {
                        Text(subject).font(.headline).bold()
                        weeks.map { Text("(\($0))").font(.callout) }
                    }
                    Text(note).font(.callout)
                }
            }

            Spacer().layoutPriority(-1)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(Color(.secondarySystemBackground))
        )
    }
}

private struct PairFormIndicator: View {
    var form: PairCell.Form
    @Environment(\.sizeCategory) private var sizeCategory
    @ScaledMetric(relativeTo: .body) private var formIndicatorWidth: CGFloat = 3

    var body: some View {
        Capsule()
            .frame(width: formIndicatorWidth)
            .foregroundColor(form.color)
    }
}

extension PairCell {
    init(pair: Day.Pair) {
        self.init(
            from: pair.from,
            to: pair.to,
            subject: pair.subject,
            weeks: pair.weeks,
            note: pair.note,
            form: Form(pair.form)
        )
    }
}

extension PairCell.Form {
    var color: Color {
        switch self {
        case .lecture: return .green
        case .practice: return .red
        case .lab: return .yellow
        case .exam: return .purple
        case .unknown: return .gray
        }
    }

    init(_ form: Day.Pair.Form) {
        switch form {
        case .exam: self = .exam
        case .lab: self = .lab
        case .lecture: self = .lecture
        case .practice: self = .practice
        case .unknown: self = .unknown
        }
    }
}

extension ContentSizeCategory {

    var isAccessibility: Bool { Self.accessibility.contains(self) }

    private static let accessibility: Set<ContentSizeCategory> = [
        .accessibilityMedium,
        .accessibilityLarge,
        .accessibilityExtraLarge,
        .accessibilityExtraExtraLarge,
        .accessibilityExtraExtraExtraLarge
    ]
}

#if DEBUG
struct PairView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PairCell(
                from: "9:00",
                to: "11:30",
                subject: "ОСиСП",
                weeks: "1,2",
                note: "Пара проходит в подвале",
                form: .lab
            )

            PairCell(
                from: "9:00",
                to: "11:30",
                subject: "ОСиСП",
                weeks: "1,2",
                note: "Пара проходит в подвале",
                form: .lab
            )
            .colorScheme(.dark)

            PairCell(
                from: "9:00",
                to: "11:30",
                subject: "ОСиСП",
                weeks: "1,2",
                note: "Пара проходит в подвале",
                form: .lab
            )
            .environment(\.sizeCategory, .accessibilityMedium)
        }
        .previewLayout(.sizeThatFits)
        .background(Color.gray)
    }
}
#endif