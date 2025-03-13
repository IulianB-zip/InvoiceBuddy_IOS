//
//  CancellationTokenBag.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 13.03.2025.
//


import Combine

// Cancellation token bag to store publishers
class CancellationTokenBag {
    static let shared = CancellationTokenBag()
    var tokens = Set<AnyCancellable>()
}