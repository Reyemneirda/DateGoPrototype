//
//  SlideMenuViewController.swift
//  DateGoPrototype
//
//  Created by Adrien Meyer on 21/04/2018.
//  Copyright © 2018 DateGo. All rights reserved.
//

import Foundation
import ViewDeck


class SlideMenuExampleViewController: IIViewDeckController
{
    
    
    lazy var menuController : UIViewController = {
        
        let storyboard : UIStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        
        return storyboard.instantiateViewController(withIdentifier: "MenuController")
        
    }()
    
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.leftViewController = self.menuController
        self.centerViewController = self.menuController
        
        self.isPanningEnabled = false
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    
    
}
