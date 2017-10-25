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

    fileprivate let startGameButton = UIButton(type: .system)
    fileprivate let separator = UIView()
    fileprivate let collectionView = UICollectionView(frame: .zero,
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        ConnectionManager.onConnect { _, _ in
            self.updatePlayers()
        }
        ConnectionManager.onDisconnect { _, _ in
            self.updatePlayers()
        }
        ConnectionManager.onEvent(.StartGame) { [unowned self] _, object in
            let dict = object as! [String: NSData]
            let blackCard = Card(mpcSerialized: dict["blackCard"]! as Data)
            let whiteCards = CardArray(mpcSerialized: dict["whiteCards"]! as Data).array
            self.startGame(blackCard: blackCard, whiteCards: whiteCards)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        ConnectionManager.onConnect(nil)
        ConnectionManager.onDisconnect(nil)
        ConnectionManager.onEvent(.StartGame, run: nil)

        super.viewWillDisappear(animated)
    }

    // MARK: UI

    fileprivate func setupNavigationBar() {
        navigationController!.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController!.navigationBar.shadowImage = UIImage()
        navigationController!.navigationBar.isTranslucent = true
    }

    fileprivate func setupLaunchImage() {
        view.addSubview(UIImageView(image: .launchImage()))

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.frame = view.bounds
        view.addSubview(blurView)
    }

    fileprivate func setupStartGameButton() {
        // Button
        startGameButton.translatesAutoresizingMaskIntoConstraints = false
        startGameButton.titleLabel!.font = startGameButton.titleLabel!.font.withSize(25)
        startGameButton.setTitle("Waiting For Players", for: .disabled)
        startGameButton.setTitle("Start Game", for: UIControlState())
        startGameButton.addTarget(
            self, action: #selector(MenuViewController.startGame as (MenuViewController) -> () -> ()),
            for: .touchUpInside
        )
        startGameButton.isEnabled = false
        view.addSubview(startGameButton)

        // Layout
        constrain(startGameButton) { button in
            button.top == button.superview!.top + 60
            button.centerX == button.superview!.centerX
        }
    }

    fileprivate func setupSeparator() {
        // Separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = lightColor
        view.addSubview(separator)

        // Layout
        constrain(separator, startGameButton) { separator, startGameButton in
            separator.top == startGameButton.bottom + 10
            separator.centerX == separator.superview!.centerX
            separator.width == separator.superview!.width - 40
            separator.height == 1 / UIScreen.main.scale
        }
    }

    fileprivate func setupCollectionView() {
        // Collection View
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(PlayerCell.self, forCellWithReuseIdentifier: PlayerCell.reuseID)
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

    @objc func startGame() {
        let blackCard = CardManager.nextCardsWithType(.Black).first!
        let whiteCards = CardManager.nextCardsWithType(.White, count: 10)
        sendBlackCard(blackCard)
        startGame(blackCard: blackCard, whiteCards: whiteCards)
    }

    fileprivate func startGame(blackCard: Card, whiteCards: [Card]) {
        let gameVC = GameViewController(blackCard: blackCard, whiteCards: whiteCards)
        navigationController!.pushViewController(gameVC, animated: true)
    }

    // MARK: Multipeer

    fileprivate func sendBlackCard(_ blackCard: Card) {
        ConnectionManager.sendEventForEach(.StartGame) {
            let whiteCards = CardManager.nextCardsWithType(.White, count: 10)
            let whiteCardsArray = CardArray(array: whiteCards)
            return ["blackCard": blackCard, "whiteCards": whiteCardsArray]
        }
    }

    fileprivate func updatePlayers() {
        startGameButton.isEnabled = (ConnectionManager.otherPlayers.count > 0)
        collectionView.reloadData()
    }

    // MARK: UICollectionViewDataSource

    @objc func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ConnectionManager.otherPlayers.count
    }

    @objc func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PlayerCell.reuseID, for: indexPath) as! PlayerCell
        cell.label.text = ConnectionManager.otherPlayers[indexPath.row].name
        return cell
    }

    @objc func collectionView(_ collectionView: UICollectionView,
                              layout collectionViewLayout: UICollectionViewLayout,
                              sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.size.width - 32, height: 50)
    }
}
