import Foundation
import Combine

protocol InvoiceRepository {
    func getAll() throws -> [Invoice]
    func save(_ invoice: Invoice) throws
    func delete(id: String) throws
}

protocol CloudInvoiceServicing: Sendable {
    func getAll() async throws -> [Invoice]
    func create(_ invoice: Invoice) async throws -> Invoice
    func update(_ invoice: Invoice) async throws -> Invoice
    func delete(id: String) async throws
}

final class LocalInvoiceRepository: InvoiceRepository {
    private let fileURL: URL?
    private var memoryInvoices: [Invoice]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = LocalInvoiceRepository.defaultFileURL, seed: [Invoice] = []) {
        self.fileURL = fileURL
        self.memoryInvoices = seed
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    convenience init(scope: String) {
        self.init(fileURL: Self.fileURL(for: scope))
    }

    func getAll() throws -> [Invoice] {
        guard let fileURL else { return sorted(memoryInvoices) }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return sorted(try decoder.decode([Invoice].self, from: Data(contentsOf: fileURL)))
    }

    func save(_ invoice: Invoice) throws {
        var invoices = try getAll()
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        } else {
            invoices.append(invoice)
        }
        try persist(invoices)
    }

    func delete(id: String) throws {
        var invoices = try getAll()
        invoices.removeAll { $0.id == id }
        try persist(invoices)
    }

    private func persist(_ invoices: [Invoice]) throws {
        guard let fileURL else {
            memoryInvoices = invoices
            return
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(invoices).write(to: fileURL, options: .atomic)
    }

    private func sorted(_ invoices: [Invoice]) -> [Invoice] {
        invoices.sorted { $0.updatedAt > $1.updatedAt }
    }

    private static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "SingilanNa/invoices.json")
    }

    private static func fileURL(for scope: String) -> URL {
        guard scope != InvoiceStore.guestScope else { return defaultFileURL }
        let safeScope = scope.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "account"
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "SingilanNa/accounts/\(safeScope)/invoices.json")
    }
}

@MainActor
final class InvoiceStore: ObservableObject {
    private struct HistorySnapshot {
        let invoices: [Invoice]
        let tombstones: Set<String>
    }
    @Published private(set) var invoices: [Invoice] = []
    @Published var errorMessage: String?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncAt: Date?
    nonisolated static let guestScope = "guest"
    private var repository: any InvoiceRepository
    private(set) var scope: String
    private var tombstoneURL: URL?
    private var undoStack: [HistorySnapshot] = []
    private var redoStack: [HistorySnapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init() {
        scope = Self.guestScope
        repository = LocalInvoiceRepository(scope: Self.guestScope)
        tombstoneURL = nil
        reload()
    }

    init(repository: any InvoiceRepository, scope: String = InvoiceStore.guestScope, tombstoneURL: URL? = nil) {
        self.repository = repository
        self.scope = scope
        self.tombstoneURL = tombstoneURL
        reload()
    }

    var isGuestScope: Bool { scope == Self.guestScope }

    func save(_ invoice: Invoice) -> Bool {
        do {
            recordHistory()
            try repository.save(invoice)
            reload()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(at offsets: IndexSet) {
        do {
            recordHistory()
            for index in offsets {
                try deleteLocally(id: invoices[index].id)
            }
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ invoice: Invoice) {
        do {
            recordHistory()
            try deleteLocally(id: invoice.id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func duplicate(_ invoice: Invoice) {
        _ = save(InvoiceOperations.duplicate(invoice))
    }

    func switchScope(to newScope: String, migrateCurrent: Bool) {
        guard newScope != scope else { return }
        do {
            let sourceRepository = repository
            let migration = migrateCurrent ? try sourceRepository.getAll() : []
            scope = newScope
            repository = LocalInvoiceRepository(scope: newScope)
            tombstoneURL = Self.defaultTombstoneURL(for: newScope)
            for invoice in migration { try repository.save(invoice) }
            if migrateCurrent {
                for invoice in migration { try sourceRepository.delete(id: invoice.id) }
            }
            undoStack.removeAll()
            redoStack.removeAll()
            lastSyncAt = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func synchronize(using cloud: any CloudInvoiceServicing) async -> Bool {
        guard !isSyncing else { return false }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let localInvoices = try repository.getAll()
            let cloudInvoices = try await cloud.getAll()
            var deletedIDs = try loadTombstones()
            let deletedThisSync = deletedIDs

            for id in deletedIDs {
                try await cloud.delete(id: id)
                deletedIDs.remove(id)
                try persistTombstones(deletedIDs)
            }

            let localByID = Dictionary(uniqueKeysWithValues: localInvoices.map { ($0.id, $0) })
            let cloudByID = Dictionary(uniqueKeysWithValues: cloudInvoices.map { ($0.id, $0) })

            for local in localInvoices {
                if let remote = cloudByID[local.id] {
                    if isNewer(local, than: remote) {
                        _ = try await cloud.update(local)
                    } else if isNewer(remote, than: local) {
                        try repository.save(remote)
                    }
                } else {
                    _ = try await cloud.create(local)
                }
            }

            for remote in cloudInvoices where localByID[remote.id] == nil && !deletedThisSync.contains(remote.id) {
                try repository.save(remote)
            }

            reload()
            lastSyncAt = .now
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func isNewer(_ candidate: Invoice, than other: Invoice) -> Bool {
        if candidate.revision != other.revision { return candidate.revision > other.revision }
        return candidate.updatedAt > other.updatedAt
    }

    private func deleteLocally(id: String) throws {
        try repository.delete(id: id)
        guard !isGuestScope else { return }
        var tombstones = try loadTombstones()
        tombstones.insert(id)
        try persistTombstones(tombstones)
    }

    private func loadTombstones() throws -> Set<String> {
        guard let tombstoneURL, FileManager.default.fileExists(atPath: tombstoneURL.path) else { return [] }
        return Set(try JSONDecoder().decode([String].self, from: Data(contentsOf: tombstoneURL)))
    }

    private func persistTombstones(_ ids: Set<String>) throws {
        guard let tombstoneURL else { return }
        try FileManager.default.createDirectory(at: tombstoneURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(ids.sorted()).write(to: tombstoneURL, options: .atomic)
    }

    private static func defaultTombstoneURL(for scope: String) -> URL? {
        guard scope != guestScope else { return nil }
        let safeScope = scope.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "account"
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "SingilanNa/accounts/\(safeScope)/deleted-invoices.json")
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        replaceAll(with: previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        replaceAll(with: next)
    }

    private func recordHistory() {
        undoStack.append(currentSnapshot())
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func currentSnapshot() -> HistorySnapshot {
        HistorySnapshot(invoices: invoices, tombstones: (try? loadTombstones()) ?? [])
    }

    private func replaceAll(with snapshot: HistorySnapshot) {
        do {
            for invoice in try repository.getAll() { try repository.delete(id: invoice.id) }
            for invoice in snapshot.invoices { try repository.save(invoice) }
            try persistTombstones(snapshot.tombstones)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload() {
        do {
            invoices = try repository.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static var preview: InvoiceStore {
        InvoiceStore(repository: LocalInvoiceRepository(fileURL: nil))
    }
}
