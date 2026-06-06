import Foundation
import Combine
import SwiftUI

enum CardSlot: Hashable {
    case hero(Int)
    case player(Int, Int)
    case board(Int)

    var title: String {
        switch self {
        case .hero(let index):
            return "我的手牌 \(index + 1)"
        case .player(let seatID, let index):
            if seatID == 0 {
                return "我的手牌 \(index + 1)"
            }
            return "P\(seatID + 1) 手牌 \(index + 1)"
        case .board(let index):
            switch index {
            case 0: return "翻牌 1"
            case 1: return "翻牌 2"
            case 2: return "翻牌 3"
            case 3: return "转牌"
            default: return "河牌"
            }
        }
    }

    var shortTitle: String {
        switch self {
        case .hero(let index):
            return "H\(index + 1)"
        case .player(let seatID, let index):
            return seatID == 0 ? "H\(index + 1)" : "P\(seatID + 1)-\(index + 1)"
        case .board(let index):
            return ["F1", "F2", "F3", "T", "R"][index]
        }
    }
}

enum TablePosition: String, CaseIterable, Identifiable, Hashable {
    case underTheGun
    case underTheGunPlus1
    case middle
    case lojack
    case hijack
    case cutoff
    case button
    case smallBlind
    case bigBlind

    var id: String { rawValue }

    static let tableOrder: [TablePosition] = [
        .button,
        .smallBlind,
        .bigBlind,
        .underTheGun,
        .underTheGunPlus1,
        .middle,
        .lojack,
        .hijack,
        .cutoff
    ]

    var displayName: String {
        switch self {
        case .underTheGun: return "UTG"
        case .underTheGunPlus1: return "UTG+1"
        case .middle: return "MP"
        case .lojack: return "LJ"
        case .hijack: return "HJ"
        case .cutoff: return "CO"
        case .button: return "BTN"
        case .smallBlind: return "SB"
        case .bigBlind: return "BB"
        }
    }

    var detailName: String {
        switch self {
        case .underTheGun: return "枪口"
        case .underTheGunPlus1: return "枪口后"
        case .middle: return "中位"
        case .lojack: return "低劫位"
        case .hijack: return "劫位"
        case .cutoff: return "关煞"
        case .button: return "按钮"
        case .smallBlind: return "小盲"
        case .bigBlind: return "大盲"
        }
    }
}

struct PlayerSeat: Identifiable, Hashable {
    let id: Int
    var position: TablePosition
    var stackAmount: Double
    var cards: [Card?]

    var displayName: String {
        id == 0 ? "我" : "P\(id + 1)"
    }

    var completeCards: [Card]? {
        let visible = cards.compactMap { $0 }
        return visible.count == 2 ? visible : nil
    }

    var hasAnyCard: Bool {
        cards.contains { $0 != nil }
    }

    static let defaults: [PlayerSeat] = [
        PlayerSeat(id: 0, position: .button, stackAmount: 200, cards: [nil, nil]),
        PlayerSeat(id: 1, position: .smallBlind, stackAmount: 200, cards: [nil, nil]),
        PlayerSeat(id: 2, position: .bigBlind, stackAmount: 200, cards: [nil, nil]),
        PlayerSeat(id: 3, position: .underTheGun, stackAmount: 200, cards: [nil, nil]),
        PlayerSeat(id: 4, position: .underTheGunPlus1, stackAmount: 200, cards: [nil, nil]),
        PlayerSeat(id: 5, position: .middle, stackAmount: 200, cards: [nil, nil]),
        PlayerSeat(id: 6, position: .lojack, stackAmount: 200, cards: [nil, nil]),
        PlayerSeat(id: 7, position: .hijack, stackAmount: 200, cards: [nil, nil]),
        PlayerSeat(id: 8, position: .cutoff, stackAmount: 200, cards: [nil, nil])
    ]
}

@MainActor
final class PokerCalculatorViewModel: ObservableObject {
    @Published var playerSeats: [PlayerSeat] = PlayerSeat.defaults
    @Published var boardCards: [Card?] = [nil, nil, nil, nil, nil]
    @Published var selectedSlot: CardSlot = .player(0, 0)

    @Published var smallBlindAmount: Double = 1
    @Published var bigBlindAmount: Double = 2
    @Published var iterationCount: Double = 5_000

