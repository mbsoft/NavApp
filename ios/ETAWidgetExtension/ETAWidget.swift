import WidgetKit
import SwiftUI
import ActivityKit

struct ETAAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var eta: String
        var instruction: String
        var remainingDistance: String
        var progressPercentage: Int
        var isNavigating: Bool
    }
    var destination: String
    var routeType: String
}

struct ETAWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ETAAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Navigation")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(context.attributes.routeType.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(context.state.instruction)
                    .font(.subheadline)
                    .lineLimit(2)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("ETA")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.state.eta)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Remaining")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.state.remainingDistance)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
        } dynamicIsland: { context in
            // Dynamic Island UI goes here
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("ETA")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.state.eta)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Remaining")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.state.remainingDistance)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.instruction)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } compactLeading: {
                VStack(alignment: .leading, spacing: 1) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.caption2)
                    Text(context.state.remainingDistance)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.leading, 4)
                }
                .padding(.leading, 8)
            } compactTrailing: {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("ETA: \(context.state.eta)")
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text("\(context.state.progressPercentage)%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 8)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct ETAWidget_Previews: PreviewProvider {
    static let attributes = ETAAttributes(destination: "Times Square", routeType: "car")
    static let contentState = ETAAttributes.ContentState(
        eta: "14:30",
        instruction: "Turn right onto 42nd Street",
        remainingDistance: "2.3 mi",
        progressPercentage: 25,
        isNavigating: true
    )
    
    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact")
        
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded")
        
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Lock Screen")
    }
}
