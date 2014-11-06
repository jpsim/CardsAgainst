//
//  GameViewController.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/2/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit
import Cartography
import PeerKit
import MultipeerConnectivity

typealias KVOContext = UInt8
var blackLabelBoundsKVOContext = KVOContext()
let boundsKeyPath = "bounds"

struct Vote {
    let votee: Player
    let voter: Player
}

struct Answer {
    let sender: Player
    let answer: NSAttributedString
}

final class GameViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate {

    // MARK: Properties

    private var blackCard: Card
    private var whiteCards: [Card]

    private var gameState = GameState.PickingCard
    private let blackCardLabel = TouchableLabel()
    private let whiteCardCollectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: WhiteCardFlowLayout())
    private let pageControl = UIPageControl()
    private let scrollView = UIScrollView()
    private let scrollViewContentView = UIView()
    private let voteButton = UIButton.buttonWithType(.System) as UIButton
    private var blackCardLabelBottomConstraint = NSLayoutConstraint()
    private var otherBlackCardViews = [UIView]()
    private var answers = [Answer]()
    private var numberOfCardsPlayed = 0
    private var votes = [Vote]()
    private var hasVoted: Bool = false {
        didSet {
            voteButton.tintColor = hasVoted ? lightColor : appTintColor
            voteButton.userInteractionEnabled = !hasVoted
            scrollViewDidEndDecelerating(scrollView)
        }
    }
    private var scores = [Player: Int]()
    private let cellHeights = NSCache()

    private var voteeForCurrentPage: Player { return voteeForPage(pageControl.currentPage) }
    private var hasEveryPeerAnswered: Bool { return answers.count == ConnectionManager.peers.count }
    private var hasEveryPeerVoted: Bool { return self.votes.count == ConnectionManager.allPlayers.count }
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
        var stats = ""
        for (index, score) in enumerate(scores) {
            stats += "\(score.0.displayName): \(score.1)"
            if index != scores.count - 1 {
                stats += "\n"
            }
        }
        return stats
    }
    private var unansweredPlayers: [Player] {
        let answeredPlayers = answers.map { $0.sender }
        return ConnectionManager.peers.filter { !contains(answeredPlayers, $0) }
    }
    private var waitingForPeersMessage: String {
        let names = (unansweredPlayers.map({$0.name}) as NSArray).componentsJoinedByString(", ")
        return "Waiting for \(names)"
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
        blackCardLabel.font = UIFont.boldSystemFontOfSize(35)
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

        // Notifications
        Client.sharedInstance.eventBlocks[MessageType.Answer.rawValue] = { peer, object in
            let dict = object as [String: NSData]
            let attr = MPCAttributedString(mpcSerialized: dict["answer"]!).attributedString
            self.answers.append(Answer(sender: Player(peer: peer), answer: attr))
            self.updateWaitingForPeers()
            if self.gameState != .PickingCard && self.hasEveryPeerAnswered {
                self.pickWinner()
            }
        }
        Client.sharedInstance.eventBlocks[MessageType.CancelAnswer.rawValue] = { peer, object in
            let sender = Player(peer: peer)
            let previousCount = self.answers.count
            self.answers = self.answers.filter { $0.sender != sender }
            self.updateWaitingForPeers()
        }
        Client.sharedInstance.eventBlocks[MessageType.Vote.rawValue] = { peer, object in
            let voter = Player(peer: peer)
            let votee = Player(mpcSerialized: (object as [String: NSData])["votee"]!)
            self.addVote(voter, to: votee)
        }
        Client.sharedInstance.eventBlocks[MessageType.NextCard.rawValue] = { _, object in
            let dict = object as [String: NSData]
            let winner = Player(mpcSerialized: dict["winner"]!)
            let blackCard = Card(mpcSerialized: dict["blackCard"]!)
            let whiteCards = CardArray(mpcSerialized: dict["whiteCards"]!).array
            self.scores[winner]!++
            self.nextBlackCard(blackCard, newWhiteCards: whiteCards, winner: winner)
        }
        Client.sharedInstance.eventBlocks[MessageType.EndGame.rawValue] = { _, _ in
            self.dismiss()
        }
    }

    override func viewWillDisappear(animated: Bool) {
        blackCardLabel.removeObserver(self, forKeyPath: boundsKeyPath)
        let observedMessageTypes: [MessageType] = [.Answer, .CancelAnswer, .Vote, .NextCard, .EndGame]
        for type in observedMessageTypes {
            Client.sharedInstance.eventBlocks.removeValueForKey(type.rawValue)
        }

        super.viewWillDisappear(animated)
    }

    // MARK: UI

    func updateTitle() {
        title = "Card \(++numberOfCardsPlayed)"
    }

    func showStats() {
        showHUD(stats)
    }

    func showHUD(status: String, duration: Double = 1) {
        SVProgressHUD.showWithStatus(status, maskType: .Black)
        let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(duration * Double(NSEC_PER_SEC)))
        dispatch_after(delay, dispatch_get_main_queue()) {
            SVProgressHUD.dismiss()
        }
    }

    func setupVoteButton() {
        // Button
        voteButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.addSubview(voteButton)
        voteButton.enabled = false
        voteButton.titleLabel?.numberOfLines = 0
        voteButton.titleLabel?.textAlignment = .Center
        voteButton.addTarget(self, action: "vote", forControlEvents: .TouchUpInside)

        // Layout
        layout(voteButton) { voteButton in
            voteButton.bottom == voteButton.superview!.bottom - 16
            voteButton.centerX == voteButton.superview!.centerX
            voteButton.width == voteButton.superview!.width - 32
        }
    }

    func setupPageControl() {
        // Page Control
        pageControl.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.addSubview(pageControl)
        pageControl.numberOfPages = ConnectionManager.peers.count + 1

        // Layout
        layout(pageControl, voteButton) { pageControl, voteButton in
            pageControl.bottom == voteButton.top
            pageControl.centerX == pageControl.superview!.centerX
        }
    }

    func setupScrollView() {
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

    func setupBlackCard() {
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

    func setupWhiteCardCollectionView() {
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

    // MARK: Actions

    override func didMoveToParentViewController(parent: UIViewController?) {
        // User initiated pop
        if parent == nil {
            ConnectionManager.sendMessage(.EndGame)
        }
    }

    func dismiss() {
        navigationController?.popViewControllerAnimated(true)
    }

    func nextCardWithWinner(winner: Player) {
        let blackCard = CardManager.nextCardsWithType(.Black).first!
        scores[winner]!++
        for peer in Client.sharedInstance.session!.connectedPeers as [MCPeerID] {
            let nextWhiteCards = CardManager.nextCardsWithType(.White, count: 10 - whiteCards.count)
            let payload = [
                "blackCard": blackCard.mpcSerialized,
                "whiteCards": CardArray(array: nextWhiteCards).mpcSerialized,
                "winner": winner.mpcSerialized
            ]
            ConnectionManager.sendMessage(.NextCard, object: payload, toPeers: [peer])
        }
        let newWhiteCards = CardManager.nextCardsWithType(.White, count: 10 - whiteCards.count)
        nextBlackCard(blackCard, newWhiteCards: newWhiteCards, winner: winner)
    }

    func nextBlackCard(blackCard: Card, newWhiteCards: [Card], winner: Player) {
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
        blackCardLabel.font = UIFont.boldSystemFontOfSize(35)
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

    func showWinner(winner: Player) {
        showHUD("\(winner.winningString())\n\n\(stats)", duration: 2)
    }

    func removeLastWhiteCard() {
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
            blackCardLabel.font = UIFont.boldSystemFontOfSize(35)
            view.sendSubviewToBack(voteButton)
            view.sendSubviewToBack(pageControl)
            blackCardLabelBottomConstraint.constant = -200
            UIView.animateWithDuration(0.33) {
                self.whiteCardCollectionView.alpha = 1
                self.scrollView.scrollEnabled = false
                self.scrollViewContentView.layoutSubviews()
                self.viewDidLayoutSubviews()
            }
            ConnectionManager.sendMessage(.CancelAnswer)
        }
    }

    func vote() {
        if hasVoted {
            return
        }
        let votee = voteeForCurrentPage
        addVote(Player.getMe(), to: votee)
        hasVoted = true
        ConnectionManager.sendMessage(.Vote, object: ["votee": votee.mpcSerialized])

        if hasEveryPeerVoted {
            if let winner = winner {
                nextCardWithWinner(winner)
            } else {
                handleTie()
            }
        }
    }

    func voteeForPage(page: Int) -> Player {
        if page > 0 {
            return answers[page - 1].sender
        } else {
            return Player.getMe()
        }
    }

    func addVote(from: Player, to: Player) {
        votes.append(Vote(votee: to, voter: from))
        if gameState != .PickingCard {
            scrollViewDidEndDecelerating(scrollView)
        }
    }

    func handleTie() {
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

    // MARK: UICollectionViewDataSource

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return whiteCards.count
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(WhiteCardCell.reuseID,
            forIndexPath: indexPath) as WhiteCardCell
        cell.label.text = whiteCards[indexPath.row].content
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        return cell
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
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
        size.height = cell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height + 1
        cellHeights.setObject(size.height, forKey: hash)

        return size
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let selectedCard = whiteCards[indexPath.row]
        removeCardAtIndexPath(indexPath)
        addSelectedCardToBlackCard(selectedCard)
    }

    func removeCardAtIndexPath(indexPath: NSIndexPath) {
        if gameState == .PickingWinner {
            return
        }
        whiteCardCollectionView.performBatchUpdates({
            self.whiteCardCollectionView.deleteItemsAtIndexPaths([indexPath])
            self.whiteCards.removeAtIndex(indexPath.row)
        }, nil)
    }

    func addSelectedCardToBlackCard(selectedCard: Card) {
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
            blackCardLabel.font = UIFont.boldSystemFontOfSize(35)
            blackCardLabelBottomConstraint.constant = -80
            UIView.animateWithDuration(0.33, {
                self.whiteCardCollectionView.alpha = 0
                self.scrollView.scrollEnabled = true
                self.scrollViewContentView.layoutSubviews()
                self.viewDidLayoutSubviews()
            }, completion: { _ in
                self.view.bringSubviewToFront(self.voteButton)
            })

            let attr = MPCAttributedString(attributedString: blackCardLabel.attributedText).mpcSerialized
            ConnectionManager.sendMessage(.Answer, object: ["answer": attr])
            prepareForBlackCards()
        }
    }

    func prepareForBlackCards() {
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

    func updateWaitingForPeers() {
        if unansweredPlayers.count > 0 {
            voteButton.setTitle(waitingForPeersMessage, forState: .Disabled)
        } else {
            updateVoteButton()
        }
    }

    func updateVoteButton() {
        let cardString = voteeForCurrentPage.cardString(hasVoted)
        let votesString = stringFromVoteCount(voteCountForPage(pageControl.currentPage))
        voteButton.setTitle("\(cardString) (\(votesString))", forState: .Normal)
    }

    func pickWinner() {
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

    func generateBlackCards() {
        pageControl.numberOfPages = answers.count + 1
        scrollView.contentSize = CGSizeMake(view.frame.size.width * CGFloat(pageControl.numberOfPages), 0)
        for (index, answer) in enumerate(answers) {
            // Content View
            let contentFrame = CGRectOffset(scrollViewContentView.frame, scrollViewContentView.frame.size.width * CGFloat(index + 1), 0)
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

            blackCardLabel.font = self.blackCardLabel.font
            blackCardLabel.attributedText = answer.answer

            // Layout
            layout(blackCardLabel, contentView) { blackCardLabel, contentView in
                blackCardLabel.top == contentView.top + 64
                blackCardLabel.width == contentView.width - 32
                blackCardLabel.leading == contentView.leading + 16
                blackCardLabel.bottom <= contentView.bottom - 80
            }
        }
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

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<()>) {
        if context == &blackLabelBoundsKVOContext {
            whiteCardCollectionView.contentInset = UIEdgeInsetsMake(blackCardLabel.frame.size.height + 20 + 64, 0, 20, 0)
            whiteCardCollectionView.scrollRectToVisible(CGRectMake(0, 0, 1, 1), animated: true)
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    func stringFromVoteCount(voteCount: Int) -> String {
        switch voteCount {
            case 0:
                return "no votes"
            case 1:
                return "1 vote"
            default:
                return "\(voteCount) votes"
        }
    }

    func voteCountForPage(page: Int) -> Int {
        let votee = voteeForPage(page)
        return votes.filter({ $0.votee.name == votee.name }).count
    }
}
