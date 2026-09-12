//
//  HeaderView.swift
//  LunarBarMac
//
//  Created by cyan on 12/21/23.
//

import AppKit
import AppKitControls
import LunarBarKit

@MainActor
protocol HeaderViewDelegate: AnyObject {
  func headerView(_ sender: HeaderView, moveTo date: Date)
  func headerView(_ sender: HeaderView, moveBy offset: Int)
  func headerView(_ sender: HeaderView, showActionsMenu sourceView: NSView)
}

/**
 Calendar header, showing the date and a few buttons for navigation.

 Example: [ Dec 2023  Week 50    < O > ]
 */
final class HeaderView: NSView {
  weak var delegate: HeaderViewDelegate?

  private let dateLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .monospacedDigitSystemFont(ofSize: Constants.dateFontSize, weight: .medium)

    return label
  }()

  private let weekLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.alphaValue = AlphaLevels.secondary
    label.font = .monospacedDigitSystemFont(ofSize: Constants.weekFontSize, weight: .medium)
    label.setAccessibilityElement(true)

    return label
  }()

  private lazy var nextButton: ImageButton = {
    let button = createButton(
      symbolName: Icons.chevronCompactForward,
      accessibilityLabel: Localized.UI.buttonTitleNextMonth
    )

    button.addAction { [weak self] in
      guard let self else {
        return
      }

      delegate?.headerView(self, moveBy: 1)
    }

    button.toolTip = Localized.UI.buttonTitleNextMonth + " ▶"
    return button
  }()

  private lazy var actionsButton: ImageButton = {
    let button = createButton(
      symbolName: Icons.circle,
      accessibilityLabel: Localized.UI.buttonTitleShowActions
    )

    button.addAction { [weak self] in
      guard let self else {
        return
      }

      self.delegate?.headerView(self, showActionsMenu: actionsButton)
    }

    return button
  }()

  private lazy var previousButton: ImageButton = {
    let button = createButton(
      symbolName: Icons.chevronCompactBackward,
      accessibilityLabel: Localized.UI.buttonTitlePreviousMonth
    )

    button.addAction { [weak self] in
      guard let self else {
        return
      }

      delegate?.headerView(self, moveBy: -1)
    }

    button.toolTip = "◀ " + Localized.UI.buttonTitlePreviousMonth
    return button
  }()

  private var previousDate: Date = .distantPast

  init() {
    super.init(frame: .zero)

    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(dateLabel)
    NSLayoutConstraint.activate([
      dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.datePadding),
      dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

    weekLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(weekLabel)
    weekLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    nextButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(nextButton)
    NSLayoutConstraint.activate([
      nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.buttonPadding),
      nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      nextButton.widthAnchor.constraint(equalToConstant: nextButton.frame.width),
      nextButton.heightAnchor.constraint(equalToConstant: nextButton.frame.height),
    ])

    actionsButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(actionsButton)
    NSLayoutConstraint.activate([
      actionsButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor),
      actionsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      actionsButton.widthAnchor.constraint(equalToConstant: actionsButton.frame.width),
      actionsButton.heightAnchor.constraint(equalToConstant: actionsButton.frame.height),
    ])

    previousButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(previousButton)
    NSLayoutConstraint.activate([
      previousButton.trailingAnchor.constraint(equalTo: actionsButton.leadingAnchor),
      previousButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      previousButton.widthAnchor.constraint(equalToConstant: previousButton.frame.width),
      previousButton.heightAnchor.constraint(equalToConstant: previousButton.frame.height),
    ])

    NSLayoutConstraint.activate([
      weekLabel.leadingAnchor.constraint(equalTo: dateLabel.trailingAnchor, constant: Constants.weekPadding),
      weekLabel.firstBaselineAnchor.constraint(equalTo: dateLabel.firstBaselineAnchor),
      weekLabel.trailingAnchor.constraint(lessThanOrEqualTo: previousButton.leadingAnchor, constant: -Constants.datePadding),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)

    let location = convert(event.locationInWindow, from: nil)
    if dateLabel.frame.contains(location) || weekLabel.frame.contains(location) {
      delegate?.headerView(self, moveTo: .now)
    }
  }
}

// MARK: - Updating

extension HeaderView {
  enum ButtonIdentifier {
    case previous
    case actions
    case next
  }

  func updateCalendar(date: Date) {
    dateLabel.stringValue = Constants.dateFormatter.string(from: date)

    let isoWeek = Calendar.iso8601.component(.weekOfYear, from: date)
    weekLabel.stringValue = String.localizedStringWithFormat(Localized.Calendar.isoWeekFormat, isoWeek)

    if !AppPreferences.Accessibility.reduceMotion, previousDate != .distantPast,
       !Calendar.solar.isDate(previousDate, inSameMonthAs: date) {
      [dateLabel, weekLabel].forEach { label in
        let transition = CATransition()
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = .push
        transition.subtype = previousDate < date ? .fromBottom : .fromTop
        transition.duration = 0.25

        label.wantsLayer = true
        label.layer?.add(transition, forKey: "pushEffect")
      }
    }

    previousDate = date
  }

  func showClickEffect(for identifier: ButtonIdentifier) {
    guard !AppPreferences.Accessibility.reduceMotion else {
      return
    }

    let button = {
      switch identifier {
      case .previous: return previousButton
      case .actions: return actionsButton
      case .next: return nextButton
      }
    }()

    button.setAlphaValue(0.6) {
      Task { @MainActor in
        button.setAlphaValue(1)
      }
    }
  }
}

// MARK: - Private

private extension HeaderView {
  enum Constants {
    static let dateFontSize: Double = FontSizes.large
    static let weekFontSize: Double = 12
    static let datePadding: Double = 9
    static let weekPadding: Double = 6
    static let buttonPadding: Double = 6
    static let dateFormatter: DateFormatter = .localizedMonth
  }

  func createButton(symbolName: String, accessibilityLabel: String) -> ImageButton {
    ImageButton(
      symbolName: symbolName,
      sizeDelta: AppDesign.modernStyle ? 1 : 0,
      cornerRadius: AppDesign.cellCornerRadius,
      highlightColorProvider: { .highlightedBackground },
      tintColor: Colors.primaryLabel,
      accessibilityLabel: accessibilityLabel
    )
  }
}
