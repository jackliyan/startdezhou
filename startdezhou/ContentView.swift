import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = PokerCalculatorViewModel()
    @State private var selectedTab: CalculatorTab = .hand

    var body: some View {
        NavigationStack {
            currentTabContent
            .background(AppColors.pageBackground.ignoresSafeArea())
            .navigationTitle("弈筹机")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(selectedTab.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: viewModel.clearAll) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("重置")
                }

            }
            .safeAreaInset(edge: .bottom) {
                BottomTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(AppColors.pageBackground.opacity(0.96))
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .hand:
            TabScroll {
                DeckPanel(viewModel: viewModel)
                BlindSetupPanel(viewModel: viewModel)
                BoardPanel(viewModel: viewModel)
                SeatsPanel(viewModel: viewModel)
            }
        case .review:
            TabScroll {
                ReplayTablePanel(viewModel: viewModel)
                ActionLineEntryPanel(viewModel: viewModel)
                CalculationStatusView(viewModel: viewModel)
            }
        }
    }

}

private enum CalculatorTab: CaseIterable {
    case hand
    case review

    var title: String {
        switch self {
        case .hand: return "牌局"
        case .review: return "复盘"
        }
    }

    var systemImage: String {
        switch self {
        case .hand: return "rectangle.on.rectangle"
        case .review: return "checklist.checked"
        }
    }

    var tint: Color {
        switch self {
        case .hand: return AppColors.green
        case .review: return AppColors.blue
        }
    }
}

private struct BottomTabBar: View {
    @Binding var selectedTab: CalculatorTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CalculatorTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab

                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                        Text(tab.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .background(isSelected ? tab.tint : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .background(AppColors.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

private struct TrailingPointInputField: UIViewRepresentable {
    @Binding var value: Double
    let font: UIFont
    let tint: Color
    var accessoryButtonTitle: String = "收回"
    var accessoryAction: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .decimalPad
        textField.borderStyle = .none
        textField.textAlignment = .right
        textField.adjustsFontForContentSizeCategory = true
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        textField.text = Self.displayText(for: value)
        textField.inputAccessoryView = makeAccessoryToolbar(context: context)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        textField.font = font
        textField.textColor = UIColor(tint)
        textField.tintColor = UIColor(tint)
        textField.textAlignment = .right
        if let toolbar = textField.inputAccessoryView as? UIToolbar {
            toolbar.tintColor = UIColor(tint)
            if let accessoryButton = toolbar.items?.last {
                accessoryButton.title = accessoryButtonTitle
            }
        }

        if !textField.isFirstResponder {
            textField.text = Self.displayText(for: value)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func makeAccessoryToolbar(context: Context) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 44)))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: accessoryButtonTitle, style: .done, target: context.coordinator, action: #selector(Coordinator.accessoryButtonTapped))
        ]
        toolbar.tintColor = UIColor(tint)
        toolbar.sizeToFit()
        return toolbar
    }

    private static func displayText(for value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TrailingPointInputField

        init(parent: TrailingPointInputField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            moveCursorToEnd(textField)
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            moveCursorToEnd(textField)
        }

        @objc func textDidChange(_ textField: UITextField) {
            let sanitized = sanitize(textField.text ?? "")
            if sanitized != textField.text {
                textField.text = sanitized
            }
            parent.value = Double(sanitized) ?? 0
            moveCursorToEnd(textField)
        }

        @objc func accessoryButtonTapped() {
            parent.accessoryAction()
            dismissKeyboard()
        }

        private func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        private func sanitize(_ text: String) -> String {
            var result = ""
            var hasDecimalPoint = false

            for character in text.replacingOccurrences(of: ",", with: ".") {
                if character.isNumber {
                    result.append(character)
                } else if character == ".", !hasDecimalPoint {
                    result.append(character)
                    hasDecimalPoint = true
                }
            }

            return result
        }

        private func moveCursorToEnd(_ textField: UITextField) {
            DispatchQueue.main.async {
                let end = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }
        }
    }
}

private struct TabScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                content()
            }
            .padding(16)
            .padding(.bottom, 16)
        }
        .background(AppColors.pageBackground.ignoresSafeArea())
    }
}

private struct BlindSetupPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        HStack(spacing: 10) {
            SectionHeader(title: "盲注", systemImage: "circle.grid.cross.fill")

            Spacer(minLength: 0)

            CompactAmountField(title: "小盲", value: $viewModel.smallBlindAmount, tint: AppColors.blue)
                .frame(width: 108)

