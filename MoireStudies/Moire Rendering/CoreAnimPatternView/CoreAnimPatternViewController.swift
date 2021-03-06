//
//  CoreAnimPatternViewController.swift
//  MoireStudies
//
//  Created by Jialiang Xiang on 2021-02-08.
//

import Foundation
import UIKit

class CoreAnimPatternViewController: UIViewController {
    private var pattern: Pattern = Pattern.defaultPattern()
    private var SpeedFactor: CGFloat = 0.2 // to compensate for the speed increase caused by scaling
    private var tileHeight: CGFloat = Constants.UI.tileHeight
    private var tileLength: CGFloat?
    private var numOfTile: Int = 0
    private var tileContainers: Array<WeakTileLayerContainer> = Array()
    private weak var lastTile: TileLayer? // keep track of the tile at the end to ensure the next recycled tile fit seamlessly
    private weak var backingView: UIView? // the subview that holds all the tiles. It can be scaled
    private var backingViewDefaultTransf: CGAffineTransform = CGAffineTransform()
    
    override func viewDidLoad() {
        self.view.accessibilityIdentifier = "CoreAnimPatternView"
        self.view.backgroundColor = UIColor.clear
    }
    
    private func createTiles() {
        let fr = Utilities.convertToFillRatioAndScaleFactor(blackWidth: pattern.blackWidth, whiteWidth: pattern.whiteWidth).fillRatio
        // the tiles are placed to fill the backing view
        tileLength = backingView!.bounds.width
        numOfTile = Int(ceil(backingView!.bounds.height / tileHeight)) + 1

        for i in 0..<numOfTile {
            let xPos : CGFloat = backingView!.bounds.width / 2.0
            let yPos : CGFloat = CGFloat(i) * tileHeight
            let newTile = TileLayer()
            newTile.contentsScale = UIScreen.main.scale
            newTile.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            newTile.frame = CGRect(x: 0, y: 0, width: tileLength!, height: tileHeight)
            newTile.position = CGPoint(x: xPos, y: yPos)
            newTile.setUp(fillRatio: fr)
            backingView!.layer.addSublayer(newTile)
            tileContainers.append(WeakTileLayerContainer.init(tileLayer: newTile))
            if i == 0 {
                lastTile = newTile
            }
        }
    }
    
    private func animateTile(tile: TileLayer) {
        // all tiles move towards the top of the backing view at the same speed
        let remainingDistance: CGFloat = tile.position.y
        let duration = remainingDistance / (self.pattern.speed * self.SpeedFactor)
        let moveDownAnim = CABasicAnimation(keyPath: "position")
        moveDownAnim.fromValue = CGPoint(x: tile.position.x, y: tile.position.y)
        moveDownAnim.toValue = CGPoint(x: tile.position.x, y: 0)
        moveDownAnim.duration = CFTimeInterval(duration)
        moveDownAnim.delegate = self;
        moveDownAnim.fillMode = CAMediaTimingFillMode.forwards
        moveDownAnim.isRemovedOnCompletion = false
        moveDownAnim.setValue(tile, forKey: "tileLayer")
        tile.add(moveDownAnim, forKey: "move down")
    }
    
    private func animateTiles() {
        for wtc in tileContainers {
            self.animateTile(tile: wtc.tileLayer!)
        }
    }
    /**
     Summary: Set model layers to presentation layers, interrupt animations and redo animations
     */
    private func reAnimateTiles() {
        for wtc in tileContainers {
            if let pl = wtc.tileLayer!.presentation() {
                wtc.tileLayer!.position = pl.position
            }
        }
        for wtc in tileContainers {
            wtc.tileLayer!.removeAnimation(forKey: "move down")
        }
        self.animateTiles()
    }
    
    func pauseAnimations() {
        // official Apple code
        let layer = self.view.layer
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0.0 // sets the layer's time 0
        layer.timeOffset = pausedTime // add pausedTime to the layer's time, and now layer's time is pausedTime
    }

    func resumeAnimations() {
        // official Apple code
        let layer = self.view.layer
        let pausedTime = layer.timeOffset
        layer.speed = 1.0 // add current time to the layer's time
        layer.timeOffset = 0.0 // minus pausedTime from the layer's time, and now layer's time is the current time
        layer.beginTime = 0.0 // assign this for now so that convertTime work correctly
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        layer.beginTime = timeSincePause // minus timeSincePause from the layer's time, and now layer's time is pausedTime
    }
}

extension CoreAnimPatternViewController: PatternViewController {
    func setUpAndRender(pattern: Pattern) {
        let diagonalLength = Double(sqrt(pow(Float(self.view.bounds.width), 2) + pow(Float(self.view.bounds.height), 2)))
        let bv = UIView()
        bv.frame = CGRect(x: 0, y: 0, width: diagonalLength, height: diagonalLength)
//        bv.frame = CGRect(x: 0, y: 0, width: self.view.bounds.height, height: self.view.bounds.height) //uncomment to show the whole backing view for debuging
        bv.center = self.view.center
        self.view.addSubview(bv)
        backingViewDefaultTransf = bv.transform
        self.backingView = bv
        
        self.createTiles()
        self.animateTiles()
        self.updatePattern(newPattern: pattern)
    }
    
    func updatePattern(newPattern: Pattern) {
        let oldPattern = self.pattern
        self.pattern = newPattern
        if oldPattern.speed != newPattern.speed {
            self.reAnimateTiles()
        }
        let oldR = Utilities.convertToFillRatioAndScaleFactor(blackWidth: oldPattern.blackWidth,
                                                              whiteWidth: oldPattern.whiteWidth)
        let newR = Utilities.convertToFillRatioAndScaleFactor(blackWidth: newPattern.blackWidth,
                                                              whiteWidth: newPattern.whiteWidth)
        if oldPattern.direction != newPattern.direction || oldR.scaleFactor != newR.scaleFactor {
            backingView!.transform =
                backingViewDefaultTransf.rotated(by: newPattern.direction).scaledBy(x: newR.scaleFactor, y: newR.scaleFactor)
        }
        if oldR.fillRatio != newR.fillRatio {
            for wtc in tileContainers {
                wtc.tileLayer!.fillRatio = newR.fillRatio
            }
        }
    }
    
    func viewControllerLosingFocus() {
        self.pauseAnimations()
    }
    
    func takeScreenShot() -> UIImage? {
        UIGraphicsBeginImageContext(self.view.frame.size)
        guard let currentContext = UIGraphicsGetCurrentContext() else {return nil}
        self.view.layer.render(in: currentContext)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}

extension CoreAnimPatternViewController: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if (flag) { // in case this method is triggered by removing the animation
            let tile: TileLayer? = anim.value(forKey: "tileLayer") as? TileLayer
            if let t = tile, let lt = lastTile {
                t.position = CGPoint(x: backingView!.bounds.width/2.0,
                                     y: (lt.presentation()?.position.y ?? lt.position.y) - tileHeight)
                t.removeAnimation(forKey: "move down")
                lastTile = t
                self.animateTile(tile: t)
            } else {
                print("no tile found for the key or no lastTile")
            }
        }
    }
}
