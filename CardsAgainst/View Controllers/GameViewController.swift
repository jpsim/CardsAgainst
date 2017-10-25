//
//  GameViewController.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/2/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit
import Cartography

final class GameViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    // MARK: Properties

    // Data
    fileprivate var gameState = GameState.pickingCard
    fileprivate var blackCard: Card
    fileprivate var whiteCards: [Card]
    fileprivate var answers = [Answer]()
    fileprivate var votes = [Vote]()
    fileprivate var numberOfCardsPlayed = 0
    fileprivate var scores = [Player: Int]()
    fileprivate var hasVoted: Bool = false {
        didSet {
            voteButton.tintColor = hasVoted ? lightColor : appTintColor
            voteButton.isUserInteractionEnabled = !hasVoted
            scrollViewDidEndDecelerating(scrollView)
        }
    }

    // UI
    fileprivate let blackCardLabel = TouchableLabel()
    fileprivate let whiteCardCollectionView = UICollectionView(frame: .zero,
                                                               collectionViewLayout: WhiteCardFlowLayout())
    fileprivate let pageControl = UIPageControl()
    fileprivate let scrollView = UIScrollView()
    fileprivate let scrollViewContentView = UIView()
    fileprivate let voteButton = UIButton(type: .system)

    // UI Helper
    fileprivate var blackCardLabelBottomConstraint = NSLayoutConstraint()
    fileprivate var otherBlackCardViews = [UIView]()
    fileprivate let cellHeights = NSCache<AnyObject, AnyObject>()
    private var kvoObserver: NSKeyValueObservation?

    // Computed Properties
    fileprivate var voteeForCurrentPage: Player {
        return voteeForPage(pageControl.currentPage)
    }
    fileprivate var hasEveryPeerAnswered: Bool {
        return answers.count == ConnectionManager.otherPlayers.count
    }
    fileprivate var hasEveryPeerVoted: Bool {
        return votes.count == ConnectionManager.allPlayers.count
    }
    fileprivate var winner: Player? {
        if votes.count < 2 {
            return nil
        }
        var votesForPlayers = [Player: Int]()
        for votee in votes.map({ $0.votee }) {
            if let freq = votesForPlayers[votee] {
                votesForPlayers[votee] = freq + 1
            } else {
                votesForPlayers[votee] = 1
            }
        }
        if votesForPlayers.count == 1 {
            return votesForPlayers.keys.first!
        }
        let sortedVotes = votesForPlayers.values.sorted { $0 > $1 }
        let maxVotes = sortedVotes[0]
        if maxVotes == sortedVotes[1] {
            return nil // Tie
        }
        return votesForPlayers.keys.filter({votesForPlayers[$0] == maxVotes}).first!
    }
    fileprivate var stats: String {
        return scores.keys.map({ "\($0.displayName): \(scores[$0] ?? 0)" }).joined(separator: "\n")
    }
    fileprivate var unansweredPlayers: [Player] {
        let answeredPlayers = answers.map { $0.sender }
        return ConnectionManager.otherPlayers.filter { !answeredPlayers.contains($0) }
    }
    fileprivate var waitingForPeersMessage: String {
        return "Waiting for " + unansweredPlayers.map({ $0.name }).joined(separator: ", ")
    }

    // MARK: View Lifecycle

    init(blackCard: Card, whiteCards: [Card]) {
        self.blackCard = blackCard
        self.whiteCards = whiteCards

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController!.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController!.navigationBar.shadowImage = UIImage()
        cellHeights.countLimit = 20
        view.backgroundColor = appBackgroundColor

        updateTitle()

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Stats", style: .plain, target: self,
                                                            action: #selector(showStats))

        // UI
        setupVoteButton()
        setupPageControl()
        setupScrollView()
        setupWhiteCardCollectionView()
        setupBlackCard()

        // Other setup
        blackCardLabel.text = blackCard.content
        blackCardLabel.font = .blackCardFont
        whiteCardCollectionView.reloadData()

        for player in ConnectionManager.allPlayers {
            scores[player] = 0
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // KVO
        kvoObserver = blackCardLabel.observe(\.bounds, options: .new) { label, _ in
            self.whiteCardCollectionView.contentInset = UIEdgeInsets(top: label.frame.size.height + 20 + 64,
                                                                     left: 0, bottom: 20, right: 0)
            self.whiteCardCollectionView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1),
                                                             animated: true)
        }

        setupMultipeerEventHandlers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        kvoObserver?.invalidate()
        let observedEvents: [Event] = [.answer, .cancelAnswer, .vote, .nextCard, .endGame]
        for event in observedEvents {
            ConnectionManager.onEvent(event, run: nil)
        }

        super.viewWillDisappear(animated)
    }

    // MARK: UI Setup

    fileprivate func setupVoteButton() {
        // Button
        voteButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(voteButton)
        voteButton.isEnabled = false
        voteButton.titleLabel?.numberOfLines = 0
        voteButton.titleLabel?.textAlignment = .center
        voteButton.titleLabel?.font = UIFont.voteButtonFont
        voteButton.addTarget(self, action: #selector(vote), for: .touchUpInside)

        // Layout
        constrain(voteButton) { voteButton in
            voteButton.bottom == voteButton.superview!.bottom - 16
            voteButton.centerX == voteButton.superview!.centerX
            voteButton.width == voteButton.superview!.width - 32
        }
    }

    fileprivate func setupPageControl() {
        // Page Control
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)
        pageControl.numberOfPages = ConnectionManager.otherPlayers.count + 1

        // Layout
        constrain(pageControl, voteButton) { pageControl, voteButton in
            pageControl.bottom == voteButton.top
            pageControl.centerX == pageControl.superview!.centerX
        }
    }

    fileprivate func setupScrollView() {
        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.delegate = self
        scrollView.isScrollEnabled = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false

        // Layout
        constrain(scrollView) { scrollView in
            scrollView.edges == scrollView.superview!.edges
        }

        // Scroll View Content View
        scrollViewContentView.frame = view.bounds
        scrollView.addSubview(scrollViewContentView)
    }

    fileprivate func setupBlackCard() {
        // Label
        blackCardLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollViewContentView.addSubview(blackCardLabel)
        blackCardLabel.contentMode = .top
        blackCardLabel.textColor = lightColor
        blackCardLabel.numberOfLines = 0
        blackCardLabel.minimumScaleFactor = 0.5
        blackCardLabel.adjustsFontSizeToFitWidth = true

        // Layout
        constrain(blackCardLabel, scrollViewContentView) { blackCardLabel, scrollViewContentView in
            blackCardLabel.top == scrollViewContentView.top + 64
            blackCardLabel.width == scrollViewContentView.width - 32
            blackCardLabel.leading == scrollViewContentView.leading + 16
            blackCardLabelBottomConstraint = (blackCardLabel.bottom <= scrollViewContentView.bottom - 200)
        }

        // Gesture
        blackCardLabel.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                   action: #selector(removeLastWhiteCard)))
    }

    fileprivate func setupWhiteCardCollectionView() {
        // Collection View
        whiteCardCollectionView.translatesAutoresizingMaskIntoConstraints = false
        scrollViewContentView.addSubview(whiteCardCollectionView)
        whiteCardCollectionView.register(WhiteCardCell.self,
            forCellWithReuseIdentifier: WhiteCardCell.reuseID)
        whiteCardCollectionView.showsVerticalScrollIndicator = false
        whiteCardCollectionView.alwaysBounceVertical = true
        whiteCardCollectionView.dataSource = self
        whiteCardCollectionView.delegate = self
        whiteCardCollectionView.backgroundColor = appBackgroundColor

        // Layout
        constrain(whiteCardCollectionView) { whiteCardCollectionView in
            whiteCardCollectionView.edges == whiteCardCollectionView.superview!.edges
        }
    }

    // MARK: UI Derived

    override func didMove(toParentViewController parent: UIViewController?) {
        // User initiated pop
        if parent == nil {
            ConnectionManager.sendEvent(.endGame)
        }
    }

    fileprivate func updateTitle() {
        numberOfCardsPlayed += 1
        title = "Card \(numberOfCardsPlayed)"
    }

    fileprivate func prepareForBlackCards() {
        scrollView.contentSize = CGSize(width: view.frame.size.width, height: 0)
        voteButton.isEnabled = false
        pageControl.alpha = 0

        for view in otherBlackCardViews {
            view.removeFromSuperview()
        }
        otherBlackCardViews.removeAll(keepingCapacity: true)

        if hasEveryPeerAnswered {
            pickWinner()
        } else {
            updateWaitingForPeers()
        }
    }

    fileprivate func updateWaitingForPeers() {
        if unansweredPlayers.count > 0 {
            voteButton.setTitle(waitingForPeersMessage, for: .disabled)
        } else {
            updateVoteButton()
        }
    }

    fileprivate func updateVoteButton() {
        let cardString = voteeForCurrentPage.cardString(hasVoted)
        let votesString = Vote.stringFromVoteCount(voteCountForPage(pageControl.currentPage))
        voteButton.setTitle("\(cardString) (\(votesString))", for: UIControlState())
    }

    fileprivate func generateBlackCards() {
        pageControl.numberOfPages = answers.count + 1
        scrollView.contentSize = CGSize(width: view.frame.size.width * CGFloat(pageControl.numberOfPages), height: 0)
        for (index, answer) in answers.enumerated() {
            // Content View
            let contentFrame = scrollViewContentView.frame.offsetBy(
                dx: scrollViewContentView.frame.size.width * CGFloat(index + 1),
                dy: 0
            )
            let contentView = UIView(frame: contentFrame)
            scrollView.addSubview(contentView)
            otherBlackCardViews.append(contentView)

            // Black Card Label
            let blackCardLabel = TouchableLabel()
            blackCardLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(blackCardLabel)
            blackCardLabel.contentMode = .top
            blackCardLabel.textColor = lightColor
            blackCardLabel.numberOfLines = 0
            blackCardLabel.minimumScaleFactor = 0.5
            blackCardLabel.adjustsFontSizeToFitWidth = true

            blackCardLabel.attributedText = answer.answer
            // override remote font size with our own screen-specific size
            blackCardLabel.font = self.blackCardLabel.font

            // Layout
            constrain(blackCardLabel, contentView) { blackCardLabel, contentView in
                blackCardLabel.top == contentView.top + 64
                blackCardLabel.width == contentView.width - 32
                blackCardLabel.leading == contentView.leading + 16
                blackCardLabel.bottom <= contentView.bottom - 80
            }
        }
    }

    // MARK: Multipeer

    fileprivate func setupMultipeerEventHandlers() {
        // Answer
        ConnectionManager.onEvent(.answer) { [unowned self] peer, object in
            let dict = object as! [String: NSData]
            let attr = MPCAttributedString(mpcSerialized: dict["answer"]! as Data).attributedString
            self.answers.append(Answer(sender: Player(peer: peer), answer: attr))
            self.updateWaitingForPeers()
            if self.gameState != .pickingCard && self.hasEveryPeerAnswered {
                self.pickWinner()
            }
        }

        // Cancel Answer
        ConnectionManager.onEvent(.cancelAnswer) { [unowned self] peer, _ in
            let sender = Player(peer: peer)
            self.answers = self.answers.filter { $0.sender != sender }
            self.updateWaitingForPeers()
        }

        // Vote
        ConnectionManager.onEvent(.vote) { [unowned self] peer, object in
            let voter = Player(peer: peer)
            let votee = Player(mpcSerialized: (object as! [String: NSData])["votee"]! as Data)
            self.addVote(voter, to: votee)
        }

        // Next Card
        ConnectionManager.onEvent(.nextCard) { [unowned self] _, object in
            let dict = object as! [String: NSData]
            let winner = Player(mpcSerialized: dict["winner"]! as Data)
            let blackCard = Card(mpcSerialized: dict["blackCard"]! as Data)
            let whiteCards = CardArray(mpcSerialized: dict["whiteCards"]! as Data).array
            self.scores[winner]! += 1
            self.nextBlackCard(blackCard, newWhiteCards: whiteCards, winner: winner)
        }

        // End Game
        ConnectionManager.onEvent(.endGame) { [unowned self] _, _ in
            self.dismiss()
        }
    }

    // MARK: Actions

    fileprivate func dismiss() {
        navigationController?.popViewController(animated: true)
    }

    fileprivate func nextCardWithWinner(_ winner: Player) {
        let blackCard = CardManager.nextCardsWithType(.black).first!
        scores[winner]! += 1
        ConnectionManager.sendEventForEach(.nextCard) {
            let nextWhiteCards = CardManager.nextCardsWithType(.white, count: UInt(10 - self.whiteCards.count))
            let payload: [String: MPCSerializable] = [
                "blackCard": blackCard,
                "whiteCards": CardArray(array: nextWhiteCards),
                "winner": winner
            ]
            return payload
        }
        let newWhiteCards = CardManager.nextCardsWithType(.white, count: UInt(10 - whiteCards.count))
        nextBlackCard(blackCard, newWhiteCards: newWhiteCards, winner: winner)
    }

    fileprivate func nextBlackCard(_ blackCard: Card, newWhiteCards: [Card], winner: Player) {
        showWinner(winner)
        answers = [Answer]()
        pageControl.currentPage = 0
        blackCardLabel.isUserInteractionEnabled = true
        gameState = .pickingCard
        blackCardLabel.placeholderRanges = [NSRange]()
        scrollView.contentOffset = CGPoint.zero
        blackCardLabelBottomConstraint.constant = -200
        scrollView.isScrollEnabled = false
        view.sendSubview(toBack: voteButton)
        view.sendSubview(toBack: pageControl)

        blackCardLabel.text = blackCard.content
        blackCardLabel.font = UIFont.blackCardFont
        whiteCards += newWhiteCards
        whiteCardCollectionView.reloadData()
        whiteCardCollectionView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
        UIView.animate(withDuration: 0.33, animations: {
            self.whiteCardCollectionView.alpha = 1
            self.scrollView.isScrollEnabled = false
            self.scrollViewContentView.layoutSubviews()
            self.viewDidLayoutSubviews()
        })
        for view in otherBlackCardViews {
            view.removeFromSuperview()
        }
        otherBlackCardViews.removeAll(keepingCapacity: true)
        votes = [Vote]()
        hasVoted = false
        updateTitle()
    }

    // MARK: HUD

    fileprivate func showWinner(_ winner: Player) {
        showHUD("\(winner.winningString())\n\n\(stats)", duration: 2)
    }

    @objc func showStats() {
        showHUD(stats)
    }

    fileprivate func showHUD(_ status: String, duration: Double = 1) {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.show(withStatus: status)
        let delay = DispatchTime.now() + Double(Int64(duration * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delay) {
            SVProgressHUD.dismiss()
        }
    }

    // MARK: Voting

    @objc func vote() {
        if hasVoted {
            return
        }
        let votee = voteeForCurrentPage
        addVote(.getMe(), to: votee)
        hasVoted = true
        ConnectionManager.sendEvent(.vote, object: ["votee": votee])

        if hasEveryPeerVoted {
            if let winner = winner {
                nextCardWithWinner(winner)
            } else {
                handleTie()
            }
        }
    }

    fileprivate func addVote(_ from: Player, to: Player) {
        votes.append(Vote(votee: to, voter: from))
        if gameState != .pickingCard {
            scrollViewDidEndDecelerating(scrollView)
        }
    }

    fileprivate func handleTie() {
        let alert = UIAlertController(title: "Tie Breaker!",
            message: "There was a tie! You picked last, so you decide who wins",
            preferredStyle: .alert)
        for player in ConnectionManager.allPlayers {
            alert.addAction(UIAlertAction(title: player.name,
                style: .default) { _ in
                    self.nextCardWithWinner(player)
                })
        }
        present(alert, animated: true) {}
    }

    fileprivate func pickWinner() {
        if gameState != .waitingForOthers {
            return
        }
        gameState = .pickingWinner
        scrollViewDidEndDecelerating(scrollView)
        voteButton.isEnabled = true
        scrollView.contentOffset = .zero
        generateBlackCards()
        blackCardLabel.isUserInteractionEnabled = false
        UIView.animate(withDuration: 2) {
            self.pageControl.alpha = 1
        }
    }

    // MARK: Adding/Removing Cards

    fileprivate func addSelectedCardToBlackCard(_ selectedCard: Card) {
        if let range = blackCardLabel.text?.range(of: blackCardPlaceholder) {
            blackCardLabel.text = blackCardLabel.text?.replacingCharacters(in: range, with: selectedCard.content)
            let start = blackCardLabel.text!.characters.distance(from: blackCardLabel.text!.startIndex,
                                                                 to: range.lowerBound)
            let length = selectedCard.content.characters.count
            blackCardLabel.placeholderRanges.append(NSRange(location: start, length: length))
        } else {
            let range = NSRange(location: blackCardLabel.text!.characters.count + 1,
                                length: selectedCard.content.characters.count)
            blackCardLabel.placeholderRanges.append(range)
            blackCardLabel.text! += "\n\(selectedCard.content)"
        }
        let blackCardStyled = NSMutableAttributedString(string: blackCardLabel.text!)
        for range in blackCardLabel.placeholderRanges {
            blackCardStyled.addAttribute(.foregroundColor, value: appTintColor, range: range)
        }
        blackCardLabel.attributedText = blackCardStyled
        if blackCardLabel.text?.range(of: blackCardPlaceholder) == nil {
            gameState = .waitingForOthers
            blackCardLabel.font = UIFont.blackCardFont
            blackCardLabelBottomConstraint.constant = -80
            UIView.animate(withDuration: 0.33, animations: {
                self.whiteCardCollectionView.alpha = 0
                self.scrollView.isScrollEnabled = true
                self.scrollViewContentView.layoutSubviews()
                self.viewDidLayoutSubviews()
            }, completion: { _ in
                self.view.bringSubview(toFront: self.voteButton)
            })

            let attr = MPCAttributedString(attributedString: blackCardLabel.attributedText!)
            ConnectionManager.sendEvent(.answer, object: ["answer": attr])
            prepareForBlackCards()
        }
    }

    @objc func removeLastWhiteCard() {
        if let lastRange = blackCardLabel.placeholderRanges.last {
            let blackCardLabelNSString = blackCardLabel.text! as NSString
            whiteCardCollectionView.performBatchUpdates({
                let content = blackCardLabelNSString.substring(with: lastRange)
                let lastWhiteCard = Card(content: content, type: .white, expansion: "")
                self.whiteCards.append(lastWhiteCard)
                let indexPath = IndexPath(item: self.whiteCards.count - 1, section: 0)
                self.whiteCardCollectionView.insertItems(at: [indexPath])
            }, completion: nil)
            blackCardLabel.text = blackCardLabelNSString.replacingCharacters(in: lastRange, with: blackCardPlaceholder)
            let placeholderlessLength = blackCardPlaceholder.characters.count + 1

            let blackCardLabelSubstring = blackCardLabelNSString
                .substring(from: blackCardLabelNSString.length - placeholderlessLength)
            if blackCardLabelSubstring == "\n\(blackCardPlaceholder)" {
                blackCardLabel.text = blackCardLabelNSString
                    .substring(to: blackCardLabelNSString.length - placeholderlessLength)
            }
            blackCardLabel.placeholderRanges.removeLast()
            let blackCardStyled = NSMutableAttributedString(string: blackCardLabel.text!)
            for range in blackCardLabel.placeholderRanges {
                blackCardStyled.addAttribute(.foregroundColor, value: appTintColor, range: range)
            }
            blackCardLabel.attributedText = blackCardStyled
            gameState = .pickingCard
            blackCardLabel.font = UIFont.blackCardFont
            view.sendSubview(toBack: voteButton)
            view.sendSubview(toBack: pageControl)
            blackCardLabelBottomConstraint.constant = -200
            UIView.animate(withDuration: 0.33) {
                self.whiteCardCollectionView.alpha = 1
                self.scrollView.isScrollEnabled = false
                self.scrollViewContentView.layoutSubviews()
                self.viewDidLayoutSubviews()
            }
            ConnectionManager.sendEvent(.cancelAnswer)
        }
    }

    fileprivate func removeCardAtIndexPath(_ indexPath: IndexPath) {
        if gameState == .pickingWinner {
            return
        }
        whiteCardCollectionView.performBatchUpdates({
            self.whiteCardCollectionView.deleteItems(at: [indexPath])
            self.whiteCards.remove(at: indexPath.row)
        }, completion: nil)
    }

    // MARK: Logic

    fileprivate func voteCountForPage(_ page: Int) -> Int {
        let votee = voteeForPage(page)
        return votes.filter({ $0.votee.name == votee.name }).count
    }

    fileprivate func voteeForPage(_ page: Int) -> Player {
        if page > 0 {
            return answers[page - 1].sender
        }
        return .getMe()
    }

    // MARK: UICollectionViewDataSource

    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return whiteCards.count
    }

    @objc func collectionView(_ collectionView: UICollectionView,
                              cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WhiteCardCell.reuseID,
                                                      for: indexPath) as! WhiteCardCell
        cell.label.text = whiteCards[indexPath.row].content
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        return cell
    }

    @objc func collectionView(_ collectionView: UICollectionView,
                              layout collectionViewLayout: UICollectionViewLayout,
                              sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        let hash = whiteCards[indexPath.row].content.hash
        var size = CGSize(width: collectionView.frame.size.width - 32, height: 50)
        if let heightNumber = cellHeights.object(forKey: hash as AnyObject) as? NSNumber {
            size.height = CGFloat(heightNumber.floatValue)
            return size
        }
        let cell = WhiteCardCell(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        cell.label.text = whiteCards[indexPath.row].content
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        let cellSize = cell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        size.height = cellSize.height + 1
        cellHeights.setObject(size.height as AnyObject, forKey: hash as AnyObject)

        return size
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        addSelectedCardToBlackCard(whiteCards[indexPath.row])
        removeCardAtIndexPath(indexPath)
    }

    // MARK: Paging

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == self.scrollView {
            let page = round(scrollView.contentOffset.x / scrollView.frame.size.width)
            pageControl.currentPage = Int(page)
            updateVoteButton()
        }
    }
}
