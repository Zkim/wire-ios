// Wire
// Copyright (C) 2020 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation

enum SplitViewControllerLayoutSize : Int {
    case compact
    case regularPortrait
    case regularLandscape
}

protocol SplitLayoutObservable: NSObjectProtocol {
    var layoutSize: SplitViewControllerLayoutSize { get }
    var leftViewControllerWidth: CGFloat { get }
}

var SplitLayoutObservableDidChangeToLayoutSizeNotification: String?

protocol SplitViewControllerDelegate: NSObjectProtocol {
    func splitViewControllerShouldMoveLeftViewController(_ splitViewController: SplitViewController?) -> Bool
}

extension UIViewController {
    var wr_splitViewController: SplitViewController? {
        var possibleSplit = self
        
        repeat {
            if (possibleSplit is SplitViewController) {
                return possibleSplit as? SplitViewController
            }
            if let parentViewController = possibleSplit.parent {
                possibleSplit = parentViewController
            }
        } while possibleSplit != nil
        
        return nil
    }
}

class SplitViewController {
    private var horizontalPanner: UIPanGestureRecognizer?
    private var futureTraitCollection: UITraitCollection?
}
enum SplitViewControllerTransition : Int {
    case `default`
    case present
    case dismiss
}

// TODO: ext noti
var SplitLayoutObservableDidChangeToLayoutSizeNotification = "SplitLayoutObservableDidChangeToLayoutSizeNotificationName"


final class SplitViewController: UIViewController, SplitLayoutObservable {
    private var leftView: UIView?
    private var rightView: UIView?
    private var openPercentage: CGFloat = 0.0
    private var leftViewLeadingConstraint: NSLayoutConstraint?
    private var rightViewLeadingConstraint: NSLayoutConstraint?
    private var leftViewWidthConstraint: NSLayoutConstraint?
    private var rightViewWidthConstraint: NSLayoutConstraint?
    private var sideBySideConstraint: NSLayoutConstraint?
    private var pinLeftViewOffsetConstraint: NSLayoutConstraint?
    private var layoutSize: SplitViewControllerLayoutSize?

    
    var leftViewController: UIViewController?
    var rightViewController: UIViewController?
    var leftViewControllerRevealed = false
    weak var delegate: SplitViewControllerDelegate?

    private func constraintsInactiveForCurrentLayout() -> [AnyHashable]? {
    }

    private func constraintsActiveForCurrentLayout() -> [AnyHashable]? {
    }

    private func transition(from fromViewController: UIViewController?, to toViewController: UIViewController?, containerView: UIView?, animator: UIViewControllerAnimatedTransitioning?, animated: Bool, completion: () -> ()? = nil) -> Bool {
    }

    func viewDidLoad() {
        super.viewDidLoad()
        
        leftView = UIView(frame: UIScreen.main.bounds)
        leftView?.translatesAutoresizingMaskIntoConstraints = false
        if let leftView = leftView {
            view.addSubview(leftView)
        }
        
        rightView = PlaceholderConversationView(frame: UIScreen.main.bounds)
        rightView?.translatesAutoresizingMaskIntoConstraints = false
        rightView?.backgroundColor = UIColor.wr_color(fromColorScheme: ColorSchemeColorBackground)
        if let rightView = rightView {
            view.addSubview(rightView)
        }
        
        setupInitialConstraints()
        updateLayoutSize(for: traitCollection)
        updateConstraints(forSize: view.bounds.size)
        updateActiveConstraints()
        
        leftViewControllerRevealed = true
        openPercentage = 1
        horizontalPanner = UIPanGestureRecognizer(target: self, action: #selector(onHorizontalPan(_:)))
        horizontalPanner.delegate = self
        view.addGestureRecognizer(horizontalPanner)
    }
    
    func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        update(forSize: view.bounds.size)
    }
    
    func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        update(for: size)
        
