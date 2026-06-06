import Testing
@testable import startdezhou

struct startdezhouTests {
    @Test func straightFlushBeatsFourOfAKind() {
        let straightFlush = PokerHandEvaluator.evaluate([
            card(.ace, .spades),
            card(.king, .spades),
            card(.queen, .spades),
            card(.jack, .spades),
            card(.ten, .spades),
            card(.two, .clubs),
            card(.three, .diamonds)
        ])

        let quads = PokerHandEvaluator.evaluate([
            card(.ace, .spades),
            card(.ace, .hearts),
            card(.ace, .diamonds),
            card(.ace, .clubs),
            card(.king, .spades),
            card(.two, .clubs),
            card(.three, .diamonds)
        ])

        #expect(straightFlush > quads)
        #expect(straightFlush.displayName == "皇家同花顺")
    }

    @Test func wheelStraightIsDetected() {
        let value = PokerHandEvaluator.evaluate([
            card(.ace, .spades),
            card(.two, .hearts),
            card(.three, .clubs),
            card(.four, .diamonds),
            card(.five, .spades),
            card(.king, .clubs),
            card(.nine, .diamonds)
        ])

        #expect(value.category == .straight)
        #expect(value.kickers == [Rank.five.rawValue])
    }

    @Test func preflopRangeIncludesPremiumAndExcludesTrash() {
        let aces = StartingHand(card(.ace, .spades), card(.ace, .hearts))
        let sevenTwoOff = StartingHand(card(.seven, .spades), card(.two, .hearts))

        #expect(PreflopAnalyzer.contains(aces, inTopPercent: 2))
        #expect(!PreflopAnalyzer.contains(sevenTwoOff, inTopPercent: 35))
    }

    @Test func buttonOpenRangeIsWiderThanUnderTheGun() {
        let button = RangeAdvisor.heroActionPercent(position: .button, action: .openRaise)
        let underTheGun = RangeAdvisor.heroActionPercent(position: .underTheGun, action: .openRaise)

        #expect(button > underTheGun)
    }

    @Test func equityResultStaysInValidRange() {
        let result = EquityCalculator.calculate(input: EquityInput(
            heroCards: [
                card(.ace, .spades),
                card(.ace, .hearts)
            ],
            boardCards: [],
            opponentCount: 1,
            opponentRangePercent: 100,
            iterations: 300
        ))

        #expect(result.simulations == 300)
        #expect(result.equity >= 0)
        #expect(result.equity <= 1)
        #expect(result.equity > 0.5)
    }

    @Test func tableEquityUsesKnownOpponentHands() async {
        let result = await TableEquityCalculator.calculate(input: TableEquityInput(
            heroCards: [
                card(.ace, .spades),
                card(.ace, .hearts)
            ],
            opponentHands: [
                [
                    card(.king, .spades),
                    card(.king, .hearts)
                ]
            ],
            boardCards: [],
            iterations: 500
        ))

        #expect(result.simulations == 500)
        #expect(result.equity > 0.65)
        #expect(result.equity <= 1)
    }

    @Test func completeBoardTableEquityResolvesOnce() async {
        let result = await TableEquityCalculator.calculate(input: TableEquityInput(
            heroCards: [
                card(.ace, .spades),
                card(.ace, .hearts)
            ],
            opponentHands: [
                [
                    card(.king, .spades),
                    card(.king, .hearts)
                ]
            ],
            boardCards: [
                card(.two, .clubs),
                card(.three, .diamonds),
                card(.four, .spades),
                card(.eight, .clubs),
                card(.nine, .diamonds)
            ],
            iterations: 500
        ))

        #expect(result.simulations == 1)
        #expect(result.winCount == 1)
        #expect(result.equity == 1)
    }

    @Test @MainActor func callActionMatchesPreviousBetAmount() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.lineActor = .hero
        viewModel.lineAction = .bet
        viewModel.lineAmount = 15
        viewModel.addActionLineEntry()

        viewModel.selectLineAction(.call)