            CompactAmountField(title: "大盲", value: $viewModel.bigBlindAmount, tint: AppColors.green)
                .frame(width: 108)
        }
        .panelStyle()
    }
}

private struct AmountField: View {
    let title: String
    @Binding var value: Double
    let tint: Color
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TrailingPointInputField(
                value: $value,
                font: .monospacedDigitSystemFont(ofSize: 20, weight: .bold),
                tint: tint
            )
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BoardPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "公共牌", systemImage: "square.stack.3d.up.fill")
                Spacer()
                Text(viewModel.streetName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppColors.blue.opacity(0.12), in: Capsule())

                Button(action: viewModel.autoDealBoardCards) {
                    Label(viewModel.boardAutoDealTitle, systemImage: "wand.and.stars")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(AppColors.green)
                .disabled(!viewModel.canAutoDealBoardCards)
            }

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    SlotCardButton(
                        title: CardSlot.board(index).shortTitle,
                        card: viewModel.boardCards[index],
                        isSelected: viewModel.selectedSlot == .board(index),
                        selectAction: { viewModel.selectSlot(.board(index)) },
                        clearAction: { viewModel.clearSlot(.board(index)) }
                    )
                }
            }
        }
        .panelStyle()
    }
}

private struct SeatsPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "9 人牌桌", systemImage: "person.3.fill")
                Spacer()
                Text("\(viewModel.activePlayerCount)/9")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppColors.green.opacity(0.12), in: Capsule())

                Button(action: viewModel.autoDealPlayerCards) {
                    Label("补手牌", systemImage: "wand.and.stars")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(AppColors.green)
                .disabled(!viewModel.canAutoDealPlayerCards)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach($viewModel.playerSeats) { $seat in
                    PlayerSeatRow(
                        seat: seat,
                        position: $seat.position,
                        stackAmount: $seat.stackAmount,
                        viewModel: viewModel
                    )
                }
            }
        }
        .panelStyle()
    }
}

