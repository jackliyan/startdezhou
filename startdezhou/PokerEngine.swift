import Foundation

enum Suit: String, CaseIterable, Identifiable, Codable, Hashable {
    case spades
    case hearts
    case diamonds
    case clubs

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    var displayName: String {
        switch self {
        case .spades: return "黑桃"
        case .hearts: return "红桃"
        case .diamonds: return "方块"
        case .clubs: return "梅花"
        }
    }

    var isRed: Bool {
        self == .hearts || self == .diamonds
    }
}

enum Rank: Int, CaseIterable, Identifiable, Codable, Hashable, Comparable {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9
    case ten = 10
    case jack = 11
    case queen = 12
    case king = 13
    case ace = 14

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "T"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }

    var displayName: String {
        switch self {
        case .ten: return "10"
        default: return symbol
        }
    }

    static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static let descending: [Rank] = Array(Rank.allCases.reversed())
}

struct Card: Identifiable, Hashable, Codable, Comparable, CustomStringConvertible {
    let rank: Rank
    let suit: Suit

    var id: String { rank.symbol + suit.symbol }
    var description: String { id }

    static let fullDeck: [Card] = Suit.allCases.flatMap { suit in
        Rank.descending.map { rank in
            Card(rank: rank, suit: suit)
        }
    }

    static func < (lhs: Card, rhs: Card) -> Bool {
        if lhs.rank != rhs.rank {
            return lhs.rank < rhs.rank
        }
        return lhs.suit.rawValue < rhs.suit.rawValue
    }
}

enum PokerHandCategory: Int, CaseIterable, Comparable {
    case highCard = 0
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush

    var displayName: String {
        switch self {
        case .highCard: return "高牌"
        case .onePair: return "一对"
        case .twoPair: return "两对"
        case .threeOfAKind: return "三条"
        case .straight: return "顺子"
        case .flush: return "同花"
        case .fullHouse: return "葫芦"
        case .fourOfAKind: return "四条"
        case .straightFlush: return "同花顺"
        }
    }

    var strengthText: String {
        switch self {
        case .highCard: return "弱成牌"
        case .onePair: return "边缘成牌"
        case .twoPair, .threeOfAKind: return "中强牌"
        case .straight, .flush, .fullHouse: return "强牌"
        case .fourOfAKind, .straightFlush: return "超强牌"
        }
    }

