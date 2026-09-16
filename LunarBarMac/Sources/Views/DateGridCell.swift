//
//  DateGridCell.swift
//  LunarBarMac
//
//  Created by cyan on 12/22/23.
//

import AppKit
import AppKitControls
import EventKit
import LunarBarKit

/**
 Grid cell that draws a day, including its solar date and lunar date and decorating views.

 Example: 22 初十
 */
final class DateGridCell: NSCollectionViewItem {
  static let reuseIdentifier = NSUserInterfaceItemIdentifier("DateGridCell")

  private var cellDate: Date?
  private var cellEvents = [EKCalendarItem]()
  private var mainInfo = ""

  private var detailsTask: Task<Void, Never>?
  private weak var detailsPopover: NSPopover?

  private let containerView: CustomButton = {
    let button = CustomButton()
    button.setAccessibilityElement(true)
    button.setAccessibilityRole(.button)
    button.setAccessibilityHelp(Localized.UI.accessibilityClickToRevealDate)

    return button
  }()

  private let highlightView: NSView = {
    let view = NSView()
    view.wantsLayer = true
    view.alphaValue = 0

    view.layer?.cornerRadius = AppDesign.cellCornerRadius
    view.layer?.cornerCurve = .continuous

    return view
  }()

  private let solarLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .mediumSystemFont(ofSize: Constants.solarFontSize)
    label.setAccessibilityHidden(true)

    return label
  }()

  private let lunarLabel: TextLabel = {
    let label = TextLabel()
    label.textColor = Colors.primaryLabel
    label.font = .mediumSystemFont(ofSize: Constants.lunarFontSize)
    label.setAccessibilityHidden(true)

    return label
  }()

  private let eventView: EventView = {
    let view = EventView()
    view.setAccessibilityHidden(true)

    return view
  }()

  private let todayCircleView: NSView = {
    let view = NSView()
    view.wantsLayer = true
    view.isHidden = true
    view.setAccessibilityHidden(true)

    view.layer?.masksToBounds = true

    return view
  }()

  private let holidayView: TextLabel = {
    let label = TextLabel()
    label.font = .mediumSystemFont(ofSize: Constants.holidayFontSize)
    label.setAccessibilityHidden(true)
    label.isHidden = true

    return label
  }()
}

// MARK: - Life Cycle

extension DateGridCell {
  override func loadView() {
    // Required prior to macOS Sonoma
    view = NSView(frame: .zero)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setUp()
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    containerView.frame = view.bounds

    highlightView.layerBackgroundColor = .highlightedBackground
    todayCircleView.layerBackgroundColor = Colors.systemRed
    todayCircleView.layer?.cornerRadius = todayCircleView.bounds.width * 0.5
  }
}

// MARK: - Updating

