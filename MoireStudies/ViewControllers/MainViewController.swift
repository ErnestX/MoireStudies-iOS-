//
//  ViewController.swift
//  MoireStudies
//
//  Created by Jialiang Xiang on 2020-12-25.
//

import Foundation
import UIKit

class MainViewController: UIViewController {
    @IBOutlet weak var gearButton: UIButton!
    @IBOutlet weak var fileButton: UIButton!
    var initSettings: InitSettings?
    var resetMoireWhenInit = false
    private var moire: Moire?
    private var controlFrames: Array<CGRect> = Constants.UI.defaultControlFrames
    private var controlViewControllers: Array<CtrlViewTarget> = []
    private var mainView: MainView? {
        get {
            return self.view as? MainView
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.initModel()
        let mv = self.mainView!
        mv.setUp(patterns: moire!.patterns)
        // set up control views
        assert(controlFrames.count >= moire!.patterns.count)
        for i in 0..<moire!.patterns.count {
            var cvc: CtrlViewTarget?
            switch self.initSettings!.interfaceSetting {
            case UISettings.controlScheme1Slider:
                cvc = CtrlViewControllerSch1.init(id: self.getCtrlViewControllerId(index: i),
                                                      frame: controlFrames[i],
                                                      pattern: moire!.patterns[i])
            case UISettings.controlScheme2Slider:
                cvc = CtrlViewControllerSch2.init(id: self.getCtrlViewControllerId(index: i),
                                                      frame: controlFrames[i],
                                                      pattern: moire!.patterns[i])
            case UISettings.controlScheme1Gesture:
                cvc = CtrlViewControllerSch1.init(id: self.getCtrlViewControllerId(index: i),
                                                      frame: controlFrames[i],
                                                      pattern: moire!.patterns[i])
            }
            cvc!.delegate = self
            mv.addSubview(cvc!.view)
            controlViewControllers.append(cvc!)
            // set up mask for each of the control view
            if (i == 0) {
                mv.setUpMaskOnPatternView(patternIndex: 0, controlViewFrame: controlFrames[1])
            } else if (i == 1) {
                mv.setUpMaskOnPatternView(patternIndex: 1, controlViewFrame: controlFrames[0])
            }
        }
    }
    
    func initModel() {
        func resetModel() {
            self.moire = Moire()
            self.moire!.reset()
        }
        guard !self.resetMoireWhenInit else {
            resetModel()
            return
        }
        do {
            guard let data = UserDefaults.standard.value(forKey: "Moire") as? Data else {throw NSError()}
            self.moire = try PropertyListDecoder().decode(Moire.self, from: data)
        } catch {
            print("problem loading saved moire; loading the default")
            resetModel()
        }
    }
    
    func getCtrlViewControllerId(index: Int) -> Int {
        let id = index
        assert(self.getCtrlViewControllerIndex(id: id) == index, "reverse conversion test failed")
        return id
    }
    
    func getCtrlViewControllerIndex(id: Int) -> Int {
        let index = id
        return index
    }
    
    func findControlViewIndex(controlViewController: CtrlViewTarget) -> Int? {
        guard let i = controlViewController.id else {
            return nil
        }
        return self.getCtrlViewControllerIndex(id: i)
    }
    
    func reloadMoire() {
        let mv = self.mainView!
        for i in 0..<self.moire!.patterns.count {
            mv.modifiyPatternView(patternViewIndex: i, newPattern: self.moire!.patterns[i])
            let cvc = self.controlViewControllers[i]
            cvc.matchControlsWithModel(pattern: self.moire!.patterns[i])
        }
    }
    
    func saveMoire() -> Bool {
        // save preview
        if let img = self.mainView!.takeMoireScreenshot() {
            self.moire?.preview = img
        }
        // write to disk
        do {
            UserDefaults.standard.set(try PropertyListEncoder().encode(self.moire), forKey: "Moire")
            return true
        } catch {
            print("problem saving the moire")
            return false
        }
    }
    
    @IBAction func gearButtonPressed(_ sender: Any) {
        _ = self.saveMoire()
        performSegue(withIdentifier: "showSettingsView", sender: self.gearButton)
    }
    
    @IBAction func fileButtonPressed(_ sender: Any) {
        _ = self.saveMoire()
        performSegue(withIdentifier: "showSaveFilesView", sender: self.fileButton)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let s = sender as? UIButton {
            switch s {
            case self.gearButton!:
                let svc: SettingsViewController = segue.destination as! SettingsViewController
                if let currentSettings = self.initSettings {
                    svc.initSettings = currentSettings
                }
            case self.fileButton!:
                break
            default:
                break
            }
        }
        self.pauseMoire()
    }
    
    func pauseMoire() {
        self.mainView!.pauseMoire()
    }

    func resumeMoire() {
        self.mainView!.resumeMoire()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension MainViewController: PatternManager {
    func highlightPattern(caller: CtrlViewTarget) -> Bool {
        guard let index = self.findControlViewIndex(controlViewController: caller) else {
            return false
        }
        let mv = self.mainView!
        mv.highlightPatternView(patternViewIndex: index)
        return true
    }
    
    func unhighlightPattern(caller: CtrlViewTarget) -> Bool {
        guard let index = self.findControlViewIndex(controlViewController: caller) else {
            return false
        }
        let mv = self.mainView!
        mv.unhighlightPatternView(patternViewIndex: index)
        return true
    }
    
    func modifyPattern(speed: CGFloat, caller: CtrlViewTarget) -> Bool {
        print("setting speed to: ", speed)
        guard Constants.Bounds.speedRange.contains(speed) else {
            return false
        }
        guard let index = self.findControlViewIndex(controlViewController: caller) else {
            return false
        }
        moire!.patterns[index].speed = speed
        let mv = self.mainView!
        mv.modifiyPatternView(patternViewIndex: index, newPattern: moire!.patterns[index])
        return true
    }
    
    func modifyPattern(direction: CGFloat, caller: CtrlViewTarget) -> Bool {
        print("setting direction to: ", direction)
        guard Constants.Bounds.directionRange.contains(direction) else {
            return false
        }
        guard let index = self.findControlViewIndex(controlViewController: caller) else {
            return false
        }
        moire!.patterns[index].direction = direction
        let mv = self.mainView!
        mv.modifiyPatternView(patternViewIndex: index, newPattern: moire!.patterns[index])
        return true
    }
    
    func modifyPattern(fillRatio: CGFloat, caller: CtrlViewTarget) -> Bool {
        print("setting fillRatio to: ", fillRatio)
        guard Constants.Bounds.fillRatioRange.contains(fillRatio) else {
            return false
        }
        guard let index = self.findControlViewIndex(controlViewController: caller) else {
            return false
        }
        moire!.patterns[index].fillRatio = fillRatio
        let mv = self.mainView!
        mv.modifiyPatternView(patternViewIndex: index, newPattern: moire!.patterns[index])
        return true
    }
    
    func modifyPattern(scaleFactor: CGFloat, caller: CtrlViewTarget) -> Bool {
        print("setting scaleFactor to: ", scaleFactor)
        guard Constants.Bounds.scaleFactorRange.contains(scaleFactor) else {
            return false
        }
        guard let index = self.findControlViewIndex(controlViewController: caller) else {
            return false
        }
        moire!.patterns[index].scaleFactor = scaleFactor
        let mv = self.mainView!
        mv.modifiyPatternView(patternViewIndex: index, newPattern: moire!.patterns[index])
        return true
    }
    
    func getPattern(caller: CtrlViewTarget) -> Pattern? {
        guard let i = caller.id else {
            return nil
        }
        return self.moire!.patterns[getCtrlViewControllerIndex(id: i)]
    }
}

