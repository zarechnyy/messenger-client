//
//  MessageModel.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/11/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation
import MessageKit

struct Message: MessageType {
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
}