extension DateGridCell {
  func updateViews(
    cellDate: Date,
    cellEvents: [EKCalendarItem],
    monthDate: Date?,
    lunarInfo: LunarInfo?
  ) {
    self.cellDate = cellDate
    self.cellEvents = cellEvents

    let currentDate = Date.now
    let solarComponents = Calendar.solar.dateComponents([.year, .month, .day], from: cellDate)
    let lunarComponents = Calendar.lunar.dateComponents([.year, .month, .day], from: cellDate)
    let isLastDayOfYear = Calendar.lunar.isLastDayOfYear(from: cellDate)
    let isLeapLunarMonth = Calendar.lunar.isLeapMonth(from: cellDate)

    let solarMonthDay = solarComponents.fourDigitsMonthDay
    let lunarMonthDay = lunarComponents.fourDigitsMonthDay

    let holidayType = HolidayManager.default.typeOf(
      year: solarComponents.year ?? 0, // It's too broken to have year as nil
      monthDay: solarMonthDay
    )

    // Solar day label
    if let day = solarComponents.day {
      solarLabel.stringValue = String(day)
    } else {
      Logger.assertFail("Failed to get solar day from date: \(cellDate)")
    }

    // Lunar day label
    if let day = lunarComponents.day {
      if day == 1, let month = lunarComponents.month {
        // The Chinese character "月" will shift the layout slightly to the left,
        // add a "thin space" to make it optically centered.
        lunarLabel.stringValue = "\u{2009}" + AppLocalizer.chineseMonth(of: month - 1, isLeap: isLeapLunarMonth)
      } else {
        lunarLabel.stringValue = AppLocalizer.chineseDay(of: day - 1)
      }
    } else {
      Logger.assertFail("Failed to get lunar day from date: \(cellDate)")
    }

    // Prefer solar term over normal lunar day
    if let solarTerm = lunarInfo?.solarTerms[solarMonthDay] {
      lunarLabel.stringValue = AppLocalizer.solarTerm(of: solarTerm)
    }

    // Prefer lunar holiday over solar term
    if let lunarHoliday = AppLocalizer.lunarFestival(of: lunarMonthDay) {
      lunarLabel.stringValue = lunarHoliday
    }

    // Chinese New Year's Eve, the last day of the lunar year, not necessarily a certain date
    if isLastDayOfYear {
      lunarLabel.stringValue = Localized.Calendar.chineseNewYearsEve
    }

    // Filled red circle for today
    let isDateToday = Calendar.solar.isDate(cellDate, inSameDayAs: currentDate)
    todayCircleView.isHidden = !isDateToday
    solarLabel.textColor = isDateToday ? Colors.todayLabel : Colors.primaryLabel
    lunarLabel.textColor = isDateToday ? Colors.todayLabel : Colors.primaryLabel

    // Reload event dot views
    eventView.updateEvents(cellEvents)

    // Compact workday / holiday badge
    if let badge = AppLocalizer.holidayBadge(of: holidayType) {
      holidayView.isHidden = false
      holidayView.stringValue = badge
      holidayView.textColor = holidayType == .workday ? Colors.systemOrange : Colors.systemBlue
    } else {
      holidayView.isHidden = true
      holidayView.stringValue = ""
    }

    self.mainInfo = {
      var components: [String] = []
      // E.g. [Holiday]
      if let holidayLabel = AppLocalizer.holidayLabel(of: holidayType) {
        components.append(holidayLabel)
      }

      // Formatted lunar date, e.g., 癸卯年冬月十五 (leading numbers are removed to be concise)
      let lunarDate = Constants.lunarDateFormatter.string(from: cellDate)
      components.append(lunarDate.removingLeadingDigits)

      // Date ruler, e.g., "(10 days ago)" when hovering over a cell
      if let daysBetween = Calendar.solar.daysBetween(from: currentDate, to: cellDate) {
        if daysBetween == 0 {
          components.append(Localized.Calendar.todayLabel)
        } else {
          let format = daysBetween > 0 ? Localized.Calendar.daysLaterFormat : Localized.Calendar.daysAgoFormat
          components.append(String.localizedStringWithFormat(format, abs(daysBetween)))
        }
      }

      return components.joined()
    }()

    let accessibleDetails = {
      let eventTitles = cellEvents.compactMap { $0.title }

      // Only the main info
      if eventTitles.isEmpty {
        return mainInfo
      }

      // Full version, each trailing line is an event title
      return [mainInfo, eventTitles.joined(separator: "\n")].joined(separator: "\n\n")
    }()

    // Combine all visually available information to get the accessibility label
    containerView.setAccessibilityLabel([
      solarLabel.stringValue,
      lunarLabel.stringValue,
      accessibleDetails,
    ].compactMap { $0 }.joined(separator: " "))
  }

  func updateOpacity(monthDate: Date?) {
    let currentDate = Date.now
    let cellDate = cellDate ?? currentDate

    let solarComponents = Calendar.solar.dateComponents([.month], from: cellDate)
    let isDateToday = Calendar.solar.isDate(cellDate, inSameDayAs: currentDate)

    if let monthDate, Calendar.solar.month(from: monthDate) == solarComponents.month {
      if Calendar.solar.isDateInWeekend(cellDate) && !isDateToday {
        solarLabel.alphaValue = AlphaLevels.secondary
      } else {
        solarLabel.alphaValue = AlphaLevels.primary
      }

      // Intentional, secondary alpha is used only for labels at weekends
      eventView.alphaValue = AlphaLevels.primary
    } else {
      solarLabel.alphaValue = AlphaLevels.tertiary
      eventView.alphaValue = AlphaLevels.tertiary
    }

    lunarLabel.alphaValue = solarLabel.alphaValue
    holidayView.alphaValue = eventView.alphaValue
  }

  @discardableResult
  func cancelHighlight() -> Bool {
    highlightView.alphaValue = 0
    return dismissDetails()
  }
}

// MARK: - Private

private extension DateGridCell {
  enum Constants {
    static let solarFontSize: Double = FontSizes.regular
    static let lunarFontSize: Double = FontSizes.small
    static let holidayFontSize: Double = 8
    static let eventViewHeight: Double = 10
    static let todayCirclePadding: Double = 5
    static let lunarDateFormatter: DateFormatter = .lunarDate
  }

  func setUp() {
    view.addSubview(containerView)
    view.clipsToBounds = false
    containerView.clipsToBounds = false
    containerView.addAction { [weak self] in
      self?.revealDateInCalendar()
    }

    containerView.onMouseHover = { [weak self] isHovered in
      self?.onMouseHover(isHovered)
    }

    highlightView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(highlightView)

    todayCircleView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(todayCircleView)

    solarLabel.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(solarLabel)
    NSLayoutConstraint.activate([
      solarLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      solarLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: AppDesign.cellRectInset),
    ])

