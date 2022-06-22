//
//  TableViewCellViewModelMapping.swift
//  DTTableViewManager
//
//  Created by Denys Telezhkin on 22.06.2022.
//  Copyright © 2022 Denys Telezhkin. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import DTModelStorage
import UIKit

// swiftlint:disable missing_docs

open class TableViewCellViewModelMapping<Cell: UITableViewCell, Model>: CellViewModelMapping<Cell, Model>, CellViewModelMappingProtocolGeneric {
    public typealias Cell = Cell
    public typealias Model = Model
    /// Reuse identifier to be used for reusable cells.
    public var reuseIdentifier : String
    
    /// Xib name for mapping. This value will not be nil only if XIBs are used for this particular mapping.
    public var xibName: String?
    
    /// Bundle in which resources for this mapping will be searched for. For example, `DTTableViewManager` uses this property to get bundle, from which xib file for `UITableViewCell` will be retrieved. Defaults to `Bundle(for: Cell.self)`.
    /// When used for events that rely on modelClass(`.eventsModelMapping(viewType: modelClass:` method) defaults to `Bundle.main`.
    public var bundle: Bundle
    
    /// Type-erased update block, that will be called when `ModelTransfer` `update(with:)` method needs to be executed.
    public let updateBlock : (Any, Any) -> Void
    
    private var _cellConfigurationHandler: ((UITableViewCell, Any, IndexPath) -> Void)?
    private var _cellDequeueClosure: ((_ containerView: UITableView, _ model: Any, _ indexPath: IndexPath) -> UITableViewCell?)?
    
    /// Creates `ViewModelMapping` for UITableViewCell registration.
    /// - Parameters:
    ///   - cellConfiguration: Cell handler closure to be executed when cell is dequeued.
    ///   - mapping: mapping closure, that is executed at the end of initializer to allow mapping customization.
    public init(cellConfiguration: @escaping ((Cell, Model, IndexPath) -> Void),
                          mapping: ((TableViewCellViewModelMapping<Cell, Model>) -> Void)?)
    {
        
        xibName = String(describing: Cell.self)
        reuseIdentifier = String(describing: Cell.self)
        bundle = Bundle(for: Cell.self)
        updateBlock = { _, _ in }
        super.init(viewClass: Cell.self)
        _cellConfigurationHandler = { cell, model, indexPath in
            guard let view = cell as? Cell, let model = model as? Model else { return }
            cellConfiguration(view, model, indexPath)
        }
        _cellDequeueClosure = { [weak self] tableView, model, indexPath in
            guard let self = self, let model = model as? Model else { return nil }
            let cell = tableView.dequeueReusableCell(withIdentifier: self.reuseIdentifier, for: indexPath)
            if let cell = cell as? Cell {
                cellConfiguration(cell, model, indexPath)
            }
            return cell
        }
        mapping?(self)
    }
    
    /// Creates `ViewModelMapping` for UITableViewCell registration. This initializer is used, when UITableViewCell conforms to `ModelTransfer` protocol.
    /// - Parameters:
    ///   - cellConfiguration: Cell handler closure to be executed when cell is dequeued.
    ///   - mapping: mapping closure, that is executed at the end of initializer to allow mapping customization.
    public init(cellConfiguration: @escaping ((Cell, Cell.ModelType, IndexPath) -> Void),
                mapping: ((TableViewCellViewModelMapping<Cell, Cell.ModelType>) -> Void)?)
        where Cell: ModelTransfer, Cell.ModelType == Model
    {
        xibName = String(describing: Cell.self)
        reuseIdentifier = String(describing: Cell.self)
        bundle = Bundle(for: Cell.self)
        updateBlock = { view, model in
            guard let view = view as? Cell, let model = model as? Cell.ModelType else { return }
            view.update(with: model)
        }
        super.init(viewClass: Cell.self)
        
        _cellConfigurationHandler = { cell, model, indexPath in
            guard let view = cell as? Cell, let model = model as? Model else { return }
            cellConfiguration(view, model, indexPath)
        }
        _cellDequeueClosure = { [weak self] tableView, model, indexPath in
            guard let self = self, let model = model as? Cell.ModelType else {
                return nil
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: self.reuseIdentifier, for: indexPath)
            if let cell = cell as? Cell {
                cellConfiguration(cell, model, indexPath)
            }
            return cell
        }
        mapping?(self)
    }
    
    open override func updateCell(cell: Any, at indexPath: IndexPath, with model: Any) {
        guard let cell = cell as? UITableViewCell else {
            preconditionFailure("Cannot update a cell, which is not a UITableViewCell")
        }
        _cellConfigurationHandler?(cell, model, indexPath)
        updateBlock(cell, model)
    }
    
    open override func dequeueConfiguredReusableCell(for collectionView: UICollectionView, model: Any, indexPath: IndexPath) -> UICollectionViewCell? {
        preconditionFailure("This method should not be used in UITableView cell view model mapping")
    }
    
    /// Dequeues reusable cell for `model`, `indexPath` from `tableView`. Calls `cellConfiguration` closure, that was passed to initializer, then calls `ModelTransfer.update(with:)` if this cell conforms to `ModelTransfer` protocol.
    /// - Parameters:
    ///   - tableView: UITableView instance to dequeue cell from
    ///   - model: model object, that was mapped to cell type.
    ///   - indexPath: IndexPath, at which cell is going to be displayed.
    /// - Returns: dequeued configured UITableViewCell instance.
    open override func dequeueConfiguredReusableCell(for tableView: UITableView, model: Any, indexPath: IndexPath) -> UITableViewCell? {
        guard let cell = _cellDequeueClosure?(tableView, model, indexPath) else {
            return nil
        }
        updateBlock(cell, model)
        return cell
    }
}
