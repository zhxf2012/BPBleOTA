//
//  UIViewController+Hudable.swift
//  BPenPLusDemoSwift
//
//  Created by xingfa on 2022/1/8.
//  Copyright © 2022 bbb. All rights reserved.
//

import Foundation
import UIKit
import MBProgressHUD

extension UIViewController {
    @discardableResult
    func showAlert(title: String?,message: String? ,confirm:UIAlertAction?,cancel:UIAlertAction?,otherActions:[UIAlertAction] = [] ,preferredStyle:UIAlertController.Style = .alert,presentCompleted:(() -> Void)? = nil) -> UIAlertController? {
        let alert = UIAlertController.init(title: title, message: message, preferredStyle:preferredStyle )
        DispatchQueue.main.async {
             
            for action in otherActions {
                alert.addAction(action)
            }
            
            if let cancel = cancel {
                alert.addAction(cancel)
            }
            
            if let confirm  = confirm {
                alert.addAction(confirm)
            }
            
            
            self.present(alert, animated: true, completion: presentCompleted)
        }
        return alert
    }
    
    func createHud() -> MBProgressHUD {
        let pre = MBProgressHUD.forView(view)
        pre?.hide(animated: true)
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        return hud
    }
    
    func hideAllHud() {
        asyncInMainQueueBlock {[weak self] in
            if let view = self?.view, let pre = MBProgressHUD.forView(view) {
               pre.hide(animated: true)
            }
        }
    }
    
    func asyncInMainQueueBlock(_ block:@escaping (() -> Void)) {
        if Thread.current.isMainThread {
             block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
    func showProgressWith(_ title: String,progressMsg:String) {
        asyncInMainQueueBlock {[weak self] in
            let progressHud = self?.createHud()
            progressHud?.label.text = title
            progressHud?.detailsLabel.text = progressMsg
            progressHud?.show(animated: true)
        }
    }
    
    func showMessageWithTitle(_ title:String = "", msg:String,disapperAfterDelay:TimeInterval = 2) {
        asyncInMainQueueBlock { [weak self] in
            let progressHud = self?.createHud()
            progressHud?.mode = .text
            progressHud?.label.text = title
            progressHud?.detailsLabel.text = msg
            progressHud?.show(animated: true)
            progressHud?.hide(animated: true, afterDelay: disapperAfterDelay)
        }
    }
}