    lunarLabel.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(lunarLabel)
    NSLayoutConstraint.activate([
      lunarLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      lunarLabel.topAnchor.constraint(equalTo: solarLabel.bottomAnchor),
    ])

    eventView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(eventView)
    NSLayoutConstraint.activate([
      eventView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      eventView.topAnchor.constraint(equalTo: lunarLabel.bottomAnchor),
      eventView.heightAnchor.constraint(equalToConstant: Constants.eventViewHeight),
    ])

    let dateLabelsGuide = NSLayoutGuide()
    containerView.addLayoutGuide(dateLabelsGuide)
    NSLayoutConstraint.activate([
      dateLabelsGuide.topAnchor.constraint(equalTo: solarLabel.topAnchor),
      dateLabelsGuide.bottomAnchor.constraint(equalTo: lunarLabel.bottomAnchor),
      dateLabelsGuide.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      dateLabelsGuide.widthAnchor.constraint(equalToConstant: 1),

      highlightView.topAnchor.constraint(equalTo: containerView.topAnchor),
      highlightView.bottomAnchor.constraint(equalTo: eventView.bottomAnchor, constant: AppDesign.cellRectInset),
      highlightView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

      // Here we need to make sure the highlight view is wider than both labels
      highlightView.widthAnchor.constraint(
        greaterThanOrEqualTo: solarLabel.widthAnchor,
        constant: AppDesign.cellRectInset * 2
      ),
      highlightView.widthAnchor.constraint(
        greaterThanOrEqualTo: lunarLabel.widthAnchor,
        constant: AppDesign.cellRectInset * 2
      ),

      todayCircleView.centerXAnchor.constraint(equalTo: dateLabelsGuide.centerXAnchor),
      todayCircleView.centerYAnchor.constraint(equalTo: dateLabelsGuide.centerYAnchor),
      todayCircleView.widthAnchor.constraint(equalTo: todayCircleView.heightAnchor),
      todayCircleView.heightAnchor.constraint(
        greaterThanOrEqualTo: dateLabelsGuide.heightAnchor,
        constant: Constants.todayCirclePadding * 2
      ),
      todayCircleView.widthAnchor.constraint(
        greaterThanOrEqualTo: solarLabel.widthAnchor,
        constant: Constants.todayCirclePadding * 2
      ),
      todayCircleView.widthAnchor.constraint(
        greaterThanOrEqualTo: lunarLabel.widthAnchor,
        constant: Constants.todayCirclePadding * 2
      ),
    ])

    holidayView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(holidayView)
    NSLayoutConstraint.activate([
      holidayView.bottomAnchor.constraint(equalTo: solarLabel.centerYAnchor, constant: 1),
      holidayView.leadingAnchor.constraint(equalTo: solarLabel.trailingAnchor, constant: -1),
    ])

    let longPressRecognizer = NSPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
    longPressRecognizer.minimumPressDuration = 0.5
    view.addGestureRecognizer(longPressRecognizer)
  }

  func revealDateInCalendar() {
    guard let cellDate else {
      return Logger.assertFail("Missing cellDate to continue")
    }

    dismissDetails()
    (NSApp.delegate as? AppDelegate)?.openCalendar(targetDate: cellDate)
  }

  @objc func onLongPress(_ recognizer: NSPressGestureRecognizer) {
    guard recognizer.state == .began, let cellDate else {
      return
    }

    NSHapticFeedbackManager.defaultPerformer.perform(
      .generic,
      performanceTime: .now
    )

    dismissDetails()
    (NSApp.delegate as? AppDelegate)?.countDaysBetween(targetDate: cellDate)
  }

  func onMouseHover(_ isHovered: Bool) {
    highlightView.setAlphaValue(isHovered ? 1 : 0)
    dismissDetails()

    guard isHovered else {
      return
    }

    let showDetails = {
      try await Task.sleep(for: .seconds(0.5))
      let popover = DateDetailsView.createPopover(
        title: self.mainInfo,
        events: self.cellEvents,
        lineWidth: self.view.hairlineWidth
      )

      popover.show(
        relativeTo: self.containerView.bounds,
        of: self.containerView,
        preferredEdge: .maxY
      )

      if !AppPreferences.Accessibility.reduceMotion {
        popover.window?.fadeIn()
      }

      self.detailsPopover = popover
    }

    detailsTask = Task {
      try? await showDetails()
    }
  }

  @discardableResult
  func dismissDetails() -> Bool {
    let wasOpen = detailsPopover?.isShown == true
    detailsTask?.cancel()

    let closeDetails: @Sendable () -> Void = {
      Task { @MainActor in
        self.detailsPopover?.close()
        self.detailsPopover = nil
      }
    }

    if !AppPreferences.Accessibility.reduceMotion, let window = detailsPopover?.window {
      window.fadeOut(completion: closeDetails)
    } else {
      closeDetails()
    }

    return wasOpen
  }
}