    static func < (lhs: PokerHandCategory, rhs: PokerHandCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct EvaluatedHand: Comparable, Equatable {
    let category: PokerHandCategory
    let kickers: [Int]
    let cards: [Card]

    var displayName: String {
        if category == .straightFlush, kickers.first == Rank.ace.rawValue {
            return "皇家同花顺"
        }
        return category.displayName
    }

    var kickerText: String {
        kickers.compactMap { Rank(rawValue: $0)?.symbol }.joined(separator: " ")
    }

    static func == (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        lhs.category == rhs.category && lhs.kickers == rhs.kickers
    }

    static func < (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        if lhs.category != rhs.category {
            return lhs.category < rhs.category
        }

        for (left, right) in zip(lhs.kickers, rhs.kickers) where left != right {
            return left < right
        }

        return lhs.kickers.count < rhs.kickers.count
    }
}

enum PokerHandEvaluator {
    static func evaluateIfPossible(_ cards: [Card]) -> EvaluatedHand? {
        guard cards.count >= 5 else { return nil }
        return evaluate(cards)
    }

    static func evaluate(_ cards: [Card]) -> EvaluatedHand {
        precondition(cards.count >= 5, "At least five cards are required.")

        var best: EvaluatedHand?
        for combination in fiveCardCombinations(cards) {
            let value = evaluateFiveCards(combination)
            if best == nil || value > best! {
                best = value
            }
        }
        return best!
    }

    private static func fiveCardCombinations(_ cards: [Card]) -> [[Card]] {
        let count = cards.count
        guard count > 5 else { return [cards] }

        var combinations: [[Card]] = []
        for a in 0..<(count - 4) {
            for b in (a + 1)..<(count - 3) {
                for c in (b + 1)..<(count - 2) {
                    for d in (c + 1)..<(count - 1) {
                        for e in (d + 1)..<count {
                            combinations.append([cards[a], cards[b], cards[c], cards[d], cards[e]])
                        }
                    }
                }
            }
        }
        return combinations
    }

    private static func evaluateFiveCards(_ cards: [Card]) -> EvaluatedHand {
        let ranks = cards.map(\.rank.rawValue).sorted(by: >)
        let isFlush = Set(cards.map(\.suit)).count == 1
        let straightHigh = straightHighCard(in: ranks)

        if isFlush, let straightHigh {
            return EvaluatedHand(category: .straightFlush, kickers: [straightHigh], cards: cards)
        }

        let groups = rankGroups(from: cards)

        if groups[0].count == 4 {
            let kicker = groups.first { $0.count == 1 }!.rank
            return EvaluatedHand(category: .fourOfAKind, kickers: [groups[0].rank, kicker], cards: cards)
        }

        if groups[0].count == 3, groups.count > 1, groups[1].count == 2 {
            return EvaluatedHand(category: .fullHouse, kickers: [groups[0].rank, groups[1].rank], cards: cards)
        }

        if isFlush {
            return EvaluatedHand(category: .flush, kickers: ranks, cards: cards)
        }

        if let straightHigh {
            return EvaluatedHand(category: .straight, kickers: [straightHigh], cards: cards)
        }

        if groups[0].count == 3 {
            let kickers = groups.filter { $0.count == 1 }.map(\.rank).sorted(by: >)
            return EvaluatedHand(category: .threeOfAKind, kickers: [groups[0].rank] + kickers, cards: cards)
        }

        if groups[0].count == 2, groups.count > 1, groups[1].count == 2 {
            let pairs = groups.filter { $0.count == 2 }.map(\.rank).sorted(by: >)
            let kicker = groups.first { $0.count == 1 }!.rank
            return EvaluatedHand(category: .twoPair, kickers: pairs + [kicker], cards: cards)
        }

        if groups[0].count == 2 {
            let kickers = groups.filter { $0.count == 1 }.map(\.rank).sorted(by: >)
            return EvaluatedHand(category: .onePair, kickers: [groups[0].rank] + kickers, cards: cards)
        }

        return EvaluatedHand(category: .highCard, kickers: ranks, cards: cards)
    }

    private static func rankGroups(from cards: [Card]) -> [(rank: Int, count: Int)] {
        Dictionary(grouping: cards, by: { $0.rank.rawValue })
            .map { (rank: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.rank > $1.rank
            }
    }

    private static func straightHighCard(in ranks: [Int]) -> Int? {
        var unique = Array(Set(ranks)).sorted(by: >)
        if unique.contains(Rank.ace.rawValue) {
            unique.append(1)
        }

        guard unique.count >= 5 else { return nil }

        for start in 0...(unique.count - 5) {
            let window = Array(unique[start..<(start + 5)])
            if window[0] - window[4] == 4, Set(window).count == 5 {
                return window[0] == 1 ? Rank.five.rawValue : window[0]
            }
        }
        return nil
    }
}

struct StartingHand: Hashable, Identifiable {
    let high: Rank
    let low: Rank
    let isSuited: Bool

    var id: String { code }
    var isPair: Bool { high == low }

    var code: String {
        if isPair {
            return high.symbol + low.symbol
        }
        return high.symbol + low.symbol + (isSuited ? "s" : "o")
    }

    init(_ first: Card, _ second: Card) {
        if first.rank >= second.rank {
            high = first.rank
            low = second.rank
        } else {
            high = second.rank
            low = first.rank
        }
        isSuited = first.rank != second.rank && first.suit == second.suit
    }

    init(high: Rank, low: Rank, suited: Bool) {
        precondition(high >= low, "Starting hands should be normalized high-to-low.")
        self.high = high
        self.low = low
        isSuited = high != low && suited
    }
}

struct HandStrengthSnapshot {
    let title: String
    let detail: String
    let score: Double
}

enum PreflopAnalyzer {
    static let allStartingHands: [StartingHand] = {
        var hands: [StartingHand] = []
        for highIndex in Rank.descending.indices {
            for lowIndex in highIndex..<Rank.descending.count {
                let high = Rank.descending[highIndex]
                let low = Rank.descending[lowIndex]
                if high == low {
                    hands.append(StartingHand(high: high, low: low, suited: false))
                } else {
                    hands.append(StartingHand(high: high, low: low, suited: true))
                    hands.append(StartingHand(high: high, low: low, suited: false))
                }
            }
        }
        return hands
    }()

    static let rankedStartingHands: [StartingHand] = {
        allStartingHands.sorted {
            let leftScore = score($0)
            let rightScore = score($1)
            if leftScore != rightScore {
                return leftScore > rightScore
            }
            return tieBreaker($0) > tieBreaker($1)
        }
    }()

    static func score(_ hand: StartingHand) -> Double {
        let highScore = baseRankScore(hand.high)
        var score = highScore

        if hand.isPair {
            score = max(5, highScore * 2)
        }

        if hand.isSuited {
            score += 2
        }

        if !hand.isPair {
            let gap = hand.high.rawValue - hand.low.rawValue - 1
            switch gap {
            case 0:
                break
            case 1:
                score -= 1
            case 2:
                score -= 2
            case 3:
                score -= 4
            default:
                score -= 5
            }

            if gap <= 1, hand.high.rawValue < Rank.queen.rawValue {
                score += 1
            }

            if hand.high.rawValue >= Rank.jack.rawValue, hand.low.rawValue >= Rank.ten.rawValue {
                score += 1
            }
        }

        return max(0, (score * 10).rounded() / 10)
    }

    static func strengthSnapshot(for hand: StartingHand) -> HandStrengthSnapshot {
        let value = score(hand)
        switch value {
        case 16...:
            return HandStrengthSnapshot(title: "顶级起手牌", detail: "适合主动扩大底池", score: value)
        case 11..<16:
            return HandStrengthSnapshot(title: "强起手牌", detail: "多数位置可主动入池", score: value)
        case 7..<11:
            return HandStrengthSnapshot(title: "可玩牌", detail: "重视位置与前序动作", score: value)
        case 4..<7:
            return HandStrengthSnapshot(title: "投机牌", detail: "更适合深积分和后位", score: value)
        default:
            return HandStrengthSnapshot(title: "边缘牌", detail: "通常需要弃牌或特殊局面", score: value)
        }
    }

    static func rangeSet(percent: Double) -> Set<StartingHand> {
        let take = rangeCount(for: percent)
        return Set(rankedStartingHands.prefix(take))
    }

    static func topHandCodes(percent: Double, limit: Int) -> [String] {
        let take = min(rangeCount(for: percent), rankedStartingHands.count)
        return rankedStartingHands.prefix(take).prefix(limit).map(\.code)
    }

    static func contains(_ hand: StartingHand, inTopPercent percent: Double) -> Bool {
        rangeSet(percent: percent).contains(hand)
    }

    static func matrixHand(row: Rank, column: Rank) -> StartingHand {
        if row == column {
            return StartingHand(high: row, low: column, suited: false)
        }

        if row > column {
            return StartingHand(high: row, low: column, suited: true)
        }

        return StartingHand(high: column, low: row, suited: false)
    }

    private static func rangeCount(for percent: Double) -> Int {
        let clamped = min(100, max(0, percent))
        guard clamped > 0 else { return 0 }
        return min(rankedStartingHands.count, max(1, Int(ceil(Double(rankedStartingHands.count) * clamped / 100))))
    }

    private static func baseRankScore(_ rank: Rank) -> Double {
        switch rank {
        case .ace: return 10
        case .king: return 8
        case .queen: return 7
        case .jack: return 6
        case .ten: return 5
        case .nine: return 4.5
        case .eight: return 4
        case .seven: return 3.5
        case .six: return 3
        case .five: return 2.5
        case .four: return 2
        case .three: return 1.5
        case .two: return 1
        }
    }

    private static func tieBreaker(_ hand: StartingHand) -> Int {
        var value = hand.high.rawValue * 100 + hand.low.rawValue
        if hand.isPair { value += 10_000 }
        if hand.isSuited { value += 1_000 }
        return value
    }
}

enum PokerPosition: String, CaseIterable, Identifiable {
    case underTheGun
    case middle
    case cutoff
    case button
    case smallBlind
    case bigBlind

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .underTheGun: return "UTG"
        case .middle: return "MP"
        case .cutoff: return "CO"
        case .button: return "BTN"
        case .smallBlind: return "SB"
        case .bigBlind: return "BB"
        }
    }

    var detailName: String {
        switch self {
        case .underTheGun: return "枪口位"
        case .middle: return "中位"
        case .cutoff: return "关煞位"
        case .button: return "按钮位"
        case .smallBlind: return "小盲"
        case .bigBlind: return "大盲"
        }
    }
}

enum BettingAction: String, CaseIterable, Identifiable {
    case openRaise
    case callOpen
    case threeBet
    case fourBet
    case continuationBet
    case allIn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openRaise: return "开池"
        case .callOpen: return "跟注"
        case .threeBet: return "3Bet"
        case .fourBet: return "4Bet"
        case .continuationBet: return "C-Bet"
        case .allIn: return "全下"
        }
    }

    var fullName: String {
        switch self {
        case .openRaise: return "开池加注范围"
        case .callOpen: return "面对开池跟注范围"
        case .threeBet: return "再加注范围"
        case .fourBet: return "4Bet 范围"
        case .continuationBet: return "持续下注画像"
        case .allIn: return "全下范围"
        }
    }
}

enum OpponentStyle: String, CaseIterable, Identifiable {
    case tight
    case standard
    case loose
    case splashy
    case any

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tight: return "紧"
        case .standard: return "标准"
        case .loose: return "松"
        case .splashy: return "很松"
        case .any: return "任意"
        }
    }

    var multiplier: Double {
        switch self {
        case .tight: return 0.7
        case .standard: return 1
        case .loose: return 1.35
        case .splashy: return 1.8
        case .any: return 100
        }
    }
}

enum RecommendationTone: Hashable {
    case attack
    case continueHand
    case caution
    case fold
}

struct ActionRecommendation {
    let title: String
    let detail: String
    let tone: RecommendationTone
}

struct BetSizingAdvice {
    let title: String
    var amountLabel: String = "积分"
    let amount: Double
    let bbMultiple: Double
    var potAmount: Double = 0
    var finalPotAmount: Double = 0
    let amountText: String
    let detail: String
    let tone: RecommendationTone
    let bbText: String
}

