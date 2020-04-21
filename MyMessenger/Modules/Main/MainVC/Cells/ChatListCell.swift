//
//  ChatListCell.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 3/17/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import UIKit

class ChatListCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        statusView.layer.cornerRadius = 6
        statusView.backgroundColor = .red
    }
}