    @Published var lineStreet: ActionStreet = .preflop
    @Published var lineActor: ActionActor = .hero
    @Published var lineOpponentSeatID: Int?
    @Published var lineAction: LineActionKind = .bet
    @Published var lineAmount: Double = 2
    @Published var actionLineEntries: [ActionLineEntry] = []
    @Published var activeReviewOpponentIDs: Set<Int> = []

    @Published private(set) var result: EquityResult?
    @Published private(set) var isCalculating = false
    @Published private(set) var calculationProgress: Double = 0

    private var calculationTask: Task<Void, Never>?
    private var calculationRunID = UUID()

    var heroCards: [Card?] {
        playerSeats.first?.cards ?? [nil, nil]
    }

    var selectedCards: Set<Card> {
        let playerCards = playerSeats.flatMap { $0.cards.compactMap { $0 } }
        return Set(playerCards + boardCards.compactMap { $0 })
    }

    var heroCompleteCards: [Card]? {
        playerSeats.first?.completeCards
    }

    var knownOpponentHands: [[Card]] {
        liveReviewOpponentSeats.compactMap(\.completeCards)
    }

    var activeOpponentCount: Int {
        liveReviewOpponentCount
    }

    var activePlayerCount: Int {
        (heroCompleteCards == nil ? 0 : 1) + filledOpponentCount
    }

    var reviewCandidateSeats: [PlayerSeat] {
        Array(playerSeats.dropFirst())
    }

    var selectedReviewOpponentSeats: [PlayerSeat] {
        reviewCandidateSeats.filter { activeReviewOpponentIDs.contains($0.id) }
    }

    var liveReviewOpponentSeats: [PlayerSeat] {
        selectedReviewOpponentSeats.filter { !foldedReviewOpponentIDs.contains($0.id) }
    }

    var selectedReviewOpponentCount: Int {
        selectedReviewOpponentSeats.count
    }

    var liveReviewOpponentCount: Int {
        liveReviewOpponentSeats.count
    }

    var selectedIncompleteOpponentCount: Int {
        liveReviewOpponentSeats.filter { $0.completeCards == nil }.count
    }

    var filledOpponentCount: Int {
        reviewCandidateSeats.filter { $0.completeCards != nil }.count
    }

    var missingPlayerCardCount: Int {
        playerSeats.reduce(0) { partial, seat in
            partial + seat.cards.filter { $0 == nil }.count
        }
    }

    var canAutoDealPlayerCards: Bool {
        missingPlayerCardCount > 0 && availableCardsForAutoPlayerCards.count >= missingPlayerCardCount
    }

    var hasSelectedIncompleteOpponents: Bool {
        selectedIncompleteOpponentCount > 0
    }

    var foldedReviewOpponentIDs: Set<Int> {
        var latestActions: [Int: LineActionKind] = [:]
        for entry in actionLineEntries where entry.actor == .opponent {
            guard let seatID = entry.actorSeatID else { continue }
            latestActions[seatID] = entry.action
        }
        return Set(latestActions.compactMap { seatID, action in
            action == .fold ? seatID : nil
        })
    }

    var foldedReviewOpponentCount: Int {
        selectedReviewOpponentSeats.filter { foldedReviewOpponentIDs.contains($0.id) }.count
    }

    var foldedOpponentDeadCards: [Card] {
        selectedReviewOpponentSeats
            .filter { foldedReviewOpponentIDs.contains($0.id) }
            .flatMap { $0.completeCards ?? [] }
    }

    var heroHasFolded: Bool {
        actionLineEntries.last { $0.actor == .hero }?.action == .fold
    }

    var isShowdown: Bool {
        actionLineEntries.contains { isShowdownTrigger($0) }
    }

    var equityOpponentCountText: String {
        selectedReviewOpponentCount == 0 ? "0" : "\(liveReviewOpponentCount)/\(selectedReviewOpponentCount)"
    }

    var selectedLineActorName: String {
        if lineActor == .hero {
            return "我"
        }

        guard let lineOpponentSeatID,
              let seat = playerSeats.first(where: { $0.id == lineOpponentSeatID })
        else {
            return "对手"
        }

        return "\(seat.displayName)·\(seat.position.displayName)"
    }

    var boardVisibleCards: [Card] {
        boardCards.compactMap { $0 }
    }

    var streetName: String {
        switch boardVisibleCards.count {
        case 0: return "翻前"
        case 3: return "翻牌"
        case 4: return "转牌"
        case 5: return "河牌"
        default: return "待补齐公共牌"
        }
    }