enum BetSizingAdvisor {
    static func advice(
        smallBlind: Double,
        bigBlind: Double,
        currentPot: Double,
        effectiveStackBB: Double,
        position: PokerPosition,
        action: BettingAction,
        boardCardCount: Int,
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double?,
        recommendation: ActionRecommendation
    ) -> BetSizingAdvice {
        let bb = max(0.01, bigBlind)
        let sb = max(0, min(smallBlind, bb))
        let stackBB = min(500, max(1, effectiveStackBB))
        let pot = max(0, currentPot)

        if recommendation.tone == .fold {
            return BetSizingAdvice(
                title: "不建议投入",
                amountLabel: "本次投入",
                amount: 0,
                bbMultiple: 0,
                potAmount: pot,
                finalPotAmount: pot,
                amountText: "0 积分",
                detail: "当前牌力不支持这个动作，优先弃牌或过牌",
                tone: .fold,
                bbText: "0 BB"
            )
        }

        switch action {
        case .openRaise:
            let multiple = openRaiseBB(position: position)
            return amountAdvice(
                title: "开池加注",
                amountLabel: "加注到总额",
                amount: multiple * bb,
                bbMultiple: multiple,
                currentPot: pot,
                detail: "\(position.displayName) 标准开池 \(formatBB(multiple)) BB",
                tone: recommendation.tone
            )

        case .callOpen:
            let openBB = estimatedOpenBB(position: position)
            return amountAdvice(
                title: "跟注到",
                amountLabel: "跟注到总额",
                amount: openBB * bb,
                bbMultiple: openBB,
                currentPot: pot,
                detail: "按对手开池 \(formatBB(openBB)) BB 估算",
                tone: recommendation.tone
            )

        case .threeBet:
            let openBB = estimatedOpenBB(position: position)
            let multiplier = threeBetMultiplier(position: position)
            let totalBB = openBB * multiplier
            return amountAdvice(
                title: "3Bet 到",
                amountLabel: "加注到总额",
                amount: totalBB * bb,
                bbMultiple: totalBB,
                currentPot: pot,
                detail: "\(position.displayName) 约 \(formatBB(multiplier))x 对手开池",
                tone: recommendation.tone
            )

        case .fourBet:
            let openBB = estimatedOpenBB(position: position)
            let threeBetBB = openBB * threeBetMultiplier(position: position)
            let totalBB = threeBetBB * 2.2
            return amountAdvice(
                title: "4Bet 到",
                amountLabel: "加注到总额",
                amount: totalBB * bb,
                bbMultiple: totalBB,
                currentPot: pot,
                detail: "约 2.2x 对手 3Bet，避免尺寸过小给赔率",
                tone: recommendation.tone
            )

        case .continuationBet:
            let activePot = pot > 0 ? pot : estimatedPot(smallBlind: sb, bigBlind: bb, boardCardCount: boardCardCount, position: position)
            guard boardCardCount >= 3 else {
                let fallbackBB = openRaiseBB(position: position)
                return amountAdvice(
                    title: "翻前先加注",
                    amountLabel: "加注到总额",
                    amount: fallbackBB * bb,
                    bbMultiple: fallbackBB,
                    currentPot: activePot,
                    detail: "C-Bet 需要至少 3 张公共牌；当前先按开池尺寸估算",
                    tone: .caution
                )
            }

            let fraction = continuationBetFraction(madeHand: madeHand, draws: draws, equity: equity)
            return BetSizingAdvice(
                title: "C-Bet 建议",
                amountLabel: "本次下注",
                amount: activePot * fraction,
                bbMultiple: (activePot * fraction) / bb,
                potAmount: activePot,
                finalPotAmount: activePot + activePot * fraction,
                amountText: pointText(activePot * fraction),
                detail: "按当前底池下注约 \(Int((fraction * 100).rounded()))% 池",
                tone: recommendation.tone,
                bbText: "\(formatBB((activePot * fraction) / bb)) BB"
            )

        case .allIn:
            let totalBB = stackBB
            return amountAdvice(
                title: "全下",
                amountLabel: "全下总额",
                amount: totalBB * bb,
                bbMultiple: totalBB,
                currentPot: pot,
                detail: "按有效后手 \(formatBB(totalBB)) BB 估算",
                tone: recommendation.tone
            )
        }
    }

    private static func amountAdvice(
        title: String,
        amountLabel: String,
        amount: Double,
        bbMultiple: Double,
        currentPot: Double,
        detail: String,
        tone: RecommendationTone
    ) -> BetSizingAdvice {
        BetSizingAdvice(
            title: title,
            amountLabel: amountLabel,
            amount: amount,
            bbMultiple: bbMultiple,
            potAmount: currentPot,
            finalPotAmount: currentPot + amount,
            amountText: pointText(amount),
            detail: detail,
            tone: tone,
            bbText: "\(formatBB(bbMultiple)) BB"
        )
    }

    private static func openRaiseBB(position: PokerPosition) -> Double {
        switch position {
        case .underTheGun, .middle:
            return 2.5
        case .cutoff:
            return 2.3
        case .button:
            return 2.2
        case .smallBlind:
            return 3.0
        case .bigBlind:
            return 3.0
        }
    }

    private static func estimatedOpenBB(position: PokerPosition) -> Double {
        switch position {
        case .button, .smallBlind:
            return 2.2
        case .cutoff:
            return 2.3
        default:
            return 2.5
        }
    }

    private static func threeBetMultiplier(position: PokerPosition) -> Double {
        switch position {
        case .smallBlind, .bigBlind:
            return 4.0
        default:
            return 3.2
        }
    }

    private static func estimatedPot(
        smallBlind: Double,
        bigBlind: Double,
        boardCardCount: Int,
        position: PokerPosition
    ) -> Double {
        let preflopRaise = openRaiseBB(position: position) * bigBlind
        let callers = boardCardCount >= 3 ? 1.0 : 0.0
        return smallBlind + bigBlind + preflopRaise * (1 + callers)
    }

    private static func continuationBetFraction(
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double?
    ) -> Double {
        let equityValue = equity ?? 0

        if let madeHand, madeHand.category >= .twoPair || equityValue >= 0.65 {
            return 0.66
        }

        if let madeHand, madeHand.category == .onePair, equityValue >= 0.45 {
            return 0.45
        }

        if !draws.isEmpty || equityValue >= 0.35 {
            return 0.50
        }

        return 0.33
    }

    private static func formatAmount(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private static func pointText(_ value: Double) -> String {
        "\(formatAmount(value)) 积分"
    }

    private static func formatBB(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

enum ActionStreet: String, CaseIterable, Identifiable, Comparable {
    case preflop
    case flop
    case turn
    case river

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preflop: return "翻前"
        case .flop: return "翻牌"
        case .turn: return "转牌"
        case .river: return "河牌"
        }
    }

    var shortName: String {
        switch self {
        case .preflop: return "前"
        case .flop: return "翻"
        case .turn: return "转"
        case .river: return "河"
        }
    }

    var order: Int {
        switch self {
        case .preflop: return 0
        case .flop: return 1
        case .turn: return 2
        case .river: return 3
        }
    }

    static func < (lhs: ActionStreet, rhs: ActionStreet) -> Bool {
        lhs.order < rhs.order
    }

    static func current(boardCardCount: Int) -> ActionStreet {
        switch boardCardCount {
        case 0: return .preflop
        case 1...3: return .flop
        case 4: return .turn
        default: return .river
        }
    }
}

enum ActionActor: String, CaseIterable, Identifiable {
    case hero
    case opponent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hero: return "我"
        case .opponent: return "对手"
        }
    }
}

enum LineActionKind: String, CaseIterable, Identifiable {
    case check
    case call
    case bet
    case raise
    case fold
    case allIn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .check: return "过牌"
        case .call: return "跟注"
        case .bet: return "下注"
        case .raise: return "加注"
        case .fold: return "弃牌"
        case .allIn: return "全下"
        }
    }

    var needsAmount: Bool {
        switch self {
        case .call, .bet, .raise, .allIn:
            return true
        case .check, .fold:
            return false
        }
    }

    var isAggressive: Bool {
        switch self {
        case .bet, .raise, .allIn:
            return true
        case .check, .call, .fold:
            return false
        }
    }

    var isContinue: Bool {
        switch self {
        case .call, .bet, .raise, .allIn:
            return true
        case .check, .fold:
            return false
        }
    }
}

struct ActionLineEntry: Identifiable, Hashable {
    let id = UUID()
    let street: ActionStreet
    let actor: ActionActor
    let action: LineActionKind
    let amount: Double?
    let actorSeatID: Int?
    let actorName: String?

    init(
        street: ActionStreet,
        actor: ActionActor,
        action: LineActionKind,
        amount: Double?,
        actorSeatID: Int? = nil,
        actorName: String? = nil
    ) {
        self.street = street
        self.actor = actor
        self.action = action
        self.amount = amount
        self.actorSeatID = actorSeatID
        self.actorName = actorName
    }

