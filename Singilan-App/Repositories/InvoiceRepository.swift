import Foundation
import Combine

protocol InvoiceRepository {
    func getAll() throws -> [Invoice]
    func save(_ invoice: Invoice) throws
    func delete(id: String) throws
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
}

@MainActor
final class InvoiceStore: ObservableObject {
    @Published private(set) var invoices: [Invoice] = []
    @Published var errorMessage: String?
    private let repository: any InvoiceRepository
    private var undoStack: [[Invoice]] = []
    private var redoStack: [[Invoice]] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init() {
        repository = LocalInvoiceRepository()
        reload()
    }

    init(repository: any InvoiceRepository) {
        self.repository = repository
        reload()
    }

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
                try repository.delete(id: invoices[index].id)
            }
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func duplicate(_ invoice: Invoice) {
        _ = save(InvoiceOperations.duplicate(invoice))
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(invoices)
        replaceAll(with: previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(invoices)
        replaceAll(with: next)
    }

    private func recordHistory() {
        undoStack.append(invoices)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func replaceAll(with snapshot: [Invoice]) {
        do {
            for invoice in try repository.getAll() { try repository.delete(id: invoice.id) }
            for invoice in snapshot { try repository.save(invoice) }
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