private struct PlayerSeatRow: View {
    let seat: PlayerSeat
    @Binding var position: TablePosition
    @Binding var stackAmount: Double
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                Text(seat.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(seat.id == 0 ? AppColors.blue : .primary)
                    .frame(minWidth: 22, alignment: .leading)

                PositionMenu(position: position) { newPosition in
                    if seat.id == 0 {
                        viewModel.updateSeatPosition(seatID: seat.id, to: newPosition)
                    } else {
                        position = newPosition
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { index in
                    let slot = CardSlot.player(seat.id, index)
                    CompactSlotCardButton(
                        title: "\(index + 1)",
                        card: seat.cards[index],
                        isSelected: viewModel.selectedSlot == slot,
                        selectAction: { viewModel.selectSlot(slot) },
                        clearAction: { viewModel.clearSlot(slot) }
                    )
                }
            }

            CompactAmountField(title: "积分", value: $stackAmount, tint: seat.id == 0 ? AppColors.blue : AppColors.green)
        }
        .padding(7)
        .frame(maxWidth: .infinity)
        .background(rowTint.opacity(seat.hasAnyCard ? 0.11 : 0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var rowTint: Color {
        seat.id == 0 ? AppColors.blue : AppColors.green
    }
}

private struct CompactSlotCardButton: View {
    let title: String
    let card: Card?
    let isSelected: Bool
    let selectAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: selectAction) {
                VStack(spacing: 1) {
                    Text(card?.rank.displayName ?? title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(card?.suit.symbol ?? " ")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(card?.suit.isRed == true ? AppColors.red : .primary)
                .frame(width: 36, height: 42)
                .background(isSelected ? AppColors.green.opacity(0.10) : AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isSelected ? AppColors.green : AppColors.border, lineWidth: isSelected ? 2 : 1)
                }
            }
            .buttonStyle(.plain)

            if card != nil {
                Button(action: clearAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .background(.background, in: Circle())
                }
                .offset(x: 5, y: -5)
            }
        }
    }
}

private struct CompactAmountField: View {
    let title: String
    @Binding var value: Double
    let tint: Color
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TrailingPointInputField(
                value: $value,
                font: .monospacedDigitSystemFont(ofSize: 15, weight: .bold),
                tint: tint
            )
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PositionMenu: View {
    let position: TablePosition
    let selectPosition: (TablePosition) -> Void

    var body: some View {
        Menu {
            ForEach(TablePosition.allCases) { item in
                Button("\(item.displayName) · \(item.detailName)") {
                    selectPosition(item)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(position.displayName)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(AppColors.gold)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppColors.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

private struct DeckPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "牌库", systemImage: "rectangle.grid.3x2.fill")
                Spacer()
                Text(viewModel.selectedSlot.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(spacing: 8) {
                ForEach(Suit.allCases) { suit in
                    HStack(spacing: 8) {
                        Text(suit.symbol)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(suit.isRed ? AppColors.red : .primary)
                            .frame(width: 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Rank.descending) { rank in
                                    let card = Card(rank: rank, suit: suit)
                                    DeckCardButton(
                                        card: card,
                                        isUsed: viewModel.selectedCards.contains(card),
                                        action: { viewModel.assignCard(card) }
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .panelStyle()
    }
}

private struct SlotCardButton: View {
    let title: String
    let card: Card?
    let isSelected: Bool
    let selectAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: selectAction) {
                VStack(spacing: 5) {
                    Text(card?.rank.displayName ?? title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(card?.suit.symbol ?? " ")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(card?.suit.isRed == true ? AppColors.red : .primary)
                .frame(maxWidth: .infinity, minHeight: 66)
                .background(slotBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? AppColors.green : AppColors.border, lineWidth: isSelected ? 2 : 1)
                }
            }
            .buttonStyle(.plain)

            if card != nil {
                Button(action: clearAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .background(.background, in: Circle())
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    private var slotBackground: Color {
        isSelected ? AppColors.green.opacity(0.10) : AppColors.cardBackground
    }
}

private struct DeckCardButton: View {
    let card: Card
    let isUsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(card.rank.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(card.suit.symbol)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(card.suit.isRed ? AppColors.red : .primary)
            .frame(width: 36, height: 42)
            .background(isUsed ? AppColors.disabledCard : AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            }
            .opacity(isUsed ? 0.36 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isUsed)
    }
}

private struct EquitySummaryView: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("胜率")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(equityText)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Spacer(minLength: 12)

                Button(action: viewModel.calculate) {
                    Label(viewModel.isCalculating ? "计算中 \(viewModel.calculationProgressText)" : "计算胜率", systemImage: viewModel.isCalculating ? "hourglass" : "play.fill")
                        .font(.headline)
                        .frame(minWidth: 112)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canCalculate || viewModel.isCalculating)
            }

            PercentBar(value: viewModel.result?.equity ?? 0, tint: AppColors.green)

            if viewModel.isCalculating {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("计算进度")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.calculationProgressText)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppColors.green)
                    }

                    ProgressView(value: viewModel.calculationProgress)
                        .progressViewStyle(.linear)
                        .tint(AppColors.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(AppColors.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 8) {
                StatTile(title: "胜率对手", value: viewModel.equityOpponentCountText, tint: AppColors.gold)
                StatTile(title: "赢", value: percentText(viewModel.result?.winRate ?? 0), tint: AppColors.green)
                StatTile(title: "平", value: percentText(viewModel.result?.tieRate ?? 0), tint: AppColors.blue)
                StatTile(title: "输", value: percentText(viewModel.result?.lossRate ?? 0), tint: AppColors.red)
            }
        }
        .panelStyle()
    }

    private var equityText: String {
        guard let result = viewModel.result else { return "--%" }
        return percentText(result.equity)
    }
}

private struct CalculationStatusView: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        if !viewModel.canCalculate {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppColors.blue)
                    .frame(width: 22)

                Text(viewModel.calculationStatusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .panelStyle()
        }
    }
}

private struct HandSnapshotPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "牌面", systemImage: "suit.club.fill")

            HStack(spacing: 8) {
                StatTile(title: "我的手牌", value: heroText, tint: AppColors.blue)
                StatTile(title: "当前牌力", value: handText, tint: AppColors.green)
            }

            if !viewModel.drawTexts.isEmpty {
                Text(viewModel.drawTexts.joined(separator: "、"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.gold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(AppColors.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .panelStyle()
    }

    private var heroText: String {
        let cards = viewModel.heroCards.compactMap { $0 }
        guard cards.count == 2 else { return "--" }
        return cards.map(\.description).joined(separator: " ")
    }

    private var handText: String {
        if let madeHand = viewModel.madeHand {
            return madeHand.displayName
        }
        if let startingHand = viewModel.startingHand {
            return startingHand.code
        }
        return "--"
    }
}

private struct ReplayTablePanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                SectionHeader(title: "复盘牌桌", systemImage: "circle.grid.3x3.fill")

                Spacer(minLength: 8)

                Text("入池 \(viewModel.selectedReviewOpponentCount)/8")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppColors.green.opacity(0.12), in: Capsule())

                if viewModel.isShowdown {
                    Text("已开牌")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppColors.gold.opacity(0.14), in: Capsule())
                }

                if !viewModel.actionLineEntries.isEmpty {
                    Button(action: viewModel.removeLastActionLineEntry) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(AppColors.blue)
                    .accessibilityLabel("撤销上一条")

                    Button(action: viewModel.clearActionLine) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(AppColors.red)
                    .accessibilityLabel("清空行动线")
                }
            }

            ReplayTableSurface(viewModel: viewModel)
            ReplayActionRail(viewModel: viewModel)
        }
        .panelStyle()
    }
}

