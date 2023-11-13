//
//  AppDelegate.swift
//  LinkMapInspector
//
//  Created by StevenChoi on 2022/12/16.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var welcomeWindowController : NSWindowController? = {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        return storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("welcome-window-controller")) as? NSWindowController
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if NSDocumentController.shared.documents.isEmpty {
            showWelcome()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false;
    }
    
    func showWelcome() {
        self.welcomeWindowController?.showWindow(self)
    }
}

