//
//  AppState.swift
//  BsuirScheduleApp
//
//  Created by Anton Siliuk on 9/28/19.
//  Copyright © 2019 Saute. All rights reserved.
//

import Foundation
import BsuirApi
import Combine
import UIKit

import os.log

let appStateLog = OSLog(subsystem: "com.saute.BsuirScheduleApp", category: "AppState")
func log(_ message: StaticString, _ arguments: CVarArg...) { os_log(.error, log: appStateLog, message, arguments) }

enum ContentState<Value> {
    case initial
    case loading
    case error
    case some(Value)
}

extension ContentState: Equatable where Value: Equatable {}

final class AppState: ObservableObject {
    let requestManager: RequestsManager
    init(requestManager: RequestsManager) { self.requestManager = requestManager }
    private(set) lazy var allGroups = AllGroupsState(requestManager: requestManager)
    private(set) lazy var allLecturers = AllLecturersState(requestManager: requestManager)
}

final class AllGroupsState: ObservableObject {
    let requestManager: RequestsManager
    init(requestManager: RequestsManager) { self.requestManager = requestManager }

    struct MyGroup: Identifiable, Comparable {
        var id: Int { group.id }
        var name: String { group.name }

        static func < (lhs: MyGroup, rhs: MyGroup) -> Bool { lhs.name < rhs.name }

        fileprivate init(group: Group) { self.group = group }
        fileprivate let group: Group
    }

    @Published var groups: ContentState<[MyGroup]> = .loading

    func request() {
        log("Requesting all groups...")
        cancellable = requestManager
            .request(BsuirTargets.Groups())
            .map { .some($0.map(MyGroup.init).sorted()) }
            .handleEvents(
                receiveOutput: { log("Got some groups %@", String(describing: $0)) },
                receiveCompletion: { log("Groups request completed %@", String(describing: $0)) }
            )
            .replaceError(with: .error)
            .receive(on: RunLoop.main)
            .weekAssign(to: \.groups, on: self)
    }

    func state(for group: MyGroup) -> GroupState {
        return GroupState(group: group.group, requestManager: requestManager)
    }

    private var cancellable: AnyCancellable?
}

struct Day: Equatable {

    struct Pair: Hashable, Equatable {

        enum Form {
            case lecture
            case practice
            case lab
            case exam
            case unknown
        }

        let from: String
        let to: String
        let form: Form
        let subject: String
        let note: String
        let weeks: String

        init(_ pair: BsuirApi.Pair) {
            self.from = Self.timeFormatter.string(from: pair.startLessonTime.components) ?? "N/A"
            self.to = Self.timeFormatter.string(from: pair.endLessonTime.components) ?? "N/A"
            self.form = Form(pair.lessonType)
            self.subject = pair.subject
            self.note = (pair.auditory.map(Optional.some) + [pair.note]).compactMap { $0 }.joined(separator: ", ")
            self.weeks = pair.weekNumber.prettyName.capitalized
        }

        private static let timeFormatter: DateComponentsFormatter = {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .positional
            formatter.zeroFormattingBehavior = .pad
            return formatter
        }()
    }

    let title: String
    let pairs: [Pair]

    init(day: DaySchedule) {
        self.title = day.weekDay.title
        self.pairs = day.schedule.map(Pair.init)
    }
}

private extension BsuirApi.Pair.Time {

    var components: DateComponents {
        DateComponents(timeZone: timeZone, hour: hour, minute: minute)
    }
}

private extension Day.Pair.Form {

    init(_ form: BsuirApi.Pair.Form) {
        switch form {
        case .lecture: self = .lecture
        case .practice: self = .practice
        case .lab: self = .lab
        case .exam: self = .exam
        case .unknown: self = .unknown
        }
    }
}

private extension BsuirApi.WeekNum {

    var prettyName: String {
        switch self {
        case []: return "никогда"
        case .oddWeeks: return "нечетные"
        case .evenWeeks: return "четные"
        case .always: return "вчегда"
        case let numbers: return numbers.name
        }
    }

    private var name: String {
        var result: [String] = []
        if contains(.first) { result.append("первая") }
        if contains(.second) { result.append("вторая") }
        if contains(.third) { result.append("третья") }
        if contains(.forth) { result.append("четвертая") }
        return result.joined(separator: ", ")
    }
}

final class GroupState: ObservableObject {

    init(group: Group, requestManager: RequestsManager) {
        self.group = group
        self.requestManager = requestManager
    }