        #expect(viewModel.lineActor == .opponent)
        #expect(viewModel.lineAmount == 15)
    }

    @Test func defaultSeatsIncludeStackAmounts() {
        #expect(PlayerSeat.defaults.count == 9)
        #expect(PlayerSeat.defaults.allSatisfy { $0.stackAmount == 200 })
    }

    @Test @MainActor func reviewOpponentSelectionControlsEquityHands() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.playerSeats[0].cards = [
            card(.ace, .spades),
            card(.ace, .hearts)
        ]
        viewModel.playerSeats[1].cards = [
            card(.king, .spades),
            card(.king, .hearts)
        ]
        viewModel.playerSeats[2].cards = [
            card(.queen, .spades),
            card(.queen, .hearts)
        ]

        #expect(viewModel.knownOpponentHands.isEmpty)
        #expect(!viewModel.canCalculate)

        viewModel.toggleReviewOpponent(2)

        #expect(viewModel.activeOpponentCount == 1)
        #expect(viewModel.knownOpponentHands == [[
            card(.queen, .spades),
            card(.queen, .hearts)
        ]])
        #expect(viewModel.canCalculate)

        viewModel.toggleReviewOpponent(3)

        #expect(viewModel.selectedIncompleteOpponentCount == 1)
        #expect(!viewModel.canCalculate)
    }

    @Test @MainActor func foldedOpponentIsRemovedFromEquityButKeptAsDeadCards() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.playerSeats[0].cards = [
            card(.ace, .spades),
            card(.ace, .hearts)
        ]
        viewModel.playerSeats[1].cards = [
            card(.king, .spades),
            card(.king, .hearts)
        ]
        viewModel.playerSeats[2].cards = [
            card(.queen, .spades),
            card(.queen, .hearts)
        ]
        viewModel.toggleReviewOpponent(1)
        viewModel.toggleReviewOpponent(2)

        viewModel.selectOpponentLineActor(seatID: 1)
        viewModel.lineAction = .fold
        viewModel.addActionLineEntry()

        #expect(viewModel.activeOpponentCount == 1)
        #expect(viewModel.equityOpponentCountText == "1/2")
        #expect(viewModel.knownOpponentHands == [[
            card(.queen, .spades),
            card(.queen, .hearts)
        ]])
        #expect(Set(viewModel.foldedOpponentDeadCards) == Set([
            card(.king, .spades),
            card(.king, .hearts)
        ]))
        #expect(viewModel.canCalculate)
    }

    @Test @MainActor func allOpponentsFoldLeavesHeroWithCompleteEquityContext() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.playerSeats[0].cards = [
            card(.ace, .spades),
            card(.ace, .hearts)
        ]
        viewModel.playerSeats[1].cards = [
            card(.king, .spades),
            card(.king, .hearts)
        ]
        viewModel.toggleReviewOpponent(1)

        viewModel.selectOpponentLineActor(seatID: 1)
        viewModel.lineAction = .fold
        viewModel.addActionLineEntry()

        #expect(viewModel.activeOpponentCount == 0)
        #expect(viewModel.equityOpponentCountText == "0/1")
        #expect(viewModel.knownOpponentHands.isEmpty)
        #expect(viewModel.canCalculate)
    }

    @Test @MainActor func heroFoldBlocksEquityCalculation() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.playerSeats[0].cards = [
            card(.ace, .spades),
            card(.ace, .hearts)
        ]
        viewModel.playerSeats[1].cards = [
            card(.king, .spades),
            card(.king, .hearts)
        ]
        viewModel.toggleReviewOpponent(1)

        viewModel.selectHeroLineActor()
        viewModel.lineAction = .fold
        viewModel.addActionLineEntry()

        #expect(viewModel.heroHasFolded)
        #expect(!viewModel.canCalculate)
        #expect(viewModel.calculationStatusText == "行动线里我已弃牌，本手已结束")
    }

    @Test @MainActor func actionLineEntryKeepsSelectedOpponentSeat() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.toggleReviewOpponent(1)
        viewModel.selectOpponentLineActor(seatID: 1)
        viewModel.lineAction = .bet
        viewModel.lineAmount = 8

        viewModel.addActionLineEntry()

        let entry = viewModel.actionLineEntries[0]
        #expect(entry.actor == .opponent)
        #expect(entry.actorSeatID == 1)
        #expect(entry.displayActorName == "P2·SB")
    }

    @Test @MainActor func seatActionHelpersTrackReplayOrder() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.toggleReviewOpponent(1)

        viewModel.selectHeroLineActor()
        viewModel.lineAction = .bet
        viewModel.lineAmount = 8
        viewModel.addActionLineEntry()

        viewModel.selectOpponentLineActor(seatID: 1)
        viewModel.lineAction = .call
        viewModel.lineAmount = 8
        viewModel.addActionLineEntry()

        viewModel.selectHeroLineActor()
        viewModel.lineAction = .check
        viewModel.addActionLineEntry()

        #expect(viewModel.isSeatInPot(0))
        #expect(viewModel.isSeatInPot(1))
        #expect(viewModel.latestActionNumber(for: 0) == 3)
        #expect(viewModel.latestActionNumber(for: 1) == 2)
        #expect(viewModel.lastActionEntry(for: 0)?.action == .check)
        #expect(viewModel.lastActionEntry(for: 1)?.action == .call)
    }

    @Test @MainActor func actionLineAdvancesThroughSeatsInOrder() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.toggleReviewOpponent(1)
        viewModel.toggleReviewOpponent(2)

        #expect(viewModel.currentActionSeatOrderIDs == [0, 1, 2])

        viewModel.selectHeroLineActor()
        viewModel.lineAction = .bet
        viewModel.lineAmount = 8
        viewModel.addActionLineEntry()

        #expect(viewModel.lineActor == .opponent)
        #expect(viewModel.lineOpponentSeatID == 1)

        viewModel.lineAction = .call
        viewModel.lineAmount = 8
        viewModel.addActionLineEntry()

        #expect(viewModel.lineActor == .opponent)
        #expect(viewModel.lineOpponentSeatID == 2)

        viewModel.lineAction = .call
        viewModel.lineAmount = 8
        viewModel.addActionLineEntry()

        #expect(viewModel.lineActor == .hero)
        #expect(viewModel.lineOpponentSeatID == nil)
    }

    @Test @MainActor func actionLineSkipsFoldedSeatWhenAdvancing() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.toggleReviewOpponent(1)
        viewModel.toggleReviewOpponent(2)

        viewModel.selectOpponentLineActor(seatID: 1)
        viewModel.lineAction = .fold
        viewModel.addActionLineEntry()

        #expect(viewModel.foldedReviewOpponentIDs.contains(1))
        #expect(viewModel.currentActionSeatOrderIDs == [0, 2])
        #expect(viewModel.lineActor == .opponent)
        #expect(viewModel.lineOpponentSeatID == 2)
    }

    @Test @MainActor func autoDealBoardCardsFollowsStreetProgression() {
        let viewModel = PokerCalculatorViewModel()
        let heroCards = [
            card(.ace, .spades),
            card(.ace, .hearts)
        ]
        viewModel.playerSeats[0].cards = heroCards

        viewModel.autoDealBoardCards()

        #expect(viewModel.boardVisibleCards.count == 3)
        #expect(Set(viewModel.boardVisibleCards).count == 3)
        #expect(Set(viewModel.boardVisibleCards).isDisjoint(with: Set(heroCards)))
        #expect(viewModel.streetName == "翻牌")

        viewModel.autoDealBoardCards()

        #expect(viewModel.boardVisibleCards.count == 4)
        #expect(Set(viewModel.boardVisibleCards).count == 4)
        #expect(viewModel.streetName == "转牌")

        viewModel.autoDealBoardCards()

        #expect(viewModel.boardVisibleCards.count == 5)
        #expect(Set(viewModel.boardVisibleCards).count == 5)
        #expect(viewModel.streetName == "河牌")

        viewModel.autoDealBoardCards()

        #expect(viewModel.boardVisibleCards.count == 3)
        #expect(Set(viewModel.boardVisibleCards).count == 3)
        #expect(Set(viewModel.boardVisibleCards).isDisjoint(with: Set(heroCards)))
    }

    @Test @MainActor func autoDealPlayerCardsFillsOnlyMissingCards() {
        let viewModel = PokerCalculatorViewModel()
        let fixedHeroCard = card(.ace, .spades)
        let fixedBoardCard = card(.king, .spades)
        viewModel.playerSeats[0].cards[0] = fixedHeroCard
        viewModel.boardCards[0] = fixedBoardCard

        viewModel.autoDealPlayerCards()

        let playerCards = viewModel.playerSeats.flatMap { $0.cards.compactMap { $0 } }

        #expect(playerCards.count == 18)
        #expect(Set(playerCards).count == 18)
        #expect(playerCards.contains(fixedHeroCard))
        #expect(!playerCards.contains(fixedBoardCard))
        #expect(viewModel.boardCards[0] == fixedBoardCard)
        #expect(viewModel.missingPlayerCardCount == 0)
        #expect(!viewModel.canAutoDealPlayerCards)
    }

    @Test @MainActor func allInActionOpensShowdownCardsForLiveSeats() {
        let viewModel = PokerCalculatorViewModel()
        let fixedHeroCard = card(.ace, .spades)
        viewModel.playerSeats[0].cards[0] = fixedHeroCard
        viewModel.toggleReviewOpponent(1)
        viewModel.toggleReviewOpponent(2)

        viewModel.selectOpponentLineActor(seatID: 1)
        viewModel.lineAction = .fold
        viewModel.addActionLineEntry()

        viewModel.selectHeroLineActor()
        viewModel.lineAction = .allIn
        viewModel.addActionLineEntry()

        let liveShowdownCards = [0, 2].flatMap { seatID in
            viewModel.playerSeats.first { $0.id == seatID }?.cards.compactMap { $0 } ?? []
        }
        let foldedSeatCards = viewModel.playerSeats.first { $0.id == 1 }?.cards.compactMap { $0 } ?? []

        #expect(viewModel.isShowdown)
        #expect(viewModel.playerSeats.first { $0.id == 0 }?.completeCards != nil)
        #expect(viewModel.playerSeats.first { $0.id == 2 }?.completeCards != nil)
        #expect(liveShowdownCards.count == 4)
        #expect(Set(liveShowdownCards).count == 4)
        #expect(liveShowdownCards.contains(fixedHeroCard))
        #expect(foldedSeatCards.isEmpty)
    }

    @Test @MainActor func riverCallOpensShowdownCardsForSelectedSeats() {
        let viewModel = PokerCalculatorViewModel()
        viewModel.toggleReviewOpponent(4)
        viewModel.lineStreet = .river
        viewModel.selectOpponentLineActor(seatID: 4)
        viewModel.lineAction = .call
        viewModel.lineAmount = 30

        viewModel.addActionLineEntry()

        let showdownCards = [0, 4].flatMap { seatID in
            viewModel.playerSeats.first { $0.id == seatID }?.cards.compactMap { $0 } ?? []
        }

        #expect(viewModel.isShowdown)
        #expect(viewModel.playerSeats.first { $0.id == 0 }?.completeCards != nil)
        #expect(viewModel.playerSeats.first { $0.id == 4 }?.completeCards != nil)
        #expect(showdownCards.count == 4)
        #expect(Set(showdownCards).count == 4)
    }

    @Test func buttonOpenRaiseUsesBigBlindAmount() {
        let advice = BetSizingAdvisor.advice(
            smallBlind: 5,
            bigBlind: 10,
            currentPot: 15,
            effectiveStackBB: 100,
            position: .button,
            action: .openRaise,
            boardCardCount: 0,
            madeHand: nil,
            draws: [],
            equity: nil,
            recommendation: ActionRecommendation(title: "主动进攻", detail: "", tone: .attack)
        )

        #expect(advice.amountText == "22 积分")
        #expect(advice.bbText == "2.2 BB")
        #expect(advice.amountLabel == "加注到总额")
        #expect(advice.potAmount == 15)
        #expect(advice.finalPotAmount == 37)
    }

    @Test func foldRecommendationReturnsZeroBet() {
        let advice = BetSizingAdvisor.advice(
            smallBlind: 1,
            bigBlind: 2,
            currentPot: 3,
            effectiveStackBB: 100,
            position: .underTheGun,
            action: .openRaise,
            boardCardCount: 0,
            madeHand: nil,
            draws: [],
            equity: nil,
            recommendation: ActionRecommendation(title: "倾向弃牌", detail: "", tone: .fold)
        )

        #expect(advice.amountText == "0 积分")
        #expect(advice.bbText == "0 BB")
        #expect(advice.finalPotAmount == 3)
    }

    @Test func continuationBetUsesVisiblePotAmount() {
        let advice = BetSizingAdvisor.advice(
            smallBlind: 1,
            bigBlind: 2,
            currentPot: 30,
            effectiveStackBB: 100,
            position: .button,
            action: .continuationBet,
            boardCardCount: 3,
            madeHand: nil,
            draws: ["同花听牌"],
            equity: 0.42,
            recommendation: ActionRecommendation(title: "半诈唬候选", detail: "", tone: .caution)
        )

        #expect(advice.amountLabel == "本次下注")
        #expect(advice.amountText == "15 积分")
        #expect(advice.potAmount == 30)
        #expect(advice.finalPotAmount == 45)
    }

    @Test func actionLineFlagsLooseDefenseAgainstAggression() {
        let advice = ActionLineAdvisor.advice(
            entries: [
                ActionLineEntry(street: .flop, actor: .opponent, action: .raise, amount: 18),
                ActionLineEntry(street: .flop, actor: .hero, action: .call, amount: 18)
            ],
            recommendation: ActionRecommendation(title: "减少投入", detail: "", tone: .fold),
            betSizingAdvice: BetSizingAdvice(
                title: "不建议投入",
                amount: 0,
                bbMultiple: 0,
                amountText: "0",
                detail: "",
                tone: .fold,
                bbText: "0 BB"
            ),
            startingHand: StartingHand(card(.seven, .spades), card(.two, .hearts)),
            madeHand: nil,
            draws: [],
            equity: 0.22,
            position: .button,
            bettingAction: .continuationBet,
            boardCardCount: 3,
            bigBlind: 2
        )

        #expect(advice.title == "行动线偏离较大")
        #expect(advice.findings.contains { $0.title == "投入偏宽" })
        #expect(advice.findings.contains { $0.title == "面对进攻防守偏宽" })
    }

    @Test func actionLineRewardsAggressionWithGoodSizing() {
        let advice = ActionLineAdvisor.advice(
            entries: [
                ActionLineEntry(street: .preflop, actor: .hero, action: .raise, amount: 22)
            ],
            recommendation: ActionRecommendation(title: "主动进攻", detail: "", tone: .attack),
            betSizingAdvice: BetSizingAdvice(
                title: "开池加注",
                amount: 22,
                bbMultiple: 2.2,
                amountText: "22",
                detail: "",
                tone: .attack,
                bbText: "2.2 BB"
            ),
            startingHand: StartingHand(card(.ace, .spades), card(.ace, .hearts)),
            madeHand: nil,
            draws: [],
            equity: nil,
            position: .button,
            bettingAction: .openRaise,
            boardCardCount: 0,
            bigBlind: 10
        )

        #expect(advice.title == "行动线基本合理")
        #expect(advice.findings.contains { $0.title == "主动性匹配" })
        #expect(advice.findings.contains { $0.title == "下注尺寸接近建议" })
    }
}

private func card(_ rank: Rank, _ suit: Suit) -> Card {
    Card(rank: rank, suit: suit)
}
