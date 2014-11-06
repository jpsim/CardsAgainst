//
//  MenuViewController.swift
//  CardsAgainst
//
//  Created by JP Simard on 10/25/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import Cartography

private func launchImage() -> UIImage {
    // We only care about iOS 8+ portrait iPhones
    // LaunchImage names found here: http://stackoverflow.com/a/25843887/373262
    var launchImageName: String
    switch UIScreen.mainScreen().bounds.size.height {
        case 0..<568:
            // 3.5 inch screen
            launchImageName = "LaunchImage-700"
        case 568:
            // 4 inch screen
            launchImageName = "LaunchImage-700-568h"
        case 667:
            // 4.7 inch screen
            launchImageName = "LaunchImage-800-667h"
        case 736:
            // 5.5 inch screen
            launchImageName = "LaunchImage-800-Portrait-736h"
        default:
            // Let the system decide
            launchImageName = "LaunchImage"
    }
    return UIImage(named: launchImageName)!
}

final class MenuViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    // MARK: Properties

    private var startGameButton = UIButton.buttonWithType(.System) as UIButton
    private var separator = UIView()
    private var collectionView = UICollectionView(frame: CGRectZero,
        collectionViewLayout: UICollectionViewFlowLayout())
    private var players: [Player] { return ConnectionManager.peers }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupLaunchImage()
        setupStartGameButton()
        setupSeparator()
        setupCollectionView()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        Client.sharedInstance.onConnect = { _ in
            self.updatePlayers()
        }
        Client.sharedInstance.onDisconnect = { _ in
            self.updatePlayers()
        }
        Client.sharedInstance.eventBlocks[MessageType.StartGame.rawValue] = { _, object in
            let dict = object as [String: NSData]
            let blackCard = Card(mpcSerialized: dict["blackCard"]!)
            let whiteCards = CardArray(mpcSerialized: dict["whiteCards"]!).array
            self.startGame(blackCard: blackCard, whiteCards: whiteCards)
        }
    }

    override func viewWillDisappear(animated: Bool) {
        Client.sharedInstance.onConnect = nil
        Client.sharedInstance.onDisconnect = nil
        Client.sharedInstance.eventBlocks.removeValueForKey(MessageType.StartGame.rawValue)

        super.viewWillDisappear(animated)
    }

    // MARK: UI

    func setupNavigationBar() {
        navigationController!.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: .Default)
        navigationController!.navigationBar.shadowImage = UIImage()
        navigationController!.navigationBar.translucent = true
    }

    func setupLaunchImage() {
        view.addSubview(UIImageView(image: launchImage()))

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
        blurView.frame = view.bounds
        view.addSubview(blurView)
    }

    func setupStartGameButton() {
        // Button
        startGameButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        startGameButton.titleLabel!.font = startGameButton.titleLabel!.font.fontWithSize(25)
        startGameButton.setTitle("Waiting For Players", forState: .Disabled)
        startGameButton.setTitle("Start Game", forState: .Normal)
        startGameButton.addTarget(self, action: "startGame", forControlEvents: .TouchUpInside)
        startGameButton.enabled = false
        view.addSubview(startGameButton)

        // Layout
        layout(startGameButton) { button in
            button.top == button.superview!.top + 60
            button.centerX == button.superview!.centerX
        }
    }

    func setupSeparator() {
        // Separator
        separator.setTranslatesAutoresizingMaskIntoConstraints(false)
        separator.backgroundColor = lightColor
        view.addSubview(separator)

        // Layout
        layout(separator, startGameButton) { separator, startGameButton in
            separator.top == startGameButton.bottom + 10
            separator.centerX == separator.superview!.centerX
            separator.width == separator.superview!.width - 40
            separator.height == (1 / Float(UIScreen.mainScreen().scale))
        }
    }

    func setupCollectionView() {
        // Collection View
        let cvLayout = collectionView.collectionViewLayout as UICollectionViewFlowLayout
        cvLayout.itemSize = CGSizeMake(separator.frame.size.width, 40)
        cvLayout.minimumLineSpacing = 0
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = UIColor.clearColor()
        collectionView.setTranslatesAutoresizingMaskIntoConstraints(false)
        collectionView.registerClass(PlayerCell.self,
            forCellWithReuseIdentifier: PlayerCell.reuseID)
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)

        // Layout
        layout(collectionView, separator) { collectionView, separator in
            collectionView.top == separator.bottom
            collectionView.left == separator.left
            collectionView.right == separator.right
            collectionView.bottom == collectionView.superview!.bottom
        }
    }

    // MARK: Actions

    func startGame() {
        let blackCard = CardManager.nextCardsWithType(.Black).first!
        let whiteCards = CardManager.nextCardsWithType(.White, count: 10)
        sendBlackCard(blackCard)
        startGame(blackCard: blackCard, whiteCards: whiteCards)
    }

    func sendBlackCard(blackCard: Card) {
        for peer in Client.sharedInstance.session!.connectedPeers as [MCPeerID] {
            let whiteCards = CardManager.nextCardsWithType(.White, count: 10)
            let whiteCardsArray = CardArray(array: whiteCards)
            let object = [
                "blackCard": blackCard.mpcSerialized,
                "whiteCards": whiteCardsArray.mpcSerialized
            ]
            ConnectionManager.sendMessage(.StartGame, object: object, toPeers: [peer])
        }
    }

    func startGame(notification: NSNotification) {
        startGame(blackCard: fromNotification(notification),
            whiteCards: fromNotification(notification).array)
    }

    func startGame(#blackCard: Card, whiteCards: [Card]) {
        let gameVC = GameViewController(blackCard: blackCard, whiteCards: whiteCards)
        navigationController!.pushViewController(gameVC, animated: true)
    }

    // MARK: Multipeer

    func updatePlayers() {
        startGameButton.enabled = (players.count > 0)
        collectionView.reloadData()
    }

    // MARK: UICollectionViewDataSource

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ConnectionManager.peers.count
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PlayerCell.reuseID, forIndexPath: indexPath) as PlayerCell
        cell.label.text = ConnectionManager.peers[indexPath.row].name
        return cell
    }
}