    var displayActorName: String {
        actorName ?? actor.displayName
    }

    func amountText() -> String {
        guard let amount, amount > 0 else { return "" }
        return "\(Self.formatAmount(amount)) 积分"
    }

    private static func formatAmount(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

}

struct ActionLineFinding: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let tone: RecommendationTone
}

struct ActionLineAdvice {
    let title: String
    let detail: String
    let tone: RecommendationTone
    let scoreText: String
    let findings: [ActionLineFinding]
}

struct GTOActionPlan {
    let title: String
    let primaryAction: String
    let mixedAction: String?
    let frequencyText: String
    let sizingText: String
    let equityText: String
    let potOddsText: String
    let detail: String
    let tone: RecommendationTone
    let reasons: [ActionLineFinding]
}

enum GTOActionPlanner {
    static func plan(
        entries: [ActionLineEntry],
        startingHand: StartingHand?,
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double?,
        position: PokerPosition,
        boardCardCount: Int,
        currentPot: Double,
        bigBlind: Double,
        heroStack: Double
    ) -> GTOActionPlan {
        guard startingHand != nil || madeHand != nil else {
            return GTOActionPlan(
                title: "等待手牌",
                primaryAction: "--",
                mixedAction: nil,
                frequencyText: "补齐手牌后生成",
                sizingText: "--",
                equityText: "--",
                potOddsText: "--",
                detail: "GTO 近似解需要你的两张手牌；翻后还会结合公共牌、胜率和行动线判断",
                tone: .caution,
                reasons: []
            )
        }

        if let last = entries.last, last.actor == .hero, last.action != .check {
            return GTOActionPlan(
                title: "等待对手响应",
                primaryAction: "等待",
                mixedAction: nil,
                frequencyText: "当前轮到对手",
                sizingText: "--",
                equityText: equityLabel(equity ?? estimatedEquity(startingHand: startingHand, madeHand: madeHand, draws: draws)),
                potOddsText: "--",
                detail: "你的最后一个动作已经进入行动线，下一步先记录对手动作，再生成新的最优解",
                tone: .continueHand,
                reasons: [ActionLineFinding(title: "行动顺序", detail: "GTO 决策按当前轮到谁行动来判断，避免重复给你的动作", tone: .continueHand)]
            )
        }

        let equityValue = equity ?? estimatedEquity(startingHand: startingHand, madeHand: madeHand, draws: draws)
        let pressure = facingOpponentPressure(entries: entries)

        if let pressure {
            return facingPressurePlan(
                pressure: pressure,
                startingHand: startingHand,
                madeHand: madeHand,
                draws: draws,
                equity: equityValue,
                hasExactEquity: equity != nil,
                position: position,
                boardCardCount: boardCardCount,
                currentPot: currentPot,
                bigBlind: bigBlind,
                heroStack: heroStack
            )
        }

        return initiativePlan(
            entries: entries,
            startingHand: startingHand,
            madeHand: madeHand,
            draws: draws,
            equity: equityValue,
            hasExactEquity: equity != nil,
            position: position,
            boardCardCount: boardCardCount,
            currentPot: currentPot,
            bigBlind: bigBlind,
            heroStack: heroStack
        )
    }

    private static func facingPressurePlan(
        pressure: ActionLineEntry,
        startingHand: StartingHand?,
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double,
        hasExactEquity: Bool,
        position: PokerPosition,
        boardCardCount: Int,
        currentPot: Double,
        bigBlind: Double,
        heroStack: Double
    ) -> GTOActionPlan {
        let callAmount = min(max(0, pressure.amount ?? 0), max(0, heroStack))
        let potOdds = callAmount > 0 ? callAmount / max(callAmount, currentPot + callAmount) : 0
        let equityEdge = equity - potOdds
        let spr = currentPot > 0 ? heroStack / currentPot : 99
        let canRaise = heroStack > callAmount + max(0.01, bigBlind)
        let reasons = pressureReasons(
            pressure: pressure,
            startingHand: startingHand,
            madeHand: madeHand,
            draws: draws,
            equity: equity,
            hasExactEquity: hasExactEquity,
            potOdds: potOdds,
            boardCardCount: boardCardCount
        )

        if pressure.action == .allIn || spr <= 1.4 {
            if equityEdge >= 0.08 {
                return GTOActionPlan(
                    title: "GTO 近似：跟全下",
                    primaryAction: "跟注",
                    mixedAction: equityEdge < 0.16 ? "少量弃牌" : nil,
                    frequencyText: equityEdge < 0.16 ? "跟注 75% / 弃牌 25%" : "跟注 100%",
                    sizingText: "投入 \(pointText(callAmount))",
                    equityText: equityLabel(equity),
                    potOddsText: oddsLabel(potOdds),
                    detail: "胜率高于底池赔率，短 SPR 场景优先兑现摊牌权益",
                    tone: .continueHand,
                    reasons: reasons
                )
            }

            return GTOActionPlan(
                title: "GTO 近似：弃牌",
                primaryAction: "弃牌",
                mixedAction: equityEdge > -0.05 ? "低频跟注" : nil,
                frequencyText: equityEdge > -0.05 ? "弃牌 70% / 跟注 30%" : "弃牌 100%",
                sizingText: "不再投入",
                equityText: equityLabel(equity),
                potOddsText: oddsLabel(potOdds),
                detail: "面对全下时胜率没有覆盖所需赔率，继续投入的期望值偏低",
                tone: .fold,
                reasons: reasons
            )
        }

        if equityEdge >= 0.22, canRaise {
            let raiseAmount = min(heroStack, max(callAmount * 2.6, currentPot * 0.72))
            return GTOActionPlan(
                title: "GTO 近似：加注施压",
                primaryAction: "加注",
                mixedAction: "跟注",
                frequencyText: "加注 65% / 跟注 35%",
                sizingText: "加注到 \(pointText(raiseAmount))",
                equityText: equityLabel(equity),
                potOddsText: oddsLabel(potOdds),
                detail: "胜率优势明显，保留一部分跟注保护范围，同时用加注拿价值和施压",
                tone: .attack,
                reasons: reasons
            )
        }

        if equityEdge >= 0.03 {
            return GTOActionPlan(
                title: "GTO 近似：跟注",
                primaryAction: "跟注",
                mixedAction: equityEdge < 0.10 ? "弃牌" : nil,
                frequencyText: equityEdge < 0.10 ? "跟注 65% / 弃牌 35%" : "跟注 85% / 加注 15%",
                sizingText: "跟注 \(pointText(callAmount))",
                equityText: equityLabel(equity),
                potOddsText: oddsLabel(potOdds),
                detail: "胜率略高于所需赔率，优先跟注保留对手诈唬范围",
                tone: .continueHand,
                reasons: reasons
            )
        }

        if !draws.isEmpty, equityEdge > -0.06, canRaise, boardCardCount >= 3 {
            let raiseAmount = min(heroStack, max(callAmount * 2.4, currentPot * 0.60))
            return GTOActionPlan(
                title: "GTO 近似：混合反击",
                primaryAction: "弃牌",
                mixedAction: "低频加注",
                frequencyText: "弃牌 70% / 加注 30%",
                sizingText: "加注到 \(pointText(raiseAmount))",
                equityText: equityLabel(equity),
                potOddsText: oddsLabel(potOdds),
                detail: "直接跟注略亏，但听牌可低频转成半诈唬反击",
                tone: .caution,
                reasons: reasons
            )
        }

        return GTOActionPlan(
            title: "GTO 近似：弃牌",
            primaryAction: "弃牌",
            mixedAction: nil,
            frequencyText: "弃牌 100%",
            sizingText: "不再投入",
            equityText: equityLabel(equity),
            potOddsText: oddsLabel(potOdds),
            detail: "胜率低于底池赔率，继续跟注或加注都容易进入负期望",
            tone: .fold,
            reasons: reasons
        )
    }

