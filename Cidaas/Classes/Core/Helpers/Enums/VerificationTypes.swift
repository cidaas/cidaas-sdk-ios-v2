//
//  VerificationTypes.swift
//  Cidaas
//
//  Created by ganesh on 23/07/18.
//

import Foundation

public enum VerificationTypes : String {
    case PATTERN = "PATTERN"
    case TOUCH = "TOUCHID"
    case PUSH = "PUSH"
    case FACE = "FACE"
    case VOICE = "VOICE"
    case TOTP = "TOTP"
    case EMAIL = "EMAIL"
    case SMS = "SMS"
    case IVR = "IVR"
    case BACKUPCODE = "BACKUPCODE"
    case PASSWORD = "PASSWORD"
}