    var boardAutoDealTitle: String {
        switch boardVisibleCards.count {
        case 0...2:
            return "发翻牌"
        case 3:
            return "发转牌"
        case 4:
            return "发河牌"
        default:
            return "重发"
        }
    }

    var canAutoDealBoardCards: Bool {
        autoBoardDealNeededCount > 0 && availableCardsForAutoBoard.count >= autoBoardDealNeededCount
    }

    var startingHand: StartingHand? {
        guard let heroCompleteCards else { return nil }
        return StartingHand(heroCompleteCards[0], heroCompleteCards[1])
    }

    var madeHand: EvaluatedHand? {
        guard let heroCompleteCards else { return nil }
        return PokerHandEvaluator.evaluateIfPossible(heroCompleteCards + boardVisibleCards)
    }

    var drawTexts: [String] {
        guard let heroCompleteCards else { return [] }
        return DrawAnalyzer.drawTexts(heroCards: heroCompleteCards, boardCards: boardVisibleCards)
    }

    var currentActionStreet: ActionStreet {
        ActionStreet.current(boardCardCount: boardVisibleCards.count)
    }

    var blindPotAmount: Double {
        max(0, smallBlindAmount) + max(0.01, bigBlindAmount)
    }

    var currentActionPotAmount: Double {
        actionLineEntries.reduce(blindPotAmount) { partial, entry in
            partial + max(0, entry.amount ?? 0)
        }
    }

    var previewActionPotAmount: Double {
        currentActionPotAmount + (lineAction.needsAmount ? max(0, committedLineAmount) : 0)
    }

    var lastRaiseTotalAmount: Double? {
        actionLineEntries.reversed().first { entry in
            entry.action == .raise || entry.action == .allIn
        }?.amount
    }

    var callMatchAmount: Double {
        actionLineEntries.reversed().first { entry in
            (entry.action == .bet || entry.action == .raise || entry.action == .allIn)
                && (entry.amount ?? 0) > 0
        }?.amount ?? max(0.01, bigBlindAmount)
    }

    var lineAmountTitle: String {
        switch lineAction {
        case .raise: return "加注到总额"
        case .allIn: return "全下积分"
        case .call: return "跟注积分"
        case .bet: return "下注积分"
        case .check, .fold: return "积分"
        }
    }

    var currentLineAmount: Double {
        lineAction == .allIn ? selectedLineActorStackAmount : lineAmount
    }

    var selectedLineActorStackAmount: Double {
        selectedLineActorSeat?.stackAmount ?? 0
    }

    var calculationProgressText: String {
        "\(Int((calculationProgress * 100).rounded()))%"
    }

    var currentActionSeatOrderIDs: [Int] {
        actionSeatIDs(for: lineStreet)
    }

    var gtoActionPlan: GTOActionPlan {
        GTOActionPlanner.plan(
            entries: actionLineEntries,
            startingHand: startingHand,
            madeHand: madeHand,
            draws: drawTexts,
            equity: result?.equity,
            position: heroPokerPosition,
            boardCardCount: boardVisibleCards.count,
            currentPot: currentActionPotAmount,
            bigBlind: bigBlindAmount,
            heroStack: playerSeats.first?.stackAmount ?? 0
        )
    }

    var canCalculate: Bool {
        heroCompleteCards != nil
            && selectedReviewOpponentCount > 0
            && liveReviewOpponentCount == knownOpponentHands.count
            && !heroHasFolded
            && boardVisibleCards.count != 1
            && boardVisibleCards.count != 2
    }

    var calculationStatusText: String {
        if heroCompleteCards == nil {
            return "先录入我的两张手牌"
        }

        if selectedReviewOpponentCount == 0 {
            return "复盘页先选择至少一名入池对手"
        }

        if heroHasFolded {
            return "行动线里我已弃牌，本手已结束"
        }

        if hasSelectedIncompleteOpponents {
            return "未弃牌的入池对手需要补齐两张手牌"
        }

        if boardVisibleCards.count == 1 || boardVisibleCards.count == 2 {
            return "公共牌需为空、3 张、4 张或 5 张"
        }

        return "可以计算胜率"
    }

    func selectSlot(_ slot: CardSlot) {
        selectedSlot = normalized(slot)
    }