    private static func initiativePlan(
        entries: [ActionLineEntry],
        startingHand: StartingHand?,
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double,
        hasExactEquity: Bool,
        position: PokerPosition,
        boardCardCount: Int,
        currentPot: Double,
        bigBlind: Double,
        heroStack: Double
    ) -> GTOActionPlan {
        let reasons = initiativeReasons(
            startingHand: startingHand,
            madeHand: madeHand,
            draws: draws,
            equity: equity,
            hasExactEquity: hasExactEquity,
            position: position,
            boardCardCount: boardCardCount
        )

        if boardCardCount == 0, let startingHand {
            let openRange = RangeAdvisor.heroActionPercent(position: position, action: .openRaise)
            let inOpenRange = PreflopAnalyzer.contains(startingHand, inTopPercent: openRange)
            let coreRange = PreflopAnalyzer.contains(startingHand, inTopPercent: max(2, openRange * 0.42))
            let openBB = openRaiseBB(position: position)
            let openAmount = openBB * max(0.01, bigBlind)

            if coreRange {
                return GTOActionPlan(
                    title: "GTO 近似：标准开池",
                    primaryAction: "加注",
                    mixedAction: nil,
                    frequencyText: "加注 100%",
                    sizingText: "加注到 \(pointText(openAmount))",
                    equityText: equityLabel(equity),
                    potOddsText: "--",
                    detail: "\(startingHand.code) 属于 \(position.displayName) 核心开池范围，应主动进入底池",
                    tone: .attack,
                    reasons: reasons
                )
            }

            if inOpenRange {
                return GTOActionPlan(
                    title: "GTO 近似：混合开池",
                    primaryAction: "加注",
                    mixedAction: "弃牌",
                    frequencyText: "加注 60% / 弃牌 40%",
                    sizingText: "加注到 \(pointText(openAmount))",
                    equityText: equityLabel(equity),
                    potOddsText: "--",
                    detail: "\(startingHand.code) 在可开池边缘，按位置做混合频率",
                    tone: .continueHand,
                    reasons: reasons
                )
            }

            let passiveAction = position == .bigBlind ? "过牌" : "弃牌"
            return GTOActionPlan(
                title: "GTO 近似：放弃边缘牌",
                primaryAction: passiveAction,
                mixedAction: nil,
                frequencyText: "\(passiveAction) 100%",
                sizingText: "不主动投入",
                equityText: equityLabel(equity),
                potOddsText: "--",
                detail: "\(startingHand.code) 不在 \(position.displayName) 标准开池范围内",
                tone: .fold,
                reasons: reasons
            )
        }

        let activePot = max(currentPot, max(0.01, bigBlind) * 3)
        let stackCap = max(0, heroStack)
        let strongMadeHand = madeHand.map { $0.category >= .twoPair } ?? false
        let betAmount: Double
        let detail: String

        if strongMadeHand || equity >= 0.65 {
            betAmount = min(stackCap, activePot * 0.66)
            detail = strongMadeHand ? "强成牌需要价值下注，避免给对手免费看牌" : "胜率优势明显，下注可获取价值并保护范围"
            return GTOActionPlan(
                title: "GTO 近似：价值下注",
                primaryAction: "下注",
                mixedAction: "过牌",
                frequencyText: "下注 75% / 过牌 25%",
                sizingText: "下注 \(pointText(betAmount))",
                equityText: equityLabel(equity),
                potOddsText: "--",
                detail: detail,
                tone: .attack,
                reasons: reasons
            )
        }

        if !draws.isEmpty, equity >= 0.30 {
            betAmount = min(stackCap, activePot * 0.50)
            return GTOActionPlan(
                title: "GTO 近似：半诈唬混合",
                primaryAction: "下注",
                mixedAction: "过牌",
                frequencyText: "下注 55% / 过牌 45%",
                sizingText: "下注 \(pointText(betAmount))",
                equityText: equityLabel(equity),
                potOddsText: "--",
                detail: "听牌有摊牌补牌权益，适合用中等频率下注施压",
                tone: .caution,
                reasons: reasons
            )
        }

        if madeHand?.category == .onePair || equity >= 0.42 {
            betAmount = min(stackCap, activePot * 0.33)
            return GTOActionPlan(
                title: "GTO 近似：控池",
                primaryAction: "过牌",
                mixedAction: "小注",
                frequencyText: "过牌 65% / 小注 35%",
                sizingText: "小注 \(pointText(betAmount))",
                equityText: equityLabel(equity),
                potOddsText: "--",
                detail: "中等牌力优先保留摊牌价值，低频小注保护范围",
                tone: .continueHand,
                reasons: reasons
            )
        }

        return GTOActionPlan(
            title: "GTO 近似：过牌放弃",
            primaryAction: "过牌",
            mixedAction: "弃牌",
            frequencyText: entries.isEmpty ? "弃牌 100%" : "过牌 80% / 弃牌 20%",
            sizingText: "不主动投入",
            equityText: equityLabel(equity),
            potOddsText: "--",
            detail: "当前牌力和胜率不足以支撑主动下注",
            tone: .fold,
            reasons: reasons
        )
    }

    private static func facingOpponentPressure(entries: [ActionLineEntry]) -> ActionLineEntry? {
        guard let pressureIndex = entries.lastIndex(where: { entry in
            entry.actor == .opponent && entry.action.isAggressive && (entry.amount ?? 0) > 0
        }) else {
            return nil
        }

        let heroAnswered = entries.indices.contains { index in
            index > pressureIndex && entries[index].actor == .hero && entries[index].action.isContinue
        }

        return heroAnswered ? nil : entries[pressureIndex]
    }

    private static func pressureReasons(
        pressure: ActionLineEntry,
        startingHand: StartingHand?,
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double,
        hasExactEquity: Bool,
        potOdds: Double,
        boardCardCount: Int
    ) -> [ActionLineFinding] {
        var reasons: [ActionLineFinding] = [
            ActionLineFinding(
                title: "面对下注",
                detail: "对手最后动作是 \(pressure.action.displayName)，需要先比较胜率和底池赔率",
                tone: .caution
            ),
            ActionLineFinding(
                title: hasExactEquity ? "胜率输入" : "胜率估算",
                detail: "\(equityLabel(equity)) 对比所需 \(oddsLabel(potOdds))",
                tone: equity >= potOdds ? .continueHand : .fold
            )
        ]

        if let madeHand {
            reasons.append(ActionLineFinding(title: "当前牌型", detail: madeHand.displayName, tone: madeHand.category >= .twoPair ? .attack : .continueHand))
        } else if let startingHand, boardCardCount == 0 {
            reasons.append(ActionLineFinding(title: "起手牌", detail: "\(startingHand.code) 分数 \(formatAmount(PreflopAnalyzer.score(startingHand)))", tone: .continueHand))
        }

        if !draws.isEmpty {
            reasons.append(ActionLineFinding(title: "补牌权益", detail: draws.joined(separator: "、"), tone: .caution))
        }

        return Array(reasons.prefix(4))
    }

    private static func initiativeReasons(
        startingHand: StartingHand?,
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double,
        hasExactEquity: Bool,
        position: PokerPosition,
        boardCardCount: Int
    ) -> [ActionLineFinding] {
        var reasons: [ActionLineFinding] = [
            ActionLineFinding(
                title: "位置",
                detail: "\(position.displayName) \(position.detailName)",
                tone: .continueHand
            ),
            ActionLineFinding(
                title: hasExactEquity ? "胜率输入" : "胜率估算",
                detail: equityLabel(equity),
                tone: equity >= 0.55 ? .attack : .caution
            )
        ]

        if let madeHand {
            reasons.append(ActionLineFinding(title: "当前牌型", detail: madeHand.displayName, tone: madeHand.category >= .twoPair ? .attack : .continueHand))
        } else if let startingHand, boardCardCount == 0 {
            reasons.append(ActionLineFinding(title: "起手牌", detail: "\(startingHand.code) 分数 \(formatAmount(PreflopAnalyzer.score(startingHand)))", tone: .continueHand))
        }

        if !draws.isEmpty {
            reasons.append(ActionLineFinding(title: "听牌", detail: draws.joined(separator: "、"), tone: .caution))
        }

        return Array(reasons.prefix(4))
    }