    var name: String { group.name }
    @Published var days: ContentState<[Day]> = .loading

    func request() {
        log("Requesting days...")
        cancellable = requestManager
            .request(BsuirTargets.Schedule(agent: .groupID(group.id)))
            .map { .some($0.schedules.map(Day.init)) }
            .handleEvents(
                receiveOutput: { log("Got some days %@", String(describing: $0)) },
                receiveCompletion: { log("Days request completed %@", String(describing: $0)) }
            )
            .replaceError(with: .error)
            .receive(on: RunLoop.main)
            .weekAssign(to: \.days, on: self)
    }

    private var cancellable: AnyCancellable?
    private let group: Group
    private let requestManager: RequestsManager
}

final class AllLecturersState: ObservableObject {

    struct Lecturer: Identifiable {
        var id: Int { employee.id }
        var fullName: String { employee.fio }

        fileprivate init(employee: Employee) { self.employee = employee }
        fileprivate let employee: Employee
    }

    @Published var lecturers: ContentState<[Lecturer]> = .loading

    init(requestManager: RequestsManager) { self.requestManager = requestManager }

    func request() {
        cancellable = requestManager
            .request(BsuirTargets.Employees())
            .map { .some($0.map(Lecturer.init)) }
            .replaceError(with: .error)
            .receive(on: RunLoop.main)
            .weekAssign(to: \.lecturers, on: self)
    }

    func state(for lecturer: Lecturer) -> LecturerState {
        return LecturerState(employee: lecturer.employee, requestManager: requestManager)
    }

    func image(for lecturer: Lecturer) -> RemoteImage {
        RemoteImage(requestManager: requestManager, url: lecturer.employee.photoLink)
    }

    private var cancellable: AnyCancellable?
    private let requestManager: RequestsManager
}

final class RemoteImage: ObservableObject {

    init(requestManager: RequestsManager, url: URL?) {
        self.requestManager = requestManager
        self.url = url
    }

    @Published var image: ContentState<UIImage?> = .initial

    func request() {
        guard let url = self.url else {
            image = .some(nil)
            cancellable = nil
            return
        }
        image = .loading
        cancellable = requestManager.session
            .dataTaskPublisher(for: url)
            .log(appStateLog, identifier: "RemoteImage(\(url.absoluteString))")
            .map { .some(UIImage(data: $0.data)) }
            .replaceError(with: .error)
            .receive(on: RunLoop.main)
            .weekAssign(to: \.image, on: self)
    }

    private var cancellable: AnyCancellable?
    private let requestManager: RequestsManager
    private let url: URL?
}

final class LecturerState: ObservableObject {

    init(employee: Employee, requestManager: RequestsManager) {
        self.employee = employee
        self.requestManager = requestManager
    }

    var name: String { employee.fio }
    @Published var days: ContentState<[Day]> = .loading

    func request() {
        cancellable = requestManager
            .request(BsuirTargets.EmployeeSchedule(id: employee.id))
            .map { .some($0.schedules?.map(Day.init) ?? []) }
            .replaceError(with: .error)
            .receive(on: RunLoop.main)
            .weekAssign(to: \.days, on: self)
    }

    private var cancellable: AnyCancellable?
    private let employee: Employee
    private let requestManager: RequestsManager
}

private extension Employee {

    var fio: String {
        return [lastName, firstName, middleName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private extension DaySchedule.Day {

    var title: String {
        switch self {
        case let .date(date): return Self.formatter.string(from: date)
        case let .relative(weekDay): return weekDay.rawValue
        }
    }

    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

private extension Publisher where Failure == Never {

    func weekAssign<Root: AnyObject>(to keyPath: ReferenceWritableKeyPath<Root, Output>, on root: Root) -> AnyCancellable {
        sink(receiveValue: { [weak root] in root?[keyPath: keyPath] = $0 })
    }
}

private extension Publisher {

    func log(_ log: OSLog, identifier: String) -> Publishers.HandleEvents<Self> {
        handleEvents(
            receiveSubscription: { _ in os_log(.error, log: log, "%{public}@: received Subscription", identifier) },
            receiveOutput: { _ in os_log(.error, log: log, "%{public}@: received Output", identifier) },
            receiveCompletion: { _ in os_log(.error, log: log, "%{public}@: received Completion", identifier) },
            receiveCancel: { os_log(.error, log: log, "%{public}@: received Cancel", identifier) },
            receiveRequest: { _ in os_log(.error, log: log, "%{public}@: received Request", identifier) }
        )
    }
}