private struct ReplayTableSurface: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel
    private let seatWidth: CGFloat = 62
    private let seatHeight: CGFloat = 62

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.green.opacity(0.20),
                                AppColors.cardBackground,
                                AppColors.panelBackground
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(AppColors.gold.opacity(0.34), lineWidth: 3)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.green.opacity(0.24), lineWidth: 1)
                            .padding(12)
                    }
                    .shadow(color: AppColors.green.opacity(0.18), radius: 22, x: 0, y: 10)
                    .frame(width: size.width * 0.88, height: size.height * 0.56)
                    .position(x: size.width / 2, y: size.height * 0.52)

                ForEach(viewModel.playerSeats) { seat in
                    ReplayTableSeatNumber(
                        number: seat.id + 1,
                        isHero: seat.id == 0,
                        isInPot: viewModel.isSeatInPot(seat.id),
                        isFolded: viewModel.isSeatFolded(seat.id)
                    )
                    .position(tableNumberPoint(for: seat.id, in: size))
                }

                ReplayTableCenter(viewModel: viewModel)
                    .frame(width: min(size.width * 0.62, 236), height: 166)
                    .position(x: size.width / 2, y: size.height * 0.52)

                ForEach(viewModel.playerSeats) { seat in
                    ReplaySeatBubble(
                        seat: seat,
                        isInPot: viewModel.isSeatInPot(seat.id),
                        isFolded: viewModel.isSeatFolded(seat.id),
                        isCurrentActor: !viewModel.isShowdown && isCurrentActor(seat.id),
                        isShowdown: viewModel.isShowdown,
                        latestActionNumber: viewModel.latestActionNumber(for: seat.id),
                        lastAction: viewModel.lastActionEntry(for: seat.id)
                    ) {
                        if seat.id == 0 {
                            viewModel.selectHeroLineActor()
                        } else {
                            viewModel.toggleReviewOpponent(seat.id)
                        }
                    }
                    .frame(width: seatWidth, height: seatHeight)
                    .position(point(for: seat.id, in: size))
                }
            }
        }
        .frame(height: 520)
        .background(AppColors.cardBackground.opacity(0.42), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        }
    }

    private func isCurrentActor(_ seatID: Int) -> Bool {
        if seatID == 0 {
            return viewModel.lineActor == .hero
        }

        return viewModel.lineActor == .opponent && viewModel.lineOpponentSeatID == seatID
    }

    private func point(for seatID: Int, in size: CGSize) -> CGPoint {
        let normalized = normalizedPoint(for: seatID)
        let x = min(max(size.width * normalized.x, seatWidth / 2), size.width - seatWidth / 2)
        let y = min(max(size.height * normalized.y, seatHeight / 2), size.height - seatHeight / 2)
        return CGPoint(x: x, y: y)
    }

    private func normalizedPoint(for seatID: Int) -> CGPoint {
        switch seatID {
        case 0: return CGPoint(x: 0.50, y: 0.93)
        case 1: return CGPoint(x: 0.21, y: 0.80)
        case 2: return CGPoint(x: 0.06, y: 0.60)
        case 3: return CGPoint(x: 0.06, y: 0.35)
        case 4: return CGPoint(x: 0.24, y: 0.12)
        case 5: return CGPoint(x: 0.50, y: 0.07)
        case 6: return CGPoint(x: 0.76, y: 0.12)
        case 7: return CGPoint(x: 0.94, y: 0.35)
        default: return CGPoint(x: 0.94, y: 0.60)
        }
    }

    private func tableNumberPoint(for seatID: Int, in size: CGSize) -> CGPoint {
        let normalized = tableNumberNormalizedPoint(for: seatID)
        return CGPoint(x: size.width * normalized.x, y: size.height * normalized.y)
    }

    private func tableNumberNormalizedPoint(for seatID: Int) -> CGPoint {
        switch seatID {
        case 0: return CGPoint(x: 0.50, y: 0.765)
        case 1: return CGPoint(x: 0.30, y: 0.710)
        case 2: return CGPoint(x: 0.16, y: 0.590)
        case 3: return CGPoint(x: 0.16, y: 0.435)
        case 4: return CGPoint(x: 0.31, y: 0.315)
        case 5: return CGPoint(x: 0.50, y: 0.280)
        case 6: return CGPoint(x: 0.69, y: 0.315)
        case 7: return CGPoint(x: 0.84, y: 0.435)
        default: return CGPoint(x: 0.84, y: 0.590)
        }
    }
}