    private static func estimatedEquity(startingHand: StartingHand?, madeHand: EvaluatedHand?, draws: [String]) -> Double {
        if let madeHand {
            let base: Double
            switch madeHand.category {
            case .highCard: base = 0.22
            case .onePair: base = 0.44
            case .twoPair: base = 0.66
            case .threeOfAKind: base = 0.72
            case .straight: base = 0.78
            case .flush: base = 0.82
            case .fullHouse: base = 0.88
            case .fourOfAKind, .straightFlush: base = 0.95
            }
            return min(0.97, base + (draws.isEmpty ? 0 : 0.08))
        }

        if let startingHand {
            return min(0.78, max(0.18, 0.18 + PreflopAnalyzer.score(startingHand) / 28.0))
        }

        return 0
    }

    private static func openRaiseBB(position: PokerPosition) -> Double {
        switch position {
        case .underTheGun, .middle:
            return 2.5
        case .cutoff:
            return 2.3
        case .button:
            return 2.2
        case .smallBlind, .bigBlind:
            return 3.0
        }
    }

    private static func equityLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func oddsLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func formatAmount(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private static func pointText(_ value: Double) -> String {
        "\(formatAmount(value)) 积分"
    }
}

enum ActionLineAdvisor {
    static func advice(
        entries: [ActionLineEntry],
        recommendation: ActionRecommendation,
        betSizingAdvice: BetSizingAdvice,
        startingHand: StartingHand?,
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double?,
        position: PokerPosition,
        bettingAction: BettingAction,
        boardCardCount: Int,
        bigBlind: Double
    ) -> ActionLineAdvice {
        guard !entries.isEmpty else {
            return ActionLineAdvice(
                title: "等待行动线",
                detail: "添加我与对手的动作后，会结合牌力、范围和下注尺寸判断",
                tone: .caution,
                scoreText: "--",
                findings: []
            )
        }

        var score = 72
        var findings: [ActionLineFinding] = []
        let heroEntries = entries.filter { $0.actor == .hero }
        let opponentEntries = entries.filter { $0.actor == .opponent }
        let heroAggressive = heroEntries.filter { $0.action.isAggressive }
        let heroContinues = heroEntries.filter { $0.action.isContinue }
        let opponentAggressive = opponentEntries.filter { $0.action.isAggressive }
        let currentStreet = ActionStreet.current(boardCardCount: boardCardCount)
        let equityValue = equity ?? 0

        if hasStreetRegression(entries) {
            score -= 20
            findings.append(ActionLineFinding(
                title: "街道顺序异常",
                detail: "后面的动作回到了更早街道，复盘时建议按翻前、翻牌、转牌、河牌排列",
                tone: .fold
            ))
        }

        if let terminalIndex = entries.firstIndex(where: { $0.action == .fold || $0.action == .allIn }),
           terminalIndex < entries.index(before: entries.endIndex) {
            score -= 12
            findings.append(ActionLineFinding(
                title: "终结动作后仍有记录",
                detail: "弃牌或全下通常会结束这一段行动线，后续动作可能需要另起一手牌",
                tone: .caution
            ))
        }

        if entries.contains(where: { $0.street > currentStreet }) {
            score -= 6
            findings.append(ActionLineFinding(
                title: "后续街道缺少牌面",
                detail: "行动线里包含 \(currentStreet.displayName) 之后的动作，补齐公共牌后判断会更准",
                tone: .caution
            ))
        }

        switch recommendation.tone {
        case .attack:
            if heroAggressive.isEmpty {
                score -= 10
                findings.append(ActionLineFinding(
                    title: "可能偏保守",
                    detail: "当前牌力支持主动施压，但行动线里没有你的下注或加注",
                    tone: .caution
                ))
            } else {
                score += 10
                findings.append(ActionLineFinding(
                    title: "主动性匹配",
                    detail: "你的进攻动作和当前牌力建议一致",
                    tone: .continueHand
                ))
            }

        case .continueHand:
            if heroAggressive.count >= 2 {
                score -= 8
                findings.append(ActionLineFinding(
                    title: "进攻频率略高",
                    detail: "当前更像可继续牌，多次主动扩大底池需要更清楚的价值或诈唬目标",
                    tone: .caution
                ))
            } else if !heroContinues.isEmpty {
                score += 6
                findings.append(ActionLineFinding(
                    title: "继续合理",
                    detail: "跟注、控池或小尺寸下注都能和当前牌力匹配",
                    tone: .continueHand
                ))
            }

        case .caution:
            if heroAggressive.count >= 2 {
                score -= 14
                findings.append(ActionLineFinding(
                    title: "偏激进",
                    detail: "当前属于谨慎区间，多次下注或加注容易把中等牌力打成大底池",
                    tone: .caution
                ))
            } else {
                score += 4
                findings.append(ActionLineFinding(
                    title: "谨慎线可接受",
                    detail: "当前牌力更适合有选择地继续，避免无计划打大底池",
                    tone: .continueHand
                ))
            }

        case .fold:
            if !heroContinues.isEmpty {
                score -= 26
                findings.append(ActionLineFinding(
                    title: "投入偏宽",
                    detail: "当前建议倾向弃牌，但行动线里你仍然跟注、下注或加注",
                    tone: .fold
                ))
            } else {
                score += 8
                findings.append(ActionLineFinding(
                    title: "弃牌纪律合理",
                    detail: "当前牌力不足，减少投入是更稳的选择",
                    tone: .continueHand
                ))
            }
        }

        if let sizeFinding = sizingFinding(
            heroEntries: heroEntries,
            advice: betSizingAdvice,
            recommendation: recommendation,
            bigBlind: bigBlind
        ) {
            score += sizeFinding.scoreDelta
            findings.append(sizeFinding.finding)
        }

        if !opponentAggressive.isEmpty,
           let lastHero = heroEntries.last,
           lastHero.action.isContinue,
           recommendation.tone != .attack,
           equityValue > 0,
           equityValue < 0.35 {
            score -= 16
            findings.append(ActionLineFinding(
                title: "面对进攻防守偏宽",
                detail: "对手有下注或加注，你的胜率低于 35% 仍继续，容易被价值下注惩罚",
                tone: .fold
            ))
        }

        if let madeHand, madeHand.category >= .twoPair, heroAggressive.isEmpty, opponentAggressive.isEmpty {
            score -= 9
            findings.append(ActionLineFinding(
                title: "强牌价值不足",
                detail: "\(madeHand.displayName) 通常需要考虑价值下注，连续过牌可能少拿价值",
                tone: .caution
            ))
        }

        if !draws.isEmpty, heroAggressive.count == 1, recommendation.tone == .caution {
            score += 5
            findings.append(ActionLineFinding(
                title: "半诈唬有依据",
                detail: draws.joined(separator: "、") + " 可以支持一次有计划的主动下注",
                tone: .continueHand
            ))
        }

        if startingHand == nil, madeHand == nil {
            score -= 8
            findings.append(ActionLineFinding(
                title: "缺少手牌信息",
                detail: "补齐两张手牌后，行动线判断会更接近真实牌局",
                tone: .caution
            ))
        }

        score = min(100, max(0, score))
        return ActionLineAdvice(
            title: title(for: score),
            detail: detail(score: score, position: position, action: bettingAction),
            tone: tone(for: score),
            scoreText: "\(score)",
            findings: Array(findings.prefix(5))
        )
    }

    private static func hasStreetRegression(_ entries: [ActionLineEntry]) -> Bool {
        zip(entries, entries.dropFirst()).contains { previous, current in
            current.street < previous.street
        }
    }