        coordinator.animate(alongsideTransition: { context in
        }) { context in
            self.updateLayoutSizeAndLeftViewVisibility()
        }
        
    }
    
    func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        futureTraitCollection = newCollection
        updateLayoutSize(for: newCollection)
        
        super.willTransition(to: newCollection, with: coordinator)
        
        updateActiveConstraints()
        
        updateLeftViewVisibility()
    }

    func update(for size: CGSize) {
        if nil != futureTraitCollection {
            updateLayoutSize(forTraitCollection: futureTraitCollection)
        } else {
            updateLayoutSize(for: traitCollection)
        }
        
        updateConstraints(for: size)
        updateActiveConstraints()
        
        futureTraitCollection = nil
        
        // update right view constraits after size changes
        updateRightAndLeftEdgeConstraints(openPercentage)
    }
    
    func updateConstraints(for size: CGSize) {
        updateConstraints(for: size, willMoveToEmptyView: false)
    }
    
    func updateLayoutSizeAndLeftViewVisibility() {
        updateLayoutSize(for: traitCollection)
        updateLeftViewVisibility()
    }
    
    func updateLeftViewVisibility() {
        switch layoutSize {
        case SplitViewControllerLayoutSizeCompact /* fallthrough */, SplitViewControllerLayoutSizeRegularPortrait:
            leftView?.isHidden = openPercentage == 0
        case SplitViewControllerLayoutSizeRegularLandscape:
            leftView?.isHidden = false
        default:
            break
        }
    }
    
    func leftViewControllerWidth() -> CGFloat {
        return leftViewWidthConstraint.constant
    }
    
    func setLayoutSize(_ layoutSize: SplitViewControllerLayoutSize) {
        if self.layoutSize != layoutSize {
            self.layoutSize = layoutSize
            NotificationCenter.default.post(name: SplitLayoutObservableDidChangeToLayoutSizeNotification, object: self)
        }
    }

    func constraintsActiveForCurrentLayout() -> [AnyHashable]? {
        var constraints: Set<AnyHashable> = []
        
        if layoutSize == SplitViewControllerLayoutSizeRegularLandscape {
            constraints.formUnion(Set([pinLeftViewOffsetConstraint, sideBySideConstraint]))
        }
        
        constraints.formUnion(Set([leftViewWidthConstraint]))
        
        return Array(constraints)
    }
    
    func constraintsInactiveForCurrentLayout() -> [AnyHashable]? {
        var constraints: Set<AnyHashable> = []
        
        if layoutSize != SplitViewControllerLayoutSizeRegularLandscape {
            constraints.formUnion(Set([pinLeftViewOffsetConstraint, sideBySideConstraint]))
        }
        
        return Array(constraints)
    }
    
    private func setInternalLeftViewController(_ leftViewController: UIViewController?) {
        self.leftViewController = leftViewController
    }
    
    func setLeftViewController(_ leftViewController: UIViewController?) {
        setLeftViewController(leftViewController, animated: false)
    }
    
    func setLeftViewController(_ leftViewController: UIViewController?, animated: Bool, completion: () -> ()? = nil) {
        setLeftViewController(leftViewController, animated: animated, transition: SplitViewControllerTransitionDefault, completion: completion)
    }
    
    func setRightViewController(_ rightViewController: UIViewController?) {
        setRightViewController(rightViewController, animated: false, completion: nil)
    }

    func setRightViewController(_ rightViewController: UIViewController?, animated: Bool, completion: () -> ()? = nil) {
        if self.rightViewController == rightViewController {
            return
        }
        
        // To determine if self.rightViewController.presentedViewController is actually presented over it, or is it
        // presented over one of it's parents.
        if self.rightViewController.presentedViewController.presentingViewController == self.rightViewController {
            self.rightViewController.dismiss(animated: false)
        }
        
        let removedViewController = self.rightViewController
        
        let transitionDidStart = transition(from: removedViewController, to: rightViewController, containerView: rightView, animator: animatorForRightView(), animated: animated, completion: completion)
        
        if transitionDidStart {
            self.rightViewController = rightViewController
        }
    }
    func setRightViewController(_ rightViewController: UIViewController?, animated: Bool, completion: () -> ()? = nil) {
        if self.rightViewController == rightViewController {
            return
        }
        
        // To determine if self.rightViewController.presentedViewController is actually presented over it, or is it
        // presented over one of it's parents.
        if self.rightViewController.presentedViewController.presentingViewController == self.rightViewController {
            self.rightViewController.dismiss(animated: false)
        }
        
        let removedViewController = self.rightViewController
        
        let transitionDidStart = transition(from: removedViewController, to: rightViewController, containerView: rightView, animator: animatorForRightView(), animated: animated, completion: completion)
        
        if transitionDidStart {
            self.rightViewController = rightViewController
        }
    }

    func setLeftViewControllerRevealed(_ leftViewControllerIsRevealed: Bool) {
        leftViewControllerRevealed = leftViewControllerIsRevealed
        updateLeftViewControllerVisibility(animated: true, completion: nil)
    }
    
    func setLeftViewControllerRevealed(_ leftViewControllerRevealed: Bool, animated: Bool, completion: () -> ()? = nil) {
        self.leftViewControllerRevealed = leftViewControllerRevealed
        updateLeftViewControllerVisibility(animated: animated, completion: completion)
    }
    
    private func resetOpenPercentage() {
        openPercentage = leftViewControllerRevealed ? 1 : 0
    }
    
    func setOpenPercentage(_ percentage: CGFloat) {
        openPercentage = percentage
        updateRightAndLeftEdgeConstraints(percentage)
        
        setNeedsStatusBarAppearanceUpdate()
    }
    
    func updateRightAndLeftEdgeConstraints(_ percentage: CGFloat) {
        rightViewLeadingConstraint.constant = leftViewWidthConstraint.constant * percentage
        leftViewLeadingConstraint.constant = 64.0 * (1.0 - percentage)
    }

    func setLeft(_ leftViewController: UIViewController?, animated: Bool, completion: () -> ()? = nil) {
    }

    func setRight(_ rightViewController: UIViewController?, animated: Bool, completion: () -> ()? = nil) {
    }

    func setLeftViewControllerRevealed(_ leftViewControllerIsRevealed: Bool, animated: Bool, completion: () -> ()? = nil) {
    }

    private var childViewController: UIViewController? {
        return openPercentage > 0 ? leftViewController : rightViewController
    }

    override open var childForStatusBarStyle: UIViewController? {
        return childViewController
    }

    override open var childForStatusBarHidden: UIViewController? {
        return childViewController
    }

    // MARK: - animator
    @objc
    var animatorForRightView: UIViewControllerAnimatedTransitioning? {
        if layoutSize == .compact && isLeftViewControllerRevealed {
            // Right view is not visible so we should not animate.
            return CrossfadeTransition(duration: 0)
        } else if layoutSize == .regularLandscape {
            return SwizzleTransition(direction: .horizontal)
        }

        return CrossfadeTransition()
    }

    @objc
    func setLeftViewController(_ leftViewController: UIViewController?,
                               animated: Bool,
                               transition: SplitViewControllerTransition,
                               completion: Completion?) {
        if self.leftViewController == leftViewController {
            completion?()
            return
        }

        let removedViewController = self.leftViewController

        let animator: UIViewControllerAnimatedTransitioning

        if removedViewController == nil || leftViewController == nil {
            animator = CrossfadeTransition()
        } else if transition == .present {
            animator = VerticalTransition(offset: 88)
        } else if transition == .dismiss {
            animator = VerticalTransition(offset: -88)
        } else {
            animator = CrossfadeTransition()
        }

        if self.transition(from: removedViewController, to: leftViewController, containerView: leftView, animator: animator, animated: animated, completion: completion) {
            self.setInternalLeft(leftViewController)
        }
    }
}