private struct ReplayTableSeatNumber: View {
    let number: Int
    let isHero: Bool
    let isInPot: Bool
    let isFolded: Bool

    var body: some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(tint.opacity(isFolded ? 0.42 : 0.82), in: Circle())
            .overlay {
                Circle()
                    .stroke(AppColors.pageBackground.opacity(0.92), lineWidth: 2)
            }
            .overlay {
                Circle()
                    .stroke(tint.opacity(0.70), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 5, x: 0, y: 2)
    }

    private var tint: Color {
        if isFolded { return AppColors.red }
        if isHero { return AppColors.blue }
        if isInPot { return AppColors.green }
        return AppColors.gold
    }
}

private struct ReplayTableCenter: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Label("底池", systemImage: "circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.gold)

                Spacer(minLength: 4)

                Text("对手 \(viewModel.equityOpponentCountText)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(amountText(viewModel.currentActionPotAmount))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if let lastRaise = viewModel.lastRaiseTotalAmount {
                Text("加注到 \(amountText(lastRaise))")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppColors.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    ReplayMiniCard(
                        card: viewModel.boardCards[index],
                        title: ["F1", "F2", "F3", "T", "R"][index]
                    )
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("胜率")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(equityText)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppColors.green)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    Text("赢")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(percentText(viewModel.result?.winRate ?? 0))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppColors.green)
                }
            }

            PercentBar(value: viewModel.result?.equity ?? 0, tint: AppColors.green)
        }
        .padding(10)
        .background(AppColors.pageBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.green.opacity(0.24), lineWidth: 1)
        }
    }

    private var equityText: String {
        guard let result = viewModel.result else { return "--%" }
        return percentText(result.equity)
    }
}

private struct ReplayMiniCard: View {
    let card: Card?
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Text(card?.rank.displayName ?? title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(card?.suit.symbol ?? " ")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(card?.suit.isRed == true ? AppColors.red : .primary)
        .frame(width: 27, height: 34)
        .background(AppColors.panelBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(card == nil ? AppColors.border : AppColors.green.opacity(0.36), lineWidth: 1)
        }
    }
}

