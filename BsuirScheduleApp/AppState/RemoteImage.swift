//
//  RemoteImage.swift
//  BsuirScheduleApp
//
//  Created by Anton Siliuk on 3/7/20.
//  Copyright © 2020 Saute. All rights reserved.
//

import Combine
import Foundation
import UIKit
import BsuirApi

enum ContentState<Value> {
    case initial
    case loading
    case error
    case some(Value)
}

extension ContentState: Equatable where Value: Equatable {}

class LoadableContent<Value>: ObservableObject {

    @Published private(set) var state: ContentState<Value> = .initial
    
    init(_ load: AnyPublisher<Value, Error>) {
        self.loadPublisher = load
    }

    func load() {
        loading = loadPublisher
            .map(ContentState.some)
            .receive(on: RunLoop.main)
            .replaceError(with: .error)
            .weekAssign(to: \.state, on: self)
    }

    func stop() {
        loading = nil
    }

    private let loadPublisher: AnyPublisher<Value, Error>
    private var loading: AnyCancellable?
}

extension Publisher {

    func eraseToLoading() -> AnyPublisher<Output, Error> {
        self.mapError { $0 }.eraseToAnyPublisher()
    }
}

final class RemoteImage: LoadableContent<UIImage?> {

    init(requestManager: RequestsManager, url: URL?) {
        super.init(
            Just(url)
                .compactMap { $0 }
                .setFailureType(to: URLError.self)
                .flatMap(requestManager.session.dataTaskPublisher)
                .log(.appState, identifier: "RemoteImage(\(url?.absoluteString ?? "No url"))")
                .map { UIImage(data: $0.data) }
                .eraseToLoading()
        )
    }
}