    private static func sizingFinding(
        heroEntries: [ActionLineEntry],
        advice: BetSizingAdvice,
        recommendation: ActionRecommendation,
        bigBlind: Double
    ) -> (finding: ActionLineFinding, scoreDelta: Int)? {
        let amountEntries = heroEntries.filter { $0.action.isAggressive && ($0.amount ?? 0) > 0 }
        guard let latest = amountEntries.last, let amount = latest.amount else { return nil }
        guard advice.amount > 0 else { return nil }

        let bb = max(0.01, bigBlind)
        let inputBB = amount / bb

        if amount > advice.amount * 1.55, recommendation.tone != .attack {
            return (
                ActionLineFinding(
                    title: "下注尺寸偏大",
                    detail: "\(formatBB(inputBB)) BB 明显高于建议 \(advice.bbText)，中等牌力容易被反击",
                    tone: .caution
                ),
                -12
            )
        }

        if amount < advice.amount * 0.60, latest.action.isAggressive {
            return (
                ActionLineFinding(
                    title: "下注尺寸偏小",
                    detail: "\(formatBB(inputBB)) BB 低于建议 \(advice.bbText)，可能给对手过好的跟注赔率",
                    tone: .caution
                ),
                -8
            )
        }

        return (
            ActionLineFinding(
                title: "下注尺寸接近建议",
                detail: "\(formatBB(inputBB)) BB 与当前推荐尺寸接近",
                tone: .continueHand
            ),
            5
        )
    }

    private static func title(for score: Int) -> String {
        switch score {
        case 82...: return "行动线基本合理"
        case 65..<82: return "行动线可接受"
        case 45..<65: return "行动线需要复盘"
        default: return "行动线偏离较大"
        }
    }

    private static func detail(score: Int, position: PokerPosition, action: BettingAction) -> String {
        "\(position.displayName) · \(action.displayName) 场景，综合牌力、对手范围、下注尺寸给出 \(score) 分"
    }

    private static func tone(for score: Int) -> RecommendationTone {
        switch score {
        case 82...: return .continueHand
        case 65..<82: return .caution
        case 45..<65: return .caution
        default: return .fold
        }
    }