private struct ReplaySeatBubble: View {
    let seat: PlayerSeat
    let isInPot: Bool
    let isFolded: Bool
    let isCurrentActor: Bool
    let isShowdown: Bool
    let latestActionNumber: Int?
    let lastAction: ActionLineEntry?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Text(seat.displayName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(statusTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(seat.position.displayName)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 0)

                    if let latestActionNumber {
                        Text("\(latestActionNumber)")
                            .font(.system(size: 8, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 13, height: 13)
                            .background(statusTint, in: Circle())
                    } else {
                        Image(systemName: statusIcon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(statusTint)
                    }
                }

                HStack(spacing: 2) {
                    ForEach(0..<2, id: \.self) { index in
                        ReplayHoleCard(card: seat.cards[index], title: "\(index + 1)")
                    }
                }

                Text(compactActionText)
                    .font(.system(size: 8, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(lastAction == nil ? statusTint.opacity(0.82) : statusTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(fillColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(borderColor, lineWidth: isCurrentActor ? 2 : 1)
            }
            .opacity(seat.id == 0 || isInPot ? 1 : 0.58)
        }
        .buttonStyle(.plain)
    }

    private var compactActionText: String {
        guard let lastAction else { return statusText }
        guard let amount = lastAction.amount, amount > 0 else {
            return lastAction.action.displayName
        }
        return "\(lastAction.action.displayName) \(compactAmountText(amount))"
    }

    private func compactAmountText(_ value: Double) -> String {
        amountText(value).replacingOccurrences(of: " 积分", with: "")
    }

    private var statusText: String {
        if isFolded { return "弃牌" }
        if isShowdown && (seat.id == 0 || isInPot) { return "开牌" }
        if seat.id == 0 { return "我方" }
        return isInPot ? "入池" : "未入池"
    }

    private var statusIcon: String {
        if isFolded { return "xmark.circle.fill" }
        if isShowdown && (seat.id == 0 || isInPot) { return "eye.fill" }
        if seat.id == 0 || isInPot { return "checkmark.circle.fill" }
        return "circle"
    }

    private var statusTint: Color {
        if isFolded { return AppColors.red }
        if isShowdown && (seat.id == 0 || isInPot) { return AppColors.gold }
        if seat.id == 0 { return AppColors.blue }
        if isInPot { return AppColors.green }
        return AppColors.border.opacity(0.95)
    }

    private var fillColor: Color {
        if isFolded { return AppColors.red.opacity(0.12) }
        if isCurrentActor { return statusTint.opacity(0.18) }
        if seat.id == 0 || isInPot { return statusTint.opacity(0.11) }
        return AppColors.cardBackground
    }

    private var borderColor: Color {
        if isCurrentActor { return statusTint }
        if seat.id == 0 || isInPot || isFolded { return statusTint.opacity(0.72) }
        return AppColors.border
    }
}

private struct ReplayHoleCard: View {
    let card: Card?
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Text(card?.rank.displayName ?? title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(card?.suit.symbol ?? " ")
                .font(.system(size: 7, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(card?.suit.isRed == true ? AppColors.red : .primary)
        .frame(width: 19, height: 22)
        .background(AppColors.panelBackground, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(card == nil ? AppColors.border.opacity(0.70) : AppColors.green.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct ReplayActionRail: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("行动过程", systemImage: "arrow.right.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text("行动后底池 \(amountText(viewModel.currentActionPotAmount))")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            if viewModel.actionLineEntries.isEmpty {
                Text("暂无行动")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.actionLineEntries.enumerated()), id: \.element.id) { index, entry in
                            ReplayActionChip(index: index + 1, entry: entry)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            Button(action: viewModel.calculate) {
                Label(
                    viewModel.isCalculating ? "计算中 \(viewModel.calculationProgressText)" : "计算胜率",
                    systemImage: viewModel.isCalculating ? "hourglass" : "play.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canCalculate || viewModel.isCalculating)
        }
    }
}

private struct ReplayActionChip: View {
    let index: Int
    let entry: ActionLineEntry

    var body: some View {
        HStack(spacing: 7) {
            Text("\(index)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(actorTint, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.street.shortName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.gold)

                    Text(entry.displayActorName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(actorTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text(actionText)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(width: 128, alignment: .leading)
        .background(actorTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(actorTint.opacity(0.36), lineWidth: 1)
        }
    }

    private var actionText: String {
        let amount = entry.amountText()
        return amount.isEmpty ? entry.action.displayName : "\(entry.action.displayName) \(amount)"
    }

    private var actorTint: Color {
        entry.actor == .hero ? AppColors.blue : AppColors.green
    }
}

private struct ReviewOpponentPickerPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "入池对手", systemImage: "checklist")
                Spacer()
                Text("\(viewModel.selectedReviewOpponentCount)/8")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppColors.green.opacity(0.12), in: Capsule())
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.reviewCandidateSeats) { seat in
                    ReviewOpponentCard(
                        seat: seat,
                        isSelected: viewModel.isReviewOpponentSelected(seat.id),
                        isFolded: viewModel.foldedReviewOpponentIDs.contains(seat.id)
                    ) {
                        viewModel.toggleReviewOpponent(seat.id)
                    }
                }
            }
        }
        .panelStyle()
    }
}

private struct ReviewOpponentCard: View {
    let seat: PlayerSeat
    let isSelected: Bool
    let isFolded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(seat.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? statusTint : .primary)

                    Text(seat.position.displayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.gold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                    if isSelected, isFolded {
                        Text("已弃牌")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppColors.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? (isFolded ? "xmark.circle.fill" : "checkmark.circle.fill") : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? statusTint : .secondary)
                }

                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { index in
                        ReadonlyCompactCard(card: seat.cards[index], title: "\(index + 1)")
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("积分")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(amountText(seat.stackAmount))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppColors.green)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? statusTint.opacity(0.12) : AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? statusTint : AppColors.border, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var statusTint: Color {
        isFolded ? AppColors.red : AppColors.green
    }
}

private struct ReadonlyCompactCard: View {
    let card: Card?
    let title: String

    var body: some View {
        VStack(spacing: 1) {
            Text(card?.rank.displayName ?? title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(card?.suit.symbol ?? " ")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(card?.suit.isRed == true ? AppColors.red : .primary)
        .frame(width: 36, height: 42)
        .background(AppColors.panelBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(card == nil ? AppColors.red.opacity(0.35) : AppColors.border, lineWidth: 1)
        }
    }
}

private struct ActionLineEntryPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "行动线", systemImage: "plus.circle.fill")
                Spacer()
                StreetMenu(viewModel: viewModel)
            }

            ActionPotStrip(viewModel: viewModel)

            ActionActorSelector(viewModel: viewModel)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(LineActionKind.allCases) { action in
                    QuickActionButton(
                        title: action.displayName,
                        systemImage: iconName(for: action),
                        isSelected: viewModel.lineAction == action,
                        tint: tint(for: action)
                    ) {
                        viewModel.selectLineAction(action)
                    }
                }
            }

            if viewModel.lineAction.needsAmount {
                if viewModel.lineAction == .allIn {
                    AllInAmountRow(
                        title: viewModel.lineAmountTitle,
                        actorName: viewModel.selectedLineActorName,
                        amount: viewModel.currentLineAmount
                    )
                } else {
                    ActionAmountRow(
                        title: viewModel.lineAmountTitle,
                        value: $viewModel.lineAmount,
                        confirmAction: viewModel.addActionLineEntry
                    )
                }

                HStack(spacing: 8) {
                    StatTile(title: "行动后底池", value: amountText(viewModel.previewActionPotAmount), tint: AppColors.gold)
                    Button(action: viewModel.addActionLineEntry) {
                        Label("确认", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .panelStyle()
    }

    private func iconName(for action: LineActionKind) -> String {
        switch action {
        case .check: return "hand.raised.fill"
        case .call: return "arrow.down.left.circle.fill"
        case .bet: return "arrow.up.circle.fill"
        case .raise: return "arrow.up.right.circle.fill"
        case .fold: return "xmark.circle.fill"
        case .allIn: return "flame.fill"
        }
    }

    private func tint(for action: LineActionKind) -> Color {
        switch action {
        case .check: return AppColors.blue
        case .call: return AppColors.gold
        case .bet, .raise, .allIn: return AppColors.green
        case .fold: return AppColors.red
        }
    }
}

private struct ActionActorSelector: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("行动人")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    LineActorChip(
                        title: "我",
                        subtitle: viewModel.playerSeats.first?.position.displayName ?? "",
                        isSelected: viewModel.lineActor == .hero,
                        tint: AppColors.blue,
                        action: viewModel.selectHeroLineActor
                    )

                    if viewModel.selectedReviewOpponentSeats.isEmpty {
                        LineActorChip(
                            title: "对手",
                            subtitle: "未选",
                            isSelected: viewModel.lineActor == .opponent,
                            tint: AppColors.green,
                            action: viewModel.selectGenericOpponentLineActor
                        )
                    } else {
                        ForEach(viewModel.selectedReviewOpponentSeats) { seat in
                            LineActorChip(
                                title: seat.displayName,
                                subtitle: seat.position.displayName,
                                isSelected: viewModel.lineActor == .opponent && viewModel.lineOpponentSeatID == seat.id,
                                tint: AppColors.green
                            ) {
                                viewModel.selectOpponentLineActor(seatID: seat.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }
}

private struct LineActorChip: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .opacity(0.78)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? .white : tint)
            .padding(.horizontal, 10)
            .frame(minWidth: 78, minHeight: 42, alignment: .leading)
            .background(isSelected ? tint : tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ActionPotStrip: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        HStack(spacing: 8) {
            StatTile(title: "底池", value: amountText(viewModel.currentActionPotAmount), tint: AppColors.blue)
            StatTile(title: "加注到总额", value: lastRaiseText, tint: AppColors.green)
        }
    }

    private var lastRaiseText: String {
        guard let amount = viewModel.lastRaiseTotalAmount else { return "--" }
        return amountText(amount)
    }
}

private struct StreetMenu: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        Menu {
            ForEach(ActionStreet.allCases) { street in
                Button(street.displayName) {
                    viewModel.lineStreet = street
                }
            }
            Divider()
            Button("当前牌面") {
                viewModel.syncLineStreetToBoard()
            }
        } label: {
            Label(viewModel.lineStreet.displayName, systemImage: "square.stack.3d.up.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(AppColors.blue)
    }
}

private struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(isSelected ? .white : tint)
            .background(isSelected ? tint : tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ActionAmountRow: View {
    let title: String
    @Binding var value: Double
    let confirmAction: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            TrailingPointInputField(
                value: $value,
                font: .monospacedDigitSystemFont(ofSize: 20, weight: .bold),
                tint: AppColors.green,
                accessoryButtonTitle: "确认",
                accessoryAction: confirmAction
            )
            .frame(minWidth: 96, minHeight: 30)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AllInAmountRow: View {
    let title: String
    let actorName: String
    let amount: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(actorName) 手上所有积分")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(amountText(amount))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(AppColors.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ActionLineListPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "已录入", systemImage: "list.bullet")
                Spacer()
                if !viewModel.actionLineEntries.isEmpty {
                    Button(action: viewModel.removeLastActionLineEntry) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.blue)
                    .accessibilityLabel("撤销上一条")

                    Button(action: viewModel.clearActionLine) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.red)
                    .accessibilityLabel("清空行动线")
                }
            }

            if viewModel.actionLineEntries.isEmpty {
                Text("暂无行动")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.actionLineEntries.enumerated()), id: \.element.id) { index, entry in
                        ActionLineRow(
                            index: index + 1,
                            entry: entry
                        )
                    }
                }
            }
        }
        .panelStyle()
    }
}

