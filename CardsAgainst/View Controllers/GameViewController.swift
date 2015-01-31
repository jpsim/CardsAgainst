//
//  GameViewController.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/2/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit
import Cartography

private typealias KVOContext = UInt8
private var blackLabelBoundsKVOContext = KVOContext()
private let boundsKeyPath = "bounds"

final class GameViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    // MARK: Properties

    // Data
    private var gameState = GameState.PickingCard
    private var blackCard: Card
    private var whiteCards: [Card]
    private var answers = [Answer]()
    private var votes = [Vote]()
    private var numberOfCardsPlayed = 0
    private var scores = [Player: Int]()
    private var hasVoted: Bool = false {
        didSet {
            voteButton.tintColor = hasVoted ? lightColor : appTintColor
            voteButton.userInteractionEnabled = !hasVoted
            scrollViewDidEndDecelerating(scrollView)
        }
    }

    // UI
    private let blackCardLabel = TouchableLabel()
    private let whiteCardCollectionView = UICollectionView(frame: CGRectZero,
        collectionViewLayout: WhiteCardFlowLayout())
    private let pageControl = UIPageControl()
    private let scrollView = UIScrollView()
    private let scrollViewContentView = UIView()
    private let voteButton = UIButton.buttonWithType(.System) as UIButton

    // UI Helper
    private var blackCardLabelBottomConstraint = NSLayoutConstraint()
    private var otherBlackCardViews = [UIView]()
    private let cellHeights = NSCache()

    // Computed Properties
    private var voteeForCurrentPage: Player {
        return voteeForPage(pageControl.currentPage)
    }
    private var hasEveryPeerAnswered: Bool {
        return answers.count == ConnectionManager.otherPlayers.count
    }
    private var hasEveryPeerVoted: Bool {
        return votes.count == ConnectionManager.allPlayers.count
    }
    private var winner: Player? {
        if votes.count < 2 {
            return nil
        }
        var votesForPlayers = [Player: Int]()
        for votee in votes.map({$0.votee}) {
            if let freq = votesForPlayers[votee] {
                votesForPlayers[votee] = freq + 1
            } else {
                votesForPlayers[votee] = 1
            }
        }
        if votesForPlayers.count == 1 {
            return votesForPlayers.keys.first!
        }
        let sortedVotes = votesForPlayers.values.array.sorted { $0 > $1 }
        let maxVotes = sortedVotes[0]
        if maxVotes == sortedVotes[1] {
            return nil // Tie
        }
        return votesForPlayers.keys.array.filter({votesForPlayers[$0] == maxVotes}).first!
    }
    private var stats: String {
        return join("\n", scores.keys.array.map({ "\($0.displayName): \(self.scores[$0])" }))
    }
    private var unansweredPlayers: [Player] {
        let answeredPlayers = answers.map { $0.sender }
        return ConnectionManager.otherPlayers.filter { !contains(answeredPlayers, $0) }
    }
    private var waitingForPeersMessage: String {
        return "Waiting for " + join(", ", unansweredPlayers.map({$0.name}))
    }

    // MARK: View Lifecycle

    init(blackCard: Card, whiteCards: [Card]) {
        self.blackCard = blackCard
        self.whiteCards = whiteCards

        super.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController!.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: .Default)
        navigationController!.navigationBar.shadowImage = UIImage()
        cellHeights.countLimit = 20
        view.backgroundColor = appBackgroundColor

        updateTitle()

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Stats",
            style: .Plain,
            target: self,
            action: "showStats")

        // UI
        setupVoteButton()
        setupPageControl()
        setupScrollView()
        setupWhiteCardCollectionView()
        setupBlackCard()

        // Other setup
        blackCardLabel.text = blackCard.content
        blackCardLabel.font = UIFont.blackCardFont
        whiteCardCollectionView.reloadData()

        for player in ConnectionManager.allPlayers {
            scores[player] = 0
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        // KVO
        blackCardLabel.addObserver(self,
            forKeyPath: boundsKeyPath,
            options: .New,
            context: &blackLabelBoundsKVOContext)

        setupMultipeerEventHandlers()
    }

    override func viewWillDisappear(animated: Bool) {
        blackCardLabel.removeObserver(self, forKeyPath: boundsKeyPath)
        let observedEvents: [Event] = [.Answer, .CancelAnswer, .Vote, .NextCard, .EndGame]
        for event in observedEvents {
            ConnectionManager.onEvent(event, run: nil)
        }

        super.viewWillDisappear(animated)
    }

    // MARK: UI Setup

    private func setupVoteButton() {
        // Button
        voteButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.addSubview(voteButton)
        voteButton.enabled = false
        voteButton.titleLabel?.numberOfLines = 0
        voteButton.titleLabel?.textAlignment = .Center
        voteButton.titleLabel?.font = UIFont.voteButtonFont
        voteButton.addTarget(self, action: "vote", forControlEvents: .TouchUpInside)

        // Layout
        layout(voteButton) { voteButton in
            voteButton.bottom == voteButton.superview!.bottom - 16
            voteButton.centerX == voteButton.superview!.centerX
            voteButton.width == voteButton.superview!.width - 32
        }
    }

    private func setupPageControl() {
        // Page Control
        pageControl.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.addSubview(pageControl)
        pageControl.numberOfPages = ConnectionManager.otherPlayers.count + 1

        // Layout
        layout(pageControl, voteButton) { pageControl, voteButton in
            pageControl.bottom == voteButton.top
            pageControl.centerX == pageControl.superview!.centerX
        }
    }

    private func setupScrollView() {
        // Scroll View
        scrollView.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.addSubview(scrollView)
        scrollView.delegate = self
        scrollView.scrollEnabled = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.pagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false

        // Layout
        layout(scrollView) { scrollView in
            scrollView.edges == scrollView.superview!.edges; return
        }

        // Scroll View Content View
        scrollViewContentView.frame = view.bounds
        scrollView.addSubview(scrollViewContentView)
    }

    private func setupBlackCard() {
        // Label
        blackCardLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        scrollViewContentView.addSubview(blackCardLabel)
        blackCardLabel.contentMode = .Top
        blackCardLabel.textColor = lightColor
        blackCardLabel.numberOfLines = 0
        blackCardLabel.minimumScaleFactor = 0.5
        blackCardLabel.adjustsFontSizeToFitWidth = true

        // Layout
        layout(blackCardLabel, scrollViewContentView) { blackCardLabel, scrollViewContentView in
            blackCardLabel.top == scrollViewContentView.top + 64
            blackCardLabel.width == scrollViewContentView.width - 32
            blackCardLabel.leading == scrollViewContentView.leading + 16
            self.blackCardLabelBottomConstraint = (blackCardLabel.bottom <= scrollViewContentView.bottom - 200)
        }

        // Gesture
        blackCardLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "removeLastWhiteCard"))
    }

    private func setupWhiteCardCollectionView() {
        // Collection View
        whiteCardCollectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        scrollViewContentView.addSubview(whiteCardCollectionView)
        whiteCardCollectionView.registerClass(WhiteCardCell.self,
            forCellWithReuseIdentifier: WhiteCardCell.reuseID)
        whiteCardCollectionView.showsVerticalScrollIndicator = false
        whiteCardCollectionView.alwaysBounceVertical = true
        whiteCardCollectionView.dataSource = self
        whiteCardCollectionView.delegate = self
        whiteCardCollectionView.backgroundColor = appBackgroundColor

        // Layout
        layout(whiteCardCollectionView) { whiteCardCollectionView in
            whiteCardCollectionView.edges == whiteCardCollectionView.superview!.edges; return
        }
    }

    // MARK: UI Derived

    override func didMoveToParentViewController(parent: UIViewController?) {
        // User initiated pop
        if parent == nil {
            ConnectionManager.sendEvent(.EndGame)
        }
    }

    private func updateTitle() {
        title = "Card \(++numberOfCardsPlayed)"
    }

    private func prepareForBlackCards() {
        scrollView.contentSize = CGSizeMake(self.view.frame.size.width, 0)
        voteButton.enabled = false
        pageControl.alpha = 0

        for view in otherBlackCardViews {
            view.removeFromSuperview()
        }
        otherBlackCardViews.removeAll(keepCapacity: true)

        if hasEveryPeerAnswered {
            pickWinner()
        } else {
            updateWaitingForPeers()
        }
    }

    private func updateWaitingForPeers() {
        if unansweredPlayers.count > 0 {
            voteButton.setTitle(waitingForPeersMessage, forState: .Disabled)
        } else {
            updateVoteButton()
        }
    }

    private func updateVoteButton() {
        let cardString = voteeForCurrentPage.cardString(hasVoted)
        let votesString = Vote.stringFromVoteCount(voteCountForPage(pageControl.currentPage))
        voteButton.setTitle("\(cardString) (\(votesString))", forState: .Normal)
    }

    private func generateBlackCards() {
        pageControl.numberOfPages = answers.count + 1
        scrollView.contentSize = CGSizeMake(view.frame.size.width * CGFloat(pageControl.numberOfPages), 0)
        for (index, answer) in enumerate(answers) {
            // Content View
            let contentFrame = CGRectOffset(scrollViewContentView.frame,
                scrollViewContentView.frame.size.width * CGFloat(index + 1),
                0)
            let contentView = UIView(frame: contentFrame)
            scrollView.addSubview(contentView)
            otherBlackCardViews.append(contentView)

            // Black Card Label
            let blackCardLabel = TouchableLabel()
            blackCardLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
            contentView.addSubview(blackCardLabel)
            blackCardLabel.contentMode = .Top
            blackCardLabel.textColor = lightColor
            blackCardLabel.numberOfLines = 0
            blackCardLabel.minimumScaleFactor = 0.5
            blackCardLabel.adjustsFontSizeToFitWidth = true

            blackCardLabel.attributedText = answer.answer
            blackCardLabel.font = self.blackCardLabel.font // override remote font size with our own screen-specific size

            // Layout
            layout(blackCardLabel, contentView) { blackCardLabel, contentView in
                blackCardLabel.top == contentView.top + 64
                blackCardLabel.width == contentView.width - 32
                blackCardLabel.leading == contentView.leading + 16
                blackCardLabel.bottom <= contentView.bottom - 80
            }
        }
    }

    // MARK: Multipeer

    private func setupMultipeerEventHandlers() {
        // Answer
        ConnectionManager.onEvent(.Answer) { peer, object in
            let dict = object as [String: NSData]
            let attr = MPCAttributedString(mpcSerialized: dict["answer"]!).attributedString
            self.answers.append(Answer(sender: Player(peer: peer), answer: attr))
            self.updateWaitingForPeers()
            if self.gameState != .PickingCard && self.hasEveryPeerAnswered {
                self.pickWinner()
            }
        }

        // Cancel Answer
        ConnectionManager.onEvent(.CancelAnswer) { peer, object in
            let sender = Player(peer: peer)
            let previousCount = self.answers.count
            self.answers = self.answers.filter { $0.sender != sender }
            self.updateWaitingForPeers()
        }

        // Vote
        ConnectionManager.onEvent(.Vote) { peer, object in
            let voter = Player(peer: peer)
            let votee = Player(mpcSerialized: (object as [String: NSData])["votee"]!)
            self.addVote(voter, to: votee)
        }

        // Next Card
        ConnectionManager.onEvent(.NextCard) { _, object in
            let dict = object as [String: NSData]
            let winner = Player(mpcSerialized: dict["winner"]!)
            let blackCard = Card(mpcSerialized: dict["blackCard"]!)
            let whiteCards = CardArray(mpcSerialized: dict["whiteCards"]!).array
            self.scores[winner]!++
            self.nextBlackCard(blackCard, newWhiteCards: whiteCards, winner: winner)
        }

        // End Game
        ConnectionManager.onEvent(.EndGame) { _, _ in
            self.dismiss()
        }
    }

    // MARK: Actions

    private func dismiss() {
        navigationController?.popViewControllerAnimated(true)
    }

    private func nextCardWithWinner(winner: Player) {
        let blackCard = CardManager.nextCardsWithType(.Black).first!
        scores[winner]!++
        ConnectionManager.sendEventForEach(.NextCard) {
            let nextWhiteCards = CardManager.nextCardsWithType(.White, count: 10 - self.whiteCards.count)
            let payload: [String: MPCSerializable] = [
                "blackCard": blackCard,
                "whiteCards": CardArray(array: nextWhiteCards),
                "winner": winner
            ]
            return payload
        }
        let newWhiteCards = CardManager.nextCardsWithType(.White, count: 10 - whiteCards.count)
        nextBlackCard(blackCard, newWhiteCards: newWhiteCards, winner: winner)
    }

    private func nextBlackCard(blackCard: Card, newWhiteCards: [Card], winner: Player) {
        showWinner(winner)
        answers = [Answer]()
        pageControl.currentPage = 0
        blackCardLabel.userInteractionEnabled = true
        gameState = .PickingCard
        blackCardLabel.placeholderRanges = [NSRange]()
        scrollView.contentOffset = CGPointZero
        blackCardLabelBottomConstraint.constant = -200
        scrollView.scrollEnabled = false
        view.sendSubviewToBack(voteButton)
        view.sendSubviewToBack(pageControl)

        blackCardLabel.text = blackCard.content
        blackCardLabel.font = UIFont.blackCardFont
        whiteCards += newWhiteCards
        whiteCardCollectionView.reloadData()
        whiteCardCollectionView.scrollRectToVisible(CGRectMake(0, 0, 1, 1), animated: false)
        UIView.animateWithDuration(0.33) {
            self.whiteCardCollectionView.alpha = 1
            self.scrollView.scrollEnabled = false
            self.scrollViewContentView.layoutSubviews()
            self.viewDidLayoutSubviews()
        }
        for view in otherBlackCardViews {
            view.removeFromSuperview()
        }
        otherBlackCardViews.removeAll(keepCapacity: true)
        votes = [Vote]()
        hasVoted = false
        updateTitle()
    }

    // MARK: HUD

    private func showWinner(winner: Player) {
        showHUD("\(winner.winningString())\n\n\(stats)", duration: 2)
    }

    private func showStats() {
        showHUD(stats)
    }

    private func showHUD(status: String, duration: Double = 1) {
        SVProgressHUD.showWithStatus(status, maskType: .Black)
        let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(duration * Double(NSEC_PER_SEC)))
        dispatch_after(delay, dispatch_get_main_queue()) {
            SVProgressHUD.dismiss()
        }
    }

    // MARK: Voting

    private func vote() {
        if hasVoted {
            return
        }
        let votee = voteeForCurrentPage
        addVote(Player.getMe(), to: votee)
        hasVoted = true
        ConnectionManager.sendEvent(.Vote, object: ["votee": votee])

        if hasEveryPeerVoted {
            if let winner = winner {
                nextCardWithWinner(winner)
            } else {
                handleTie()
            }
        }
    }

    private func addVote(from: Player, to: Player) {
        votes.append(Vote(votee: to, voter: from))
        if gameState != .PickingCard {
            scrollViewDidEndDecelerating(scrollView)
        }
    }

    private func handleTie() {
        let alert = UIAlertController(title: "Tie Breaker!",
            message: "There was a tie! You picked last, so you decide who wins",
            preferredStyle: .Alert)
        for player in ConnectionManager.allPlayers {
            alert.addAction(UIAlertAction(title: player.name,
                style: .Default) { _ in
                    self.nextCardWithWinner(player)
                })
        }
        presentViewController(alert, animated: true) {}
    }

    private func pickWinner() {
        if gameState != .WaitingForOthers {
            return
        }
        gameState = .PickingWinner
        scrollViewDidEndDecelerating(scrollView)
        voteButton.enabled = true
        scrollView.contentOffset = CGPointZero
        generateBlackCards()
        blackCardLabel.userInteractionEnabled = false
        UIView.animateWithDuration(2) {
            self.pageControl.alpha = 1
        }
    }

    // MARK: Adding/Removing Cards

    private func addSelectedCardToBlackCard(selectedCard: Card) {
        if let range = blackCardLabel.text?.rangeOfString(blackCardPlaceholder) {
            blackCardLabel.text = blackCardLabel.text?.stringByReplacingCharactersInRange(range, withString: selectedCard.content)
            let start = distance(blackCardLabel.text!.startIndex, range.startIndex)
            let length = countElements(selectedCard.content)
            blackCardLabel.placeholderRanges.append(NSMakeRange(start, length))
        } else {
            let range = NSMakeRange(countElements(blackCardLabel.text!)+1, countElements(selectedCard.content))
            blackCardLabel.placeholderRanges.append(range)
            blackCardLabel.text! += "\n\(selectedCard.content)"
        }
        let blackCardStyled = NSMutableAttributedString(string: blackCardLabel.text!)
        for range in blackCardLabel.placeholderRanges {
            blackCardStyled.addAttribute(NSForegroundColorAttributeName, value: appTintColor, range: range)
        }
        blackCardLabel.attributedText = blackCardStyled
        if blackCardLabel.text?.rangeOfString(blackCardPlaceholder) == nil {
            gameState = .WaitingForOthers
            blackCardLabel.font = UIFont.blackCardFont
            blackCardLabelBottomConstraint.constant = -80
            UIView.animateWithDuration(0.33, {
                self.whiteCardCollectionView.alpha = 0
                self.scrollView.scrollEnabled = true
                self.scrollViewContentView.layoutSubviews()
                self.viewDidLayoutSubviews()
                }, completion: { _ in
                    self.view.bringSubviewToFront(self.voteButton)
            })

            let attr = MPCAttributedString(attributedString: blackCardLabel.attributedText)
            ConnectionManager.sendEvent(.Answer, object: ["answer": attr])
            prepareForBlackCards()
        }
    }

    private func removeLastWhiteCard() {
        if let lastRange = blackCardLabel.placeholderRanges.last {
            let blackCardLabelNSString = blackCardLabel.text! as NSString
            whiteCardCollectionView.performBatchUpdates({
                let content = blackCardLabelNSString.substringWithRange(lastRange)
                let lastWhiteCard = Card(content: content, type: .White, expansion: "")
                self.whiteCards.append(lastWhiteCard)
                let indexPath = NSIndexPath(forItem: self.whiteCards.count - 1, inSection: 0)
                self.whiteCardCollectionView.insertItemsAtIndexPaths([indexPath])
                }, nil)
            blackCardLabel.text = blackCardLabelNSString.stringByReplacingCharactersInRange(lastRange, withString: blackCardPlaceholder)
            let placeholderlessLength = countElements(blackCardPlaceholder) + 1

            let blackCardLabelSubstring = blackCardLabelNSString.substringFromIndex(blackCardLabelNSString.length - placeholderlessLength)
            if blackCardLabelSubstring == "\n\(blackCardPlaceholder)" {
                blackCardLabel.text = blackCardLabelNSString.substringToIndex(blackCardLabelNSString.length - placeholderlessLength)
            }
            blackCardLabel.placeholderRanges.removeLast()
            let blackCardStyled = NSMutableAttributedString(string: blackCardLabel.text!)
            for range in blackCardLabel.placeholderRanges {
                blackCardStyled.addAttribute(NSForegroundColorAttributeName, value: appTintColor, range: range)
            }
            blackCardLabel.attributedText = blackCardStyled
            gameState = .PickingCard
            blackCardLabel.font = UIFont.blackCardFont
            view.sendSubviewToBack(voteButton)
            view.sendSubviewToBack(pageControl)
            blackCardLabelBottomConstraint.constant = -200
            UIView.animateWithDuration(0.33) {
                self.whiteCardCollectionView.alpha = 1
                self.scrollView.scrollEnabled = false
                self.scrollViewContentView.layoutSubviews()
                self.viewDidLayoutSubviews()
            }
            ConnectionManager.sendEvent(.CancelAnswer)
        }
    }

    private func removeCardAtIndexPath(indexPath: NSIndexPath) {
        if gameState == .PickingWinner {
            return
        }
        whiteCardCollectionView.performBatchUpdates({
            self.whiteCardCollectionView.deleteItemsAtIndexPaths([indexPath])
            self.whiteCards.removeAtIndex(indexPath.row)
            }, nil)
    }

    // MARK: Logic

    private func voteCountForPage(page: Int) -> Int {
        let votee = voteeForPage(page)
        return votes.filter({ $0.votee.name == votee.name }).count
    }

    private func voteeForPage(page: Int) -> Player {
        if page > 0 {
            return answers[page - 1].sender
        } else {
            return Player.getMe()
        }
    }

    // MARK: UICollectionViewDataSource

    func collectionView(collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int {
        return whiteCards.count
    }

    func collectionView(collectionView: UICollectionView,
        cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(WhiteCardCell.reuseID,
            forIndexPath: indexPath) as WhiteCardCell
        cell.label.text = whiteCards[indexPath.row].content
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        return cell
    }

    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let hash = whiteCards[indexPath.row].content.hash
        var size = CGSizeMake(view.frame.size.width - 32, 50)
        if let heightNumber = cellHeights.objectForKey(hash) as? NSNumber {
            size.height = CGFloat(heightNumber.floatValue)
            return size
        }
        let cell = WhiteCardCell(frame: CGRectMake(0, 0, size.width, size.height))
        cell.label.text = whiteCards[indexPath.row].content
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        let cellSize = cell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        size.height = cellSize.height + 1
        cellHeights.setObject(size.height, forKey: hash)

        return size
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(collectionView: UICollectionView,
        didSelectItemAtIndexPath indexPath: NSIndexPath) {
        addSelectedCardToBlackCard(whiteCards[indexPath.row])
        removeCardAtIndexPath(indexPath)
    }

    // MARK: Paging

    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if scrollView == self.scrollView {
            let page = round(scrollView.contentOffset.x / scrollView.frame.size.width)
            pageControl.currentPage = Int(page)
            updateVoteButton()
        }
    }

    // MARK: KVO

    override func observeValueForKeyPath(keyPath: String,
        ofObject object: AnyObject,
        change: [NSObject : AnyObject],
        context: UnsafeMutablePointer<()>) {
        if context == &blackLabelBoundsKVOContext {
            whiteCardCollectionView.contentInset = UIEdgeInsetsMake(blackCardLabel.frame.size.height + 20 + 64, 0, 20, 0)
            whiteCardCollectionView.scrollRectToVisible(CGRectMake(0, 0, 1, 1), animated: true)
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}
