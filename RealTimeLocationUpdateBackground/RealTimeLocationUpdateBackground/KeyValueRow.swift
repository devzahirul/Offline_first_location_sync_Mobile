import SwiftUI

struct KeyValueRow<Value: View>: View {
    let title: String
    @ViewBuilder let value: Value

    init(_ title: String, @ViewBuilder value: () -> Value) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            value
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