private struct ActionLineRow: View {
    let index: Int
    let entry: ActionLineEntry

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(actorTint, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.street.shortName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.gold)
                        .frame(width: 24, height: 22)
                        .background(AppColors.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                    Text(entry.displayActorName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(actorTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(entry.action.displayName)
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 0)
                }

                let amount = entry.amountText()
                if !amount.isEmpty {
                    Text(amount)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var actorTint: Color {
        entry.actor == .hero ? AppColors.blue : AppColors.green
    }
}

private struct GTOActionPlanPanel: View {
    @ObservedObject var viewModel: PokerCalculatorViewModel

    private var plan: GTOActionPlan {
        viewModel.gtoActionPlan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "GTO 近似最优解", systemImage: "scope")
                Spacer()
                Text(plan.primaryAction)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(toneColor(plan.tone), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(plan.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(toneColor(plan.tone))

                Text(plan.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                StatTile(title: "主动作", value: plan.primaryAction, tint: toneColor(plan.tone))
                StatTile(title: "混合", value: plan.mixedAction ?? "--", tint: AppColors.blue)
            }

            HStack(spacing: 8) {
                StatTile(title: "频率", value: plan.frequencyText, tint: AppColors.gold)
                StatTile(title: "尺寸", value: plan.sizingText, tint: AppColors.green)
            }

            HStack(spacing: 8) {
                StatTile(title: "胜率", value: plan.equityText, tint: AppColors.green)
                StatTile(title: "所需赔率", value: plan.potOddsText, tint: AppColors.red)
            }

            if !plan.reasons.isEmpty {
                VStack(spacing: 8) {
                    ForEach(plan.reasons) { reason in
                        GTOReasonRow(reason: reason)
                    }
                }
            }

            Text("本地 GTO 近似基于牌力、胜率、位置、底池赔率和下注尺寸；不是完整 solver 解。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .panelStyle()
    }
}

private struct GTOReasonRow: View {
    let reason: ActionLineFinding

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(toneColor(reason.tone))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(reason.title)
                    .font(.subheadline.weight(.semibold))
                Text(reason.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(toneColor(reason.tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var iconName: String {
        switch reason.tone {
        case .attack: return "bolt.fill"
        case .continueHand: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .fold: return "xmark.circle.fill"
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PercentBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.disabledCard)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 9)
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(14)
            .background(AppColors.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            }
    }
}

private enum AppColors {
    static let pageBackground = Color(red: 0.016, green: 0.047, blue: 0.118)
    static let panelBackground = Color(red: 0.030, green: 0.086, blue: 0.168)
    static let cardBackground = Color(red: 0.043, green: 0.125, blue: 0.240)
    static let disabledCard = Color(red: 0.075, green: 0.160, blue: 0.280)
    static let border = Color(red: 0.520, green: 0.882, blue: 0.941).opacity(0.18)
    static let green = Color(red: 0.322, green: 0.886, blue: 0.961)
    static let blue = Color(red: 0.106, green: 0.459, blue: 1.000)
    static let red = Color(red: 1.000, green: 0.510, blue: 0.260)
    static let gold = Color(red: 0.956, green: 0.784, blue: 0.416)
}

private func amountText(_ value: Double) -> String {
    let numberText: String
    if value >= 100 {
        numberText = String(format: "%.0f", value)
    } else if abs(value.rounded() - value) < 0.05 {
        numberText = String(format: "%.0f", value)
    } else {
        numberText = String(format: "%.1f", value)
    }

    return "\(numberText) 积分"
}

private func percentText(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

private func toneColor(_ tone: RecommendationTone) -> Color {
    switch tone {
    case .attack:
        return AppColors.green
    case .continueHand:
        return AppColors.blue
    case .caution:
        return AppColors.gold
    case .fold:
        return AppColors.red
    }
}

#Preview {
    ContentView()
}
