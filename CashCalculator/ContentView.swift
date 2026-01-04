//
//  ContentView.swift
//  CashCalculator
//
//  Created by Amir Beheshtian on 2026-01-03.
//

import SwiftUI
import Combine

struct Denomination: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Decimal
}

final class CashCalculatorViewModel: ObservableObject {
    @Published var quantities: [Denomination: Int] = [:]
    let denominations: [Denomination]
    @Published var floatAmount: Decimal = 300

    init() {
        self.denominations = [
            Denomination(label: "$100", value: 100),
            Denomination(label: "$50", value: 50),
            Denomination(label: "$20", value: 20),
            Denomination(label: "$10", value: 10),
            Denomination(label: "$5", value: 5),
            Denomination(label: "$2", value: 2),
            Denomination(label: "$1", value: 1),
            Denomination(label: "$0.25", value: 0.25),
            Denomination(label: "$0.10", value: 0.10),
            Denomination(label: "$0.05", value: 0.05)
        ]
        // Initialize quantities to zero
        for d in denominations {
            quantities[d] = 0
        }
    }

    func totalFor(_ denomination: Denomination) -> Decimal {
        let qty = Decimal(quantities[denomination] ?? 0)
        return qty * denomination.value
    }

    var grandTotal: Decimal {
        denominations.reduce(0) { partial, d in
            partial + totalFor(d)
        }
    }
    
    var bankAmount: Decimal {
        let result = grandTotal - floatAmount
        return result > 0 ? result : 0
    }
    
    func resetAll() {
        for d in denominations {
            quantities[d] = 0
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = CashCalculatorViewModel()
    @FocusState private var focusedDenomination: Denomination?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                ScrollViewReader { proxy in
                    List {
                        Section("Bills") {
                            ForEach(viewModel.denominations.filter { $0.value >= 5 }) { denom in
                                row(for: denom)
                                    .id(denom.id)
                            }
                        }
                        Section("Coins") {
                            ForEach(viewModel.denominations.filter { $0.value < 5 }) { denom in
                                row(for: denom)
                                    .id(denom.id)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: focusedDenomination) { _, newValue in
                        if let target = newValue {
                            withAnimation {
                                proxy.scrollTo(target.id, anchor: .center)
                            }
                        }
                    }
                }

                Divider()
                footer
            }
            .navigationTitle("Cash Calculator")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        viewModel.resetAll()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Done") {
                        focusedDenomination = nil
                    }
                    Spacer()
                    Button("Next") {
                        let order = viewModel.denominations
                        if let current = focusedDenomination,
                           let idx = order.firstIndex(of: current) {
                            let nextIndex = order.index(after: idx)
                            if nextIndex < order.endIndex {
                                focusedDenomination = order[nextIndex]
                            } else {
                                // Last field: dismiss
                                focusedDenomination = nil
                            }
                        } else {
                            // If nothing is focused, start at the first
                            focusedDenomination = order.first
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Denomination").font(.headline)
            Spacer()
            Text("Qty").font(.headline).frame(width: 70, alignment: .trailing)
            Text("Total").font(.headline).frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private func row(for denom: Denomination) -> some View {
        HStack {
            Text(denom.label)
            Spacer()
            TextField("", text: Binding(
                get: {
                    let current = viewModel.quantities[denom] ?? 0
                    return current == 0 ? "" : String(current)
                },
                set: { newValue in
                    // Allow empty to represent zero, and filter to digits only
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.isEmpty {
                        viewModel.quantities[denom] = 0
                    } else {
                        viewModel.quantities[denom] = Int(filtered) ?? 0
                    }
                }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(width: 84)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
            )
            .focused($focusedDenomination, equals: denom)

            Text(currencyString(viewModel.totalFor(denom)))
                .frame(width: 100, alignment: .trailing)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            // Row with Float editor
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Float").font(.caption).foregroundStyle(.secondary)
                    floatEditor
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                summaryCard(title: "Grand Total", amount: viewModel.grandTotal)
                summaryCard(title: "Goes to Bank", amount: viewModel.bankAmount, color: .orange)
            }
            .padding(.top, 8)
        }
        .padding([.horizontal, .bottom])
    }

    private var floatEditor: some View {
        let binding = Binding<String>(
            get: {
                // Show empty when 0, otherwise show integer-like or formatted plain number
                let number = NSDecimalNumber(decimal: viewModel.floatAmount)
                if number == 0 { return "" }
                return number.stringValue
            },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                if filtered.isEmpty {
                    viewModel.floatAmount = 0
                } else if let intVal = Int(filtered) {
                    viewModel.floatAmount = Decimal(intVal)
                }
            }
        )

        return TextField("0", text: binding)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(minWidth: 120)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func summaryCard(title: String, amount: Decimal, color: Color = .accentColor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currencyString(amount))
                .font(.headline)
                .bold()
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.35), lineWidth: 1)
        )
    }

    private func currencyString(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: number) ?? "$0.00"
    }
}

#Preview {
    ContentView()
}