    private static func formatBB(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

enum RangeAdvisor {
    static func recommendedRangePercent(position: PokerPosition, action: BettingAction, style: OpponentStyle) -> Double {
        if style == .any {
            return 100
        }
        return min(100, max(1, baseRangePercent(position: position, action: action) * style.multiplier))
    }

    static func heroActionPercent(position: PokerPosition, action: BettingAction) -> Double {
        baseRangePercent(position: position, action: action)
    }

    static func recommendation(
        startingHand: StartingHand?,
        madeHand: EvaluatedHand?,
        draws: [String],
        equity: Double?,
        position: PokerPosition,
        action: BettingAction
    ) -> ActionRecommendation {
        if let madeHand {
            return postflopRecommendation(madeHand: madeHand, draws: draws, equity: equity)
        }

        guard let startingHand else {
            return ActionRecommendation(title: "选择手牌", detail: "补齐两张手牌后生成建议", tone: .caution)
        }

        let rangePercent = heroActionPercent(position: position, action: action)
        let isInRange = PreflopAnalyzer.contains(startingHand, inTopPercent: rangePercent)
        let score = PreflopAnalyzer.score(startingHand)

        if isInRange, score >= 11 {
            return ActionRecommendation(title: "主动进攻", detail: "\(startingHand.code) 位于 \(position.displayName) \(action.displayName) 核心范围", tone: .attack)
        }

        if isInRange {
            return ActionRecommendation(title: "可入池", detail: "更依赖位置、赔率和后手深度", tone: .continueHand)
        }

        if score >= 6, position == .button || position == .smallBlind {
            return ActionRecommendation(title: "混合策略", detail: "后位可低频偷盲，遇到反击谨慎继续", tone: .caution)
        }

        return ActionRecommendation(title: "倾向弃牌", detail: "不在当前标准下注范围内", tone: .fold)
    }

    private static func baseRangePercent(position: PokerPosition, action: BettingAction) -> Double {
        switch action {
        case .openRaise:
            switch position {
            case .underTheGun: return 13
            case .middle: return 18
            case .cutoff: return 28
            case .button: return 45
            case .smallBlind: return 38
            case .bigBlind: return 12
            }
        case .callOpen:
            switch position {
            case .underTheGun: return 7
            case .middle: return 10
            case .cutoff: return 15
            case .button: return 24
            case .smallBlind: return 13
            case .bigBlind: return 34
            }
        case .threeBet:
            switch position {
            case .underTheGun: return 4
            case .middle: return 5
            case .cutoff: return 7
            case .button: return 11
            case .smallBlind: return 12
            case .bigBlind: return 10
            }
        case .fourBet:
            switch position {
            case .underTheGun: return 2.5
            case .middle: return 3
            case .cutoff: return 4
            case .button: return 6
            case .smallBlind: return 5
            case .bigBlind: return 5
            }
        case .continuationBet:
            switch position {
            case .underTheGun: return 38
            case .middle: return 42
            case .cutoff: return 48
            case .button: return 58
            case .smallBlind: return 46
            case .bigBlind: return 40
            }
        case .allIn:
            switch position {
            case .underTheGun: return 2.5
            case .middle: return 3.5
            case .cutoff: return 5
            case .button: return 8
            case .smallBlind: return 9
            case .bigBlind: return 7
            }
        }
    }

    private static func postflopRecommendation(madeHand: EvaluatedHand, draws: [String], equity: Double?) -> ActionRecommendation {
        let equityValue = equity ?? 0

        if madeHand.category >= .twoPair || equityValue >= 0.65 {
            return ActionRecommendation(title: "价值下注", detail: "\(madeHand.displayName) 具备主动施压价值", tone: .attack)
        }

        if madeHand.category == .onePair, equityValue >= 0.45 {
            return ActionRecommendation(title: "控制底池", detail: "一对牌可继续，但避免无计划扩大底池", tone: .continueHand)
        }

        if !draws.isEmpty, equityValue >= 0.30 {
            return ActionRecommendation(title: "半诈唬候选", detail: draws.joined(separator: "、"), tone: .caution)
        }

        if equityValue >= 0.40 {
            return ActionRecommendation(title: "谨慎继续", detail: "胜率接近可防守区间", tone: .caution)
        }

        return ActionRecommendation(title: "减少投入", detail: "牌力和胜率不足以支撑大额下注", tone: .fold)
    }
}

enum DrawAnalyzer {
    static func drawTexts(heroCards: [Card], boardCards: [Card]) -> [String] {
        guard boardCards.count >= 3, boardCards.count < 5 else { return [] }
        let cards = heroCards + boardCards
        guard cards.count >= 5 else { return [] }

        var draws: [String] = []
        let madeHand = PokerHandEvaluator.evaluateIfPossible(cards)

        let suitCounts = Dictionary(grouping: cards, by: \.suit).mapValues(\.count)
        if madeHand?.category != .flush, suitCounts.values.contains(where: { $0 == 4 }) {
            draws.append("同花听牌")
        }

        if madeHand?.category != .straight, hasOpenStraightDraw(cards) {
            draws.append("顺子听牌")
        }

        return draws
    }

    private static func hasOpenStraightDraw(_ cards: [Card]) -> Bool {
        var values = Set(cards.map(\.rank.rawValue))
        if values.contains(Rank.ace.rawValue) {
            values.insert(1)
        }

        for start in 1...10 {
            let straight = Set(start..<(start + 5))
            if straight.intersection(values).count == 4 {
                return true
            }
        }

        return false
    }
}

struct EquityInput {
    let heroCards: [Card]
    let boardCards: [Card]
    let opponentCount: Int
    let opponentRangePercent: Double
    let iterations: Int
}

struct EquityResult {
    let equity: Double
    let winCount: Int
    let tieCount: Int
    let lossCount: Int
    let simulations: Int

    var winRate: Double { Double(winCount) / Double(max(1, simulations)) }
    var tieRate: Double { Double(tieCount) / Double(max(1, simulations)) }
    var lossRate: Double { Double(lossCount) / Double(max(1, simulations)) }
}

struct TableEquityInput {
    let heroCards: [Card]
    let opponentHands: [[Card]]
    let boardCards: [Card]
    let iterations: Int
    let deadCards: [Card]

    init(
        heroCards: [Card],
        opponentHands: [[Card]],
        boardCards: [Card],
        iterations: Int,
        deadCards: [Card] = []
    ) {
        self.heroCards = heroCards
        self.opponentHands = opponentHands
        self.boardCards = boardCards
        self.iterations = iterations
        self.deadCards = deadCards
    }
}

enum TableEquityCalculator {
    static func calculate(input: TableEquityInput, progress: ((Double) -> Void)? = nil) async -> EquityResult {
        let opponentHands = input.opponentHands.filter { $0.count == 2 }
        guard input.heroCards.count == 2,
              input.boardCards.count <= 5,
              input.boardCards.count != 1,
              input.boardCards.count != 2
        else {
            return EquityResult(equity: 0, winCount: 0, tieCount: 0, lossCount: 0, simulations: 0)
        }

        let deadCards = input.heroCards + opponentHands.flatMap { $0 } + input.boardCards + input.deadCards
        guard Set(deadCards).count == deadCards.count else {
            return EquityResult(equity: 0, winCount: 0, tieCount: 0, lossCount: 0, simulations: 0)
        }

        if opponentHands.isEmpty {
            progress?(1)
            return EquityResult(equity: 1, winCount: 1, tieCount: 0, lossCount: 0, simulations: 1)
        }

        let baseDeck = Card.fullDeck.filter { !deadCards.contains($0) }
        let boardIsComplete = input.boardCards.count == 5
        let iterations = boardIsComplete ? 1 : min(50_000, max(1, input.iterations))
        let progressStep = max(1, iterations / 100)

        var rng = SystemRandomNumberGenerator()
        var wins = 0
        var ties = 0
        var losses = 0
        var equityPoints = 0.0

        progress?(0)

        for index in 0..<iterations {
            var deck = baseDeck
            if !boardIsComplete {
                deck.shuffle(using: &rng)
            }

            var finalBoard = input.boardCards
            let cardsNeeded = 5 - finalBoard.count
            if cardsNeeded > 0 {
                guard deck.count >= cardsNeeded else { continue }
                finalBoard.append(contentsOf: deck.prefix(cardsNeeded))
            }

            guard finalBoard.count == 5 else { continue }

            let heroValue = PokerHandEvaluator.evaluate(input.heroCards + finalBoard)
            let opponentValues = opponentHands.map { PokerHandEvaluator.evaluate($0 + finalBoard) }
            let betterOpponents = opponentValues.filter { $0 > heroValue }.count

            if betterOpponents == 0 {
                let tiedOpponents = opponentValues.filter { $0 == heroValue }.count
                if tiedOpponents == 0 {
                    wins += 1
                    equityPoints += 1
                } else {
                    ties += 1
                    equityPoints += 1 / Double(tiedOpponents + 1)
                }
            } else {
                losses += 1
            }

            if index + 1 == iterations || (index + 1).isMultiple(of: progressStep) {
                progress?(Double(index + 1) / Double(iterations))
                await Task.yield()
            }

            if Task.isCancelled {
                break
            }
        }

        let simulations = wins + ties + losses
        return EquityResult(
            equity: equityPoints / Double(max(1, simulations)),
            winCount: wins,
            tieCount: ties,
            lossCount: losses,
            simulations: simulations
        )
    }
}

enum EquityCalculator {
    static func calculate(input: EquityInput) -> EquityResult {
        guard input.heroCards.count == 2, input.boardCards.count <= 5 else {
            return EquityResult(equity: 0, winCount: 0, tieCount: 0, lossCount: 0, simulations: 0)
        }

        let deadCards = Set(input.heroCards + input.boardCards)
        guard deadCards.count == input.heroCards.count + input.boardCards.count else {
            return EquityResult(equity: 0, winCount: 0, tieCount: 0, lossCount: 0, simulations: 0)
        }

        let baseDeck = Card.fullDeck.filter { !deadCards.contains($0) }
        let opponentCount = min(8, max(1, input.opponentCount))
        let iterations = min(50_000, max(1, input.iterations))
        let rangeSet = PreflopAnalyzer.rangeSet(percent: input.opponentRangePercent)

        var rng = SystemRandomNumberGenerator()
        var wins = 0
        var ties = 0
        var losses = 0
        var equityPoints = 0.0

        for _ in 0..<iterations {
            var deck = baseDeck
            deck.shuffle(using: &rng)

            var opponentHands: [[Card]] = []
            for _ in 0..<opponentCount {
                guard let hand = drawOpponentHand(from: &deck, allowedHands: rangeSet, rng: &rng) else {
                    continue
                }
                opponentHands.append(hand)
            }

            var finalBoard = input.boardCards
            let cardsNeeded = 5 - finalBoard.count
            if cardsNeeded > 0 {
                finalBoard.append(contentsOf: deck.prefix(cardsNeeded))
                deck.removeFirst(min(cardsNeeded, deck.count))
            }

            guard finalBoard.count == 5, opponentHands.count == opponentCount else {
                continue
            }

            let heroValue = PokerHandEvaluator.evaluate(input.heroCards + finalBoard)
            let opponentValues = opponentHands.map { PokerHandEvaluator.evaluate($0 + finalBoard) }
            let betterOpponents = opponentValues.filter { $0 > heroValue }.count

            if betterOpponents == 0 {
                let tiedOpponents = opponentValues.filter { $0 == heroValue }.count
                if tiedOpponents == 0 {
                    wins += 1
                    equityPoints += 1
                } else {
                    ties += 1
                    equityPoints += 1 / Double(tiedOpponents + 1)
                }
            } else {
                losses += 1
            }
        }

        return EquityResult(
            equity: equityPoints / Double(max(1, wins + ties + losses)),
            winCount: wins,
            tieCount: ties,
            lossCount: losses,
            simulations: wins + ties + losses
        )
    }

    private static func drawOpponentHand(
        from deck: inout [Card],
        allowedHands: Set<StartingHand>,
        rng: inout SystemRandomNumberGenerator
    ) -> [Card]? {
        guard deck.count >= 2 else { return nil }

        if allowedHands.count >= PreflopAnalyzer.allStartingHands.count {
            return [deck.removeLast(), deck.removeLast()]
        }

        for _ in 0..<90 {
            let firstIndex = Int.random(in: 0..<deck.count, using: &rng)
            var secondIndex = Int.random(in: 0..<deck.count, using: &rng)
            while secondIndex == firstIndex {
                secondIndex = Int.random(in: 0..<deck.count, using: &rng)
            }

            let first = deck[firstIndex]
            let second = deck[secondIndex]
            if allowedHands.contains(StartingHand(first, second)) {
                removeCards([first, second], from: &deck)
                return [first, second]
            }
        }

        var matchingHands: [[Card]] = []
        for firstIndex in 0..<(deck.count - 1) {
            for secondIndex in (firstIndex + 1)..<deck.count {
                let hand = [deck[firstIndex], deck[secondIndex]]
                if allowedHands.contains(StartingHand(hand[0], hand[1])) {
                    matchingHands.append(hand)
                }
            }
        }

        if let hand = matchingHands.randomElement(using: &rng) {
            removeCards(hand, from: &deck)
            return hand
        }

        return [deck.removeLast(), deck.removeLast()]
    }

    private static func removeCards(_ cards: [Card], from deck: inout [Card]) {
        for card in cards {
            if let index = deck.firstIndex(of: card) {
                deck.remove(at: index)
            }
        }
    }
}
