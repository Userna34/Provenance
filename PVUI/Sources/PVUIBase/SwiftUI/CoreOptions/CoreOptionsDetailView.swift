import SwiftUI
import PVCoreBridge
import PVLibrary

/// View that displays and allows editing of core options for a specific core
struct CoreOptionsDetailView: View {
    let coreClass: CoreOptional.Type
    let title: String

    /// State to track current values of options
    @State private var optionValues: [String: Any] = [:]

    private struct IdentifiableOption: Identifiable {
        let id = UUID()
        let option: CoreOption
    }

    private struct OptionGroup: Identifiable {
        let id = UUID()
        let title: String
        let options: [IdentifiableOption]

        init(title: String, options: [CoreOption]) {
            self.title = title
            self.options = options.map { IdentifiableOption(option: $0) }
        }
    }

    private var groupedOptions: [OptionGroup] {
        var rootOptions = [CoreOption]()
        var groups = [OptionGroup]()

        // Process options into groups
        coreClass.options.forEach { option in
            switch option {
            case let .group(display, subOptions):
                groups.append(OptionGroup(title: display.title, options: subOptions))
            default:
                rootOptions.append(option)
            }
        }

        // Add root options as first group if any exist
        if !rootOptions.isEmpty {
            groups.insert(OptionGroup(title: "General", options: rootOptions), at: 0)
        }

        return groups
    }

    var body: some View {
        Form {
            ForEach(groupedOptions) { group in
                SwiftUI.Section {
                    ForEach(group.options) { identifiableOption in
                        optionView(for: identifiableOption.option)
                    }
                } header: {
                    Text(group.title)
                }
            }
        }
        .navigationTitle(title)
        .onAppear {
            // Load initial values
            loadOptionValues()
        }
    }

    private func loadOptionValues() {
        for group in groupedOptions {
            for identifiableOption in group.options {
                let value = getCurrentValue(for: identifiableOption.option)
                if let value = value {
                    optionValues[identifiableOption.option.key] = value
                }
            }
        }
    }

    private func getCurrentValue(for option: CoreOption) -> Any? {
        switch option {
        case .bool(_, let defaultValue):
            return coreClass.storedValueForOption(Bool.self, option.key) ?? defaultValue
        case .string(_, let defaultValue):
            return coreClass.storedValueForOption(String.self, option.key) ?? defaultValue
        case .enumeration(_, _, let defaultValue):
            return coreClass.storedValueForOption(Int.self, option.key) ?? defaultValue
        case .range(_, _, let defaultValue):
            return coreClass.storedValueForOption(Int.self, option.key) ?? defaultValue
        case .rangef(_, _, let defaultValue):
            return coreClass.storedValueForOption(Float.self, option.key) ?? defaultValue
        case .multi(_, let values):
            return coreClass.storedValueForOption(String.self, option.key) ?? values.first?.title
        case .group(_, _):
            return nil
        @unknown default:
            return nil
        }
    }

    private func setValue(_ value: Any, for option: CoreOption) {
        optionValues[option.key] = value

        switch value {
        case let boolValue as Bool:
            coreClass.setValue(boolValue, forOption: option)
        case let stringValue as String:
            coreClass.setValue(stringValue, forOption: option)
        case let intValue as Int:
            coreClass.setValue(intValue, forOption: option)
        case let floatValue as Float:
            coreClass.setValue(floatValue, forOption: option)
        default:
            break
        }
    }

    @ViewBuilder
    private func optionView(for option: CoreOption) -> some View {
        switch option {
        case let .bool(display, defaultValue):
            Toggle(isOn: Binding(
                get: { optionValues[option.key] as? Bool ?? defaultValue },
                set: { setValue($0, for: option) }
            )) {
                VStack(alignment: .leading) {
                    Text(display.title)
                    if let description = display.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

        case let .enumeration(display, values, defaultValue):
            let selection = Binding(
                get: { optionValues[option.key] as? Int ?? defaultValue },
                set: { setValue($0, for: option) }
            )

            NavigationLink {
                List {
                    ForEach(values, id: \.value) { value in
                        Button {
                            selection.wrappedValue = value.value
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(value.title)
                                    if let description = value.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if value.value == selection.wrappedValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .navigationTitle(display.title)
            } label: {
                VStack(alignment: .leading) {
                    Text(display.title)
                    if let description = display.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(values.first { $0.value == selection.wrappedValue }?.title ?? "")
                        .foregroundColor(.secondary)
                }
            }

        case let .range(display, range, defaultValue):
            VStack(alignment: .leading) {
                Text(display.title)
                if let description = display.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
#if !os(tvOS)
                Slider(
                    value: Binding(
                        get: { Double(optionValues[option.key] as? Int ?? defaultValue) },
                        set: { setValue(Int($0), for: option) }
                    ),
                    in: Double(range.min)...Double(range.max),
                    step: 1
                ) {
                    Text(display.title)
                } minimumValueLabel: {
                    Text("\(range.min)")
                } maximumValueLabel: {
                    Text("\(range.max)")
                }
#endif
            }

        case let .rangef(display, range, defaultValue):
            VStack(alignment: .leading) {
                Text(display.title)
                if let description = display.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
#if !os(tvOS)
                Slider(
                    value: Binding(
                        get: { Double(optionValues[option.key] as? Float ?? defaultValue) },
                        set: { setValue(Float($0), for: option) }
                    ),
                    in: Double(range.min)...Double(range.max),
                    step: 0.1
                ) {
                    Text(display.title)
                } minimumValueLabel: {
                    Text(String(format: "%.1f", range.min))
                } maximumValueLabel: {
                    Text(String(format: "%.1f", range.max))
                }
#endif
            }

        case let .multi(display, values):
            let selection = Binding(
                get: { optionValues[option.key] as? String ?? values.first?.title ?? "" },
                set: { setValue($0, for: option) }
            )

            NavigationLink {
                List {
                    ForEach(values, id: \.title) { value in
                        Button {
                            selection.wrappedValue = value.title
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(value.title)
                                    if let description = value.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if value.title == selection.wrappedValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                .navigationTitle(display.title)
            } label: {
                VStack(alignment: .leading) {
                    Text(display.title)
                    if let description = display.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(selection.wrappedValue)
                        .foregroundColor(.secondary)
                }
            }

        case let .string(display, defaultValue):
            let text = Binding(
                get: { optionValues[option.key] as? String ?? defaultValue },
                set: { setValue($0, for: option) }
            )

            VStack(alignment: .leading) {
                Text(display.title)
                if let description = display.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                TextField("Value", text: text)
#if !os(tvOS)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
#endif
            }

        case .group(_, _):
            EmptyView() // Groups are handled at the section level
        }
    }
}
