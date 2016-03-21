//
//  MenuViewController.swift
//  CardsAgainst
//
//  Created by JP Simard on 10/25/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import UIKit
import Cartography

final class MenuViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    // MARK: Properties

    private let startGameButton = UIButton(type: .System)
    private let separator = UIView()
    private let collectionView = UICollectionView(frame: CGRectZero,
        collectionViewLayout: UICollectionViewFlowLayout())

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        setupNavigationBar()
        setupLaunchImage()
        setupStartGameButton()
        setupSeparator()
        setupCollectionView()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        ConnectionManager.onConnect { _ in
            self.updatePlayers()
        }
        ConnectionManager.onDisconnect { _ in
            self.updatePlayers()
        }
        ConnectionManager.onEvent(.StartGame) { [unowned self] _, object in
            let dict = object as! [String: NSData]
            let blackCard = Card(mpcSerialized: dict["blackCard"]!)
            let whiteCards = CardArray(mpcSerialized: dict["whiteCards"]!).array
            self.startGame(blackCard: blackCard, whiteCards: whiteCards)
        }
    }

    override func viewWillDisappear(animated: Bool) {
        ConnectionManager.onConnect(nil)
        ConnectionManager.onDisconnect(nil)
        ConnectionManager.onEvent(.StartGame, run: nil)

        super.viewWillDisappear(animated)
    }

    // MARK: UI

    private func setupNavigationBar() {
        navigationController!.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: .Default)
        navigationController!.navigationBar.shadowImage = UIImage()
        navigationController!.navigationBar.translucent = true
    }

    private func setupLaunchImage() {
        view.addSubview(UIImageView(image: UIImage.launchImage()))

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
        blurView.frame = view.bounds
        view.addSubview(blurView)
    }

    private func setupStartGameButton() {
        // Button
        startGameButton.translatesAutoresizingMaskIntoConstraints = false
        startGameButton.titleLabel!.font = startGameButton.titleLabel!.font.fontWithSize(25)
        startGameButton.setTitle("Waiting For Players", forState: .Disabled)
        startGameButton.setTitle("Start Game", forState: .Normal)
        startGameButton.addTarget(self, action: "startGame", forControlEvents: .TouchUpInside)
        startGameButton.enabled = false
        view.addSubview(startGameButton)

        // Layout
        constrain(startGameButton) { button in
            button.top == button.superview!.top + 60
            button.centerX == button.superview!.centerX
        }
    }

    private func setupSeparator() {
        // Separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = lightColor
        view.addSubview(separator)

        // Layout
        constrain(separator, startGameButton) { separator, startGameButton in
            separator.top == startGameButton.bottom + 10
            separator.centerX == separator.superview!.centerX
            separator.width == separator.superview!.width - 40
            separator.height == 1 / UIScreen.mainScreen().scale
        }
    }

    private func setupCollectionView() {
        // Collection View
        let cvLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        cvLayout.itemSize = CGSizeMake(separator.frame.size.width, 50)
        cvLayout.minimumLineSpacing = 0
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = UIColor.clearColor()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.registerClass(PlayerCell.self,
            forCellWithReuseIdentifier: PlayerCell.reuseID)
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)

        // Layout
        constrain(collectionView, separator) { collectionView, separator in
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

    private func startGame(blackCard blackCard: Card, whiteCards: [Card]) {
        let gameVC = GameViewController(blackCard: blackCard, whiteCards: whiteCards)
        navigationController!.pushViewController(gameVC, animated: true)
    }

    // MARK: Multipeer

    private func sendBlackCard(blackCard: Card) {
        ConnectionManager.sendEventForEach(.StartGame) {
            let whiteCards = CardManager.nextCardsWithType(.White, count: 10)
            let whiteCardsArray = CardArray(array: whiteCards)
            return ["blackCard": blackCard, "whiteCards": whiteCardsArray]
        }
    }

    private func updatePlayers() {
        startGameButton.enabled = (ConnectionManager.otherPlayers.count > 0)
        collectionView.reloadData()
    }

    // MARK: UICollectionViewDataSource

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ConnectionManager.otherPlayers.count
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PlayerCell.reuseID, forIndexPath: indexPath) as! PlayerCell
        cell.label.text = ConnectionManager.otherPlayers[indexPath.row].name
        return cell
    }
}