    func card(for slot: CardSlot) -> Card? {
        switch normalized(slot) {
        case .hero(let index):
            return playerCard(seatID: 0, cardIndex: index)
        case .player(let seatID, let cardIndex):
            return playerCard(seatID: seatID, cardIndex: cardIndex)
        case .board(let index):
            guard boardCards.indices.contains(index) else { return nil }
            return boardCards[index]
        }
    }

    func assignCard(_ card: Card) {
        if selectedCards.contains(card), self.card(for: selectedSlot) != card {
            return
        }

        setCard(card, for: selectedSlot)
        advanceSelectedSlot(after: selectedSlot)
        result = nil
    }

    func clearSlot(_ slot: CardSlot) {
        setCard(nil, for: slot)
        selectedSlot = normalized(slot)
        result = nil
    }

    func autoDealBoardCards() {
        guard canAutoDealBoardCards else { return }

        if boardVisibleCards.count >= 5 {
            boardCards = [nil, nil, nil, nil, nil]
        }

        var availableCards = availableCardsForAutoBoard
        var visibleCount = boardVisibleCards.count
        let targetCount = nextBoardTargetCount(from: visibleCount)

        for index in boardCards.indices where boardCards[index] == nil && visibleCount < targetCount {
            guard let randomIndex = availableCards.indices.randomElement() else { break }
            boardCards[index] = availableCards.remove(at: randomIndex)
            visibleCount += 1
        }

        if let firstEmptyIndex = boardCards.firstIndex(where: { $0 == nil }) {
            selectedSlot = .board(firstEmptyIndex)
        } else {
            selectedSlot = .board(boardCards.index(before: boardCards.endIndex))
        }

        syncLineStreetToBoard()
        result = nil
    }

    func autoDealPlayerCards() {
        guard canAutoDealPlayerCards else { return }

        dealMissingPlayerCards(for: Set(playerSeats.map(\.id)))

        if let firstEmptySeat = playerSeats.first(where: { $0.cards.contains(where: { $0 == nil }) }),
           let firstEmptyCardIndex = firstEmptySeat.cards.firstIndex(where: { $0 == nil }) {
            selectedSlot = .player(firstEmptySeat.id, firstEmptyCardIndex)
        } else {
            selectedSlot = .board(0)
        }

        result = nil
    }

    func openShowdownCards() {
        dealMissingPlayerCards(for: showdownSeatIDs)
        result = nil
    }

    func clearAll() {
        calculationTask?.cancel()
        calculationRunID = UUID()
        playerSeats = PlayerSeat.defaults
        boardCards = [nil, nil, nil, nil, nil]
        selectedSlot = .player(0, 0)
        actionLineEntries = []
        activeReviewOpponentIDs = []
        lineStreet = .preflop
        lineActor = .hero
        lineOpponentSeatID = nil
        lineAction = .bet
        lineAmount = max(0.01, bigBlindAmount)
        result = nil
        isCalculating = false
        calculationProgress = 0
    }

    func updateSeatPosition(seatID: Int, to position: TablePosition) {
        guard let seatIndex = playerSeats.firstIndex(where: { $0.id == seatID }) else { return }
        playerSeats[seatIndex].position = position

        if seatID == 0 {
            updatePositionsAfterHeroChange(position)
        }
    }

    func syncLineStreetToBoard() {
        lineStreet = currentActionStreet
    }

    func isReviewOpponentSelected(_ seatID: Int) -> Bool {
        activeReviewOpponentIDs.contains(seatID)
    }

    func isSeatInPot(_ seatID: Int) -> Bool {
        seatID == 0 || activeReviewOpponentIDs.contains(seatID)
    }

    func isSeatFolded(_ seatID: Int) -> Bool {
        if seatID == 0 {
            return heroHasFolded
        }
        return foldedReviewOpponentIDs.contains(seatID)
    }

    func lastActionEntry(for seatID: Int) -> ActionLineEntry? {
        actionLineEntries.last { actionEntry($0, matchesSeatID: seatID) }
    }

    func latestActionNumber(for seatID: Int) -> Int? {
        actionLineEntries.enumerated().reversed().first { _, entry in
            actionEntry(entry, matchesSeatID: seatID)
        }?.offset.advanced(by: 1)
    }

    func toggleReviewOpponent(_ seatID: Int) {
        if activeReviewOpponentIDs.contains(seatID) {
            activeReviewOpponentIDs.remove(seatID)
            if lineOpponentSeatID == seatID {
                lineOpponentSeatID = selectedReviewOpponentSeats.first?.id
                if lineOpponentSeatID == nil, lineActor == .opponent {
                    lineActor = .hero
                }
            }
        } else {
            activeReviewOpponentIDs.insert(seatID)
            if lineActor == .opponent, lineOpponentSeatID == nil {
                lineOpponentSeatID = seatID
            }
        }
        result = nil
    }

