import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct EndCalendarActivity: LiveActivityIntent {
  static var title: LocalizedStringResource = "실시간 활동 종료"
  func perform() async throws -> some IntentResult {
    for activity in Activity<CalendarActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    return .result()
  }
}

@main
struct CalendarLiveActivityBundle: WidgetBundle {
  var body: some Widget { CalendarLiveActivityWidget() }
}

struct CalendarLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: CalendarActivityAttributes.self) { context in
      HStack(spacing: 14) {
        Image(systemName: "calendar.badge.clock")
          .font(.title2).foregroundStyle(.blue)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 5) {
          Text(context.isStale ? "일정 종료" : "진행 중인 일정")
            .font(.caption).foregroundStyle(.secondary)
          Text(context.state.title).font(.headline).lineLimit(2)
          HStack(spacing: 4) {
            Text(context.state.start, style: .time)
            Text("–")
            Text(context.state.end, style: .time)
          }.font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 4)
        VStack(alignment: .trailing, spacing: 5) {
          countdown(context).font(.title3.bold()).monospacedDigit()
          Text(context.isStale ? "완료" : "종료까지").font(.caption2).foregroundStyle(.secondary)
          Button(intent: EndCalendarActivity()) {
            Image(systemName: "xmark.circle.fill").font(.title3)
          }.buttonStyle(.plain).accessibilityLabel("실시간 활동 종료")
        }
      }
      .padding(16)
      .activityBackgroundTint(Color(uiColor: .secondarySystemBackground).opacity(0.88))
      .activitySystemActionForegroundColor(.primary)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("일상 캘린더", systemImage: "calendar.badge.clock")
            .font(.caption).foregroundStyle(.blue)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Button(intent: EndCalendarActivity()) {
            Image(systemName: "xmark.circle.fill")
          }.buttonStyle(.plain).accessibilityLabel("실시간 활동 종료")
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(context.state.title).font(.headline).lineLimit(2)
              Text(context.isStale ? "일정 종료" : "진행 중").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            countdown(context).font(.title2.bold()).monospacedDigit()
          }.padding(.bottom, 8)
        }
      } compactLeading: {
        Image(systemName: "calendar").foregroundStyle(.blue)
      } compactTrailing: {
        countdown(context).monospacedDigit().frame(width: 54)
      } minimal: {
        Image(systemName: context.isStale ? "checkmark.circle.fill" : "calendar.badge.clock")
          .foregroundStyle(.blue)
      }
      .keylineTint(.blue)
    }
  }

  @ViewBuilder
  private func countdown(_ context: ActivityViewContext<CalendarActivityAttributes>) -> some View {
    if context.isStale {
      Text("종료")
    } else {
      Text(timerInterval: context.state.start...context.state.end, countsDown: true)
        .contentTransition(.numericText(countsDown: true))
        .accessibilityLabel("종료까지 남은 시간")
    }
  }
}
