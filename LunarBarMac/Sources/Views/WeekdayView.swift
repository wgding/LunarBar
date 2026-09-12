//
//  WeekdayView.swift
//  LunarBarMac
//
//  Created by cyan on 12/21/23.
//

import AppKit
import AppKitControls
import LunarBarKit

/**
 Weekday symbols, showing the shortest representation of each weekday.

 Example: [ 日 一 二 三 四 五 六 ]
 */
final class WeekdayView: NSStackView {
  init() {
    super.init(frame: .zero)
    distribution = .fillEqually
    spacing = 0

    setAccessibilityElement(true)
    setAccessibilityRole(.group)
    setAccessibilityLabel(Localized.UI.accessibilityWeekdayArea)

    reloadSymbols()
  }

  func reloadSymbols() {
    let shortSymbols = Calendar.solar.orderedChineseShortWeekdaySymbols
    let fullSymbols = Calendar.solar.orderedChineseWeekdaySymbols
    let weekendIndices = Calendar.solar.weekendIndices

    Logger.assert(shortSymbols.count == fullSymbols.count, "Invalid weekday symbols")
    Logger.assert(weekendIndices.count == 2, "Invalid weekend indices")

    if arrangedSubviews.count == shortSymbols.count {
      for index in 0..<shortSymbols.count {
        guard let label = arrangedSubviews[index] as? TextLabel else {
          Logger.assertFail("Unexpected weekday view at index: \(index)")
          continue
        }

        applySymbol(
          to: label,
          index: index,
          shortSymbols: shortSymbols,
          fullSymbols: fullSymbols,
          weekendIndices: weekendIndices
        )
      }

      return
    }

    arrangedSubviews.forEach { $0.removeFromSuperview() }

    for index in 0..<shortSymbols.count {
      let label = TextLabel()
      label.alignment = .center
      label.textColor = Colors.primaryLabel
      label.font = .mediumSystemFont(ofSize: Constants.fontSize)
      applySymbol(
        to: label,
        index: index,
        shortSymbols: shortSymbols,
        fullSymbols: fullSymbols,
        weekendIndices: weekendIndices
      )
      addArrangedSubview(label)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Private

private extension WeekdayView {
  enum Constants {
    static let fontSize: Double = FontSizes.regular
  }

  func applySymbol(
    to label: TextLabel,
    index: Int,
    shortSymbols: [String],
    fullSymbols: [String],
    weekendIndices: [Int]
  ) {
    label.stringValue = shortSymbols[index]
    label.alphaValue = weekendIndices.contains(index) ? AlphaLevels.secondary : AlphaLevels.primary
    label.setAccessibilityLabel(fullSymbols[index])
  }
}