    func selectHeroLineActor() {
        lineActor = .hero
        lineOpponentSeatID = nil
        syncAllInAmountIfNeeded()
    }

    func selectOpponentLineActor(seatID: Int) {
        lineActor = .opponent
        lineOpponentSeatID = seatID
        syncAllInAmountIfNeeded()
    }

    func selectGenericOpponentLineActor() {
        lineActor = .opponent
        lineOpponentSeatID = selectedReviewOpponentSeats.first?.id
        syncAllInAmountIfNeeded()
    }

    func selectLineAction(_ action: LineActionKind) {
        lineAction = action
        if action.needsAmount {
            lineAmount = defaultLineAmount(for: action)
        } else {
            lineAmount = 0
            addActionLineEntry()
        }
    }

    func addActionLineEntry() {
        let actedSeatID = currentLineActorSeatID
        let amount = lineAction.needsAmount ? committedLineAmount : nil
        let entry = ActionLineEntry(
            street: lineStreet,
            actor: lineActor,
            action: lineAction,
            amount: amount,
            actorSeatID: lineActor == .opponent ? lineOpponentSeatID : nil,
            actorName: selectedLineActorName
        )
        actionLineEntries.append(entry)
        result = nil

        if isShowdownTrigger(entry) {
            openShowdownCards()
        } else {
            advanceLineActorAfterAction(from: actedSeatID)
        }

        if lineAction.needsAmount {
            lineAmount = defaultLineAmount(for: lineAction)
        }
    }

    func removeLastActionLineEntry() {
        guard !actionLineEntries.isEmpty else { return }
        actionLineEntries.removeLast()
        result = nil
    }

    func clearActionLine() {
        actionLineEntries = []
        result = nil
    }

    func calculate() {
        guard let heroCompleteCards, canCalculate, !isCalculating else { return }
        calculationTask?.cancel()
        let runID = UUID()
        calculationRunID = runID
        isCalculating = true
        calculationProgress = 0
        result = nil

        let input = TableEquityInput(
            heroCards: heroCompleteCards,
            opponentHands: knownOpponentHands,
            boardCards: boardVisibleCards,
            iterations: Int(iterationCount),
            deadCards: foldedOpponentDeadCards
        )

        calculationTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let output = await TableEquityCalculator.calculate(input: input) { [weak self] progress in
                guard let self, self.isCalculating, self.calculationRunID == runID else { return }
                self.calculationProgress = min(max(progress, 0), 1)
            }

            guard !Task.isCancelled, self.isCalculating, self.calculationRunID == runID else { return }
            self.result = output
            self.calculationProgress = 1
            self.isCalculating = false
        }
    }

    deinit {
        calculationTask?.cancel()
    }

    private func normalized(_ slot: CardSlot) -> CardSlot {
        switch slot {
        case .hero(let index):
            return .player(0, index)
        case .player, .board:
            return slot
        }
    }

    private func actionEntry(_ entry: ActionLineEntry, matchesSeatID seatID: Int) -> Bool {
        if seatID == 0 {
            return entry.actor == .hero
        }

        return entry.actor == .opponent && entry.actorSeatID == seatID
    }

    private var showdownSeatIDs: Set<Int> {
        Set(playerSeats.compactMap { seat in
            isSeatInPot(seat.id) && !isSeatFolded(seat.id) ? seat.id : nil
        })
    }

    private func isShowdownTrigger(_ entry: ActionLineEntry) -> Bool {
        entry.action == .allIn || (entry.street == .river && entry.action == .call)
    }

    @discardableResult
    private func dealMissingPlayerCards(for seatIDs: Set<Int>) -> Int {
        var availableCards = availableCardsForAutoPlayerCards
        var dealtCount = 0

        for seatIndex in playerSeats.indices where seatIDs.contains(playerSeats[seatIndex].id) {
            for cardIndex in playerSeats[seatIndex].cards.indices where playerSeats[seatIndex].cards[cardIndex] == nil {
                guard let randomIndex = availableCards.indices.randomElement() else { return dealtCount }
                playerSeats[seatIndex].cards[cardIndex] = availableCards.remove(at: randomIndex)
                dealtCount += 1
            }
        }

        return dealtCount
    }

    private var currentLineActorSeatID: Int? {
        if lineActor == .hero {
            return 0
        }

        return lineOpponentSeatID
    }

    private func advanceLineActorAfterAction(from actedSeatID: Int?) {
        let orderedSeatIDs = actionSeatIDs(for: lineStreet)

        guard orderedSeatIDs.count > 1 else {
            if selectedReviewOpponentCount == 0 {
                advanceLineActorWithFallback()
            } else if let onlySeatID = orderedSeatIDs.first {
                selectLineActor(seatID: onlySeatID)
            } else {
                advanceLineActorWithFallback()
            }
            return
        }

        guard let actedSeatID else {
            selectLineActor(seatID: orderedSeatIDs[0])
            return
        }

        guard let actedIndex = orderedSeatIDs.firstIndex(of: actedSeatID) else {
            advanceLineActorFromRemovedSeat(actedSeatID, availableSeatIDs: orderedSeatIDs)
            return
        }

        let nextIndex = orderedSeatIDs.index(after: actedIndex) == orderedSeatIDs.endIndex
            ? orderedSeatIDs.startIndex
            : orderedSeatIDs.index(after: actedIndex)
        selectLineActor(seatID: orderedSeatIDs[nextIndex])
    }

    private func advanceLineActorFromRemovedSeat(_ actedSeatID: Int, availableSeatIDs: [Int]) {
        let orderedSeatIDs = actionSeatIDs(for: lineStreet, including: actedSeatID)
        guard let actedIndex = orderedSeatIDs.firstIndex(of: actedSeatID) else {
            selectLineActor(seatID: availableSeatIDs[0])
            return
        }

        for offset in 1...orderedSeatIDs.count {
            let candidateIndex = (actedIndex + offset) % orderedSeatIDs.count
            let candidateSeatID = orderedSeatIDs[candidateIndex]
            if availableSeatIDs.contains(candidateSeatID) {
                selectLineActor(seatID: candidateSeatID)
                return
            }
        }

        selectLineActor(seatID: availableSeatIDs[0])
    }

    private func advanceLineActorWithFallback() {
        if lineActor == .hero {
            lineActor = .opponent
            lineOpponentSeatID = selectedReviewOpponentSeats.first?.id
        } else {
            lineActor = .hero
            lineOpponentSeatID = nil
        }
        syncAllInAmountIfNeeded()
    }

    private func selectLineActor(seatID: Int) {
        if seatID == 0 {
            lineActor = .hero
            lineOpponentSeatID = nil
        } else {
            lineActor = .opponent
            lineOpponentSeatID = seatID
        }
        syncAllInAmountIfNeeded()
    }

    private func actionSeatIDs(for street: ActionStreet, including includedSeatID: Int? = nil) -> [Int] {
        let positionOrder = actionPositionOrder(for: street)
        return playerSeats
            .filter { seat in
                (isSeatInPot(seat.id) && !isSeatFolded(seat.id)) || seat.id == includedSeatID
            }
            .sorted { leftSeat, rightSeat in
                let leftIndex = positionOrder.firstIndex(of: leftSeat.position) ?? positionOrder.endIndex
                let rightIndex = positionOrder.firstIndex(of: rightSeat.position) ?? positionOrder.endIndex

                if leftIndex != rightIndex {
                    return leftIndex < rightIndex
                }

                return leftSeat.id < rightSeat.id
            }
            .map(\.id)
    }

    private func actionPositionOrder(for street: ActionStreet) -> [TablePosition] {
        switch street {
        case .preflop:
            return [
                .underTheGun,
                .underTheGunPlus1,
                .middle,
                .lojack,
                .hijack,
                .cutoff,
                .button,
                .smallBlind,
                .bigBlind
            ]
        case .flop, .turn, .river:
            return [
                .smallBlind,
                .bigBlind,
                .underTheGun,
                .underTheGunPlus1,
                .middle,
                .lojack,
                .hijack,
                .cutoff,
                .button
            ]
        }
    }

    private var autoBoardDealNeededCount: Int {
        let visibleCount = boardVisibleCards.count
        let currentCount = visibleCount >= 5 ? 0 : visibleCount
        return max(0, nextBoardTargetCount(from: visibleCount) - currentCount)
    }

    private var availableCardsForAutoBoard: [Card] {
        let usedCards: Set<Card>
        if boardVisibleCards.count >= 5 {
            usedCards = Set(playerSeats.flatMap { $0.cards.compactMap { $0 } })
        } else {
            usedCards = selectedCards
        }

        return Card.fullDeck.filter { !usedCards.contains($0) }
    }

    private var availableCardsForAutoPlayerCards: [Card] {
        Card.fullDeck.filter { !selectedCards.contains($0) }
    }

    private func nextBoardTargetCount(from visibleCount: Int) -> Int {
        switch visibleCount {
        case 0...2:
            return 3
        case 3:
            return 4
        case 4:
            return 5
        default:
            return 3
        }
    }

    private func playerCard(seatID: Int, cardIndex: Int) -> Card? {
        guard let seatIndex = playerSeats.firstIndex(where: { $0.id == seatID }),
              playerSeats[seatIndex].cards.indices.contains(cardIndex)
        else { return nil }
        return playerSeats[seatIndex].cards[cardIndex]
    }

    private func setCard(_ card: Card?, for slot: CardSlot) {
        switch normalized(slot) {
        case .hero(let index):
            setPlayerCard(card, seatID: 0, cardIndex: index)
        case .player(let seatID, let cardIndex):
            setPlayerCard(card, seatID: seatID, cardIndex: cardIndex)
        case .board(let index):
            guard boardCards.indices.contains(index) else { return }
            boardCards[index] = card
        }
    }

    private func setPlayerCard(_ card: Card?, seatID: Int, cardIndex: Int) {
        guard let seatIndex = playerSeats.firstIndex(where: { $0.id == seatID }),
              playerSeats[seatIndex].cards.indices.contains(cardIndex)
        else { return }
        playerSeats[seatIndex].cards[cardIndex] = card
    }

    private func updatePositionsAfterHeroChange(_ heroPosition: TablePosition) {
        guard let heroOrderIndex = TablePosition.tableOrder.firstIndex(of: heroPosition) else { return }

        for seatIndex in playerSeats.indices where playerSeats[seatIndex].id != 0 {
            let offset = playerSeats[seatIndex].id
            let positionIndex = (heroOrderIndex + offset) % TablePosition.tableOrder.count
            playerSeats[seatIndex].position = TablePosition.tableOrder[positionIndex]
        }
    }

    private func defaultLineAmount(for action: LineActionKind) -> Double {
        switch action {
        case .call:
            return callMatchAmount
        case .allIn:
            return max(0.01, selectedLineActorStackAmount)
        case .bet, .raise:
            return max(lineAmount, max(0.01, bigBlindAmount))
        case .check, .fold:
            return 0
        }
    }

    private var selectedLineActorSeat: PlayerSeat? {
        if lineActor == .hero {
            return playerSeats.first
        }

        if let lineOpponentSeatID,
           let seat = playerSeats.first(where: { $0.id == lineOpponentSeatID }) {
            return seat
        }

        return selectedReviewOpponentSeats.first ?? playerSeats.dropFirst().first
    }

    private var heroPokerPosition: PokerPosition {
        switch playerSeats.first?.position ?? .button {
        case .underTheGun, .underTheGunPlus1:
            return .underTheGun
        case .middle, .lojack, .hijack:
            return .middle
        case .cutoff:
            return .cutoff
        case .button:
            return .button
        case .smallBlind:
            return .smallBlind
        case .bigBlind:
            return .bigBlind
        }
    }

    private var committedLineAmount: Double {
        if lineAction == .allIn {
            return max(0, selectedLineActorStackAmount)
        }

        return max(0.01, lineAmount)
    }

    private func syncAllInAmountIfNeeded() {
        if lineAction == .allIn {
            lineAmount = defaultLineAmount(for: .allIn)
        }
    }

    private func advanceSelectedSlot(after slot: CardSlot) {
        switch normalized(slot) {
        case .hero:
            selectedSlot = .player(0, 1)
        case .player(let seatID, let cardIndex):
            if cardIndex == 0, playerCard(seatID: seatID, cardIndex: 1) == nil {
                selectedSlot = .player(seatID, 1)
                return
            }

            if let nextSeat = playerSeats.first(where: { $0.id == seatID + 1 }) {
                selectedSlot = .player(nextSeat.id, 0)
                return
            }

            selectedSlot = .board(0)

        case .board(let index):
            if index < boardCards.index(before: boardCards.endIndex) {
                selectedSlot = .board(index + 1)
            }
        }
    }
}
