//
//  ContentView.swift
//  Xen Approximations Calc
//
//  Created by Ghifar on 14.06.25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import AudioKit
import AVFoundation
import Foundation

extension UTType {
    static var scl: UTType {
        UTType(importedAs: "public.scl")
    }
}

struct RadialVisualizationView: View {
    let show12TET: Bool
    let showApprox: Bool
    let showOriginal: Bool
    let scalePitches: [Double]
    let approximation: [Double]
    let noteCount: Int
    let size: CGFloat
    let playingOriginal: [Bool]
    let playingApprox: [Bool]

    var body: some View {
        // Consistent margin and spacing
        let margin: CGFloat = 8
        let spacing: CGFloat = 20
        let blueRadius = size / 2 - margin
        let greenRadius = blueRadius - spacing
        let redRadius = greenRadius - spacing
        ZStack {
            // Draw main (largest) circle for 12-TET
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: blueRadius * 2, height: blueRadius * 2)
            // Draw reference circles for approximation and original
            Circle()
                .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(width: greenRadius * 2, height: greenRadius * 2)
            Circle()
                .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(width: redRadius * 2, height: redRadius * 2)

            // 12-TET points and lines (outermost)
            if show12TET {
                let points: [CGPoint] = (0..<12).map { i in
                    let angle = Angle(degrees: Double(i) * 360.0 / 12.0 - 90)
                    let x = cos(angle.radians) * blueRadius + size/2
                    let y = sin(angle.radians) * blueRadius + size/2
                    return CGPoint(x: x, y: y)
                }
                // Lines between points
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                    path.addLine(to: first)
                }
                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                // Lines to center (higher opacity)
                ForEach(0..<points.count, id: \.self) { i in
                    Path { path in
                        path.move(to: CGPoint(x: size/2, y: size/2))
                        path.addLine(to: points[i])
                    }
                    .stroke(Color.blue.opacity(0.7), lineWidth: 1)
                }
                // Dots
                ForEach(0..<points.count, id: \.self) { i in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .position(points[i])
                }
            }

            // Approximation points and lines (middle)
            if showApprox {
                let points: [CGPoint] = approximation.map { cents in
                    let angle = Angle(degrees: (cents / 1200.0) * 360.0 - 90)
                    let x = cos(angle.radians) * greenRadius + size/2
                    let y = sin(angle.radians) * greenRadius + size/2
                    return CGPoint(x: x, y: y)
                }
                // Lines between points
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                    path.addLine(to: first)
                }
                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                // Lines to center (higher opacity)
                ForEach(0..<points.count, id: \.self) { i in
                    Path { path in
                        path.move(to: CGPoint(x: size/2, y: size/2))
                        path.addLine(to: points[i])
                    }
                    .stroke(Color.green.opacity(0.7), lineWidth: 1)
                }
                // Dots with highlight if playing (saturated green glow)
                ForEach(0..<points.count, id: \.self) { i in
                    let isActive = playingApprox.indices.contains(i) && playingApprox[i]
                    Circle()
                        .fill(Color.green)
                        .frame(width: isActive ? 18 : 12, height: isActive ? 18 : 12)
                        .shadow(color: isActive ? Color.green.opacity(0.95) : .clear, radius: isActive ? 12 : 0)
                        .position(points[i])
                }
            }

            // Original scale points and lines (innermost)
            if showOriginal {
                let points: [CGPoint] = scalePitches.map { cents in
                    let angle = Angle(degrees: (cents / 1200.0) * 360.0 - 90)
                    let x = cos(angle.radians) * redRadius + size/2
                    let y = sin(angle.radians) * redRadius + size/2
                    return CGPoint(x: x, y: y)
                }
                // Lines between points
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                    path.addLine(to: first)
                }
                .stroke(Color.red.opacity(0.5), lineWidth: 2)
                // Lines to center (higher opacity)
                ForEach(0..<points.count, id: \.self) { i in
                    Path { path in
                        path.move(to: CGPoint(x: size/2, y: size/2))
                        path.addLine(to: points[i])
                    }
                    .stroke(Color.red.opacity(0.7), lineWidth: 1)
                }
                // Dots with highlight if playing (saturated red glow)
                ForEach(0..<points.count, id: \.self) { i in
                    let isActive = playingOriginal.indices.contains(i) && playingOriginal[i]
                    Circle()
                        .fill(Color.red)
                        .frame(width: isActive ? 16 : 10, height: isActive ? 16 : 10)
                        .shadow(color: isActive ? Color.red.opacity(0.95) : .clear, radius: isActive ? 10 : 0)
                        .position(points[i])
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct ContentView: View {
    // Add formatter as a property
    private let centsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2  // Always show 2 decimal places
        formatter.maximumFractionDigits = 2  // Maximum 2 decimal places
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    @State private var scalePitches: [Double] = []
    @State private var editableScalePitches: [Double] = [] // For user edits
    @State private var originalScalePitches: [Double] = [] // For reset
    @State private var approximation: [Double] = []
    @State private var approximationIndices: [Int] = []
    @State private var errorMessage: String?
    @State private var showingImporter = false
    @State private var importedFileName: String = ""
    @State private var noteCountString: String = "12" // User input for number of notes
    @State private var noteCount: Int = 12 // Actual number of notes used for approximation
    @State private var show12TET = true
    @State private var showApprox = true
    @State private var showOriginal = false
    @State private var visualizationHeight: CGFloat = 260 // Default size for the visualization
    @State private var originalTonePlayers: [TonePlayerWrapper] = []
    @State private var approxTonePlayers: [TonePlayerWrapper] = []
    @State private var playingOriginal: [Bool] = []
    @State private var playingApprox: [Bool] = []
    @State private var isSliderHovered: Bool = false

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Button("Approximate") {
                        if let n = Int(noteCountString), n > 0 {
                            noteCount = n
                            calculateApproximation()
                            // Play a test sound (0.0 cents = 440 Hz) using the first originalTonePlayer if available
                            if !originalTonePlayers.isEmpty {
                                originalTonePlayers[0].player.play(cents: 0.0, id: 0)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    originalTonePlayers[0].player.stop(id: 0)
                                }
                            }
                        } else {
                            errorMessage = "Please enter a valid positive integer for the note number."
                        }
                    }
                    .padding(.top)
                    Spacer()
                }
                HStack {
                    Text("Number of notes to approximate to:")
                    TextField("12", text: $noteCountString)
                        .frame(width: 50)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .onSubmit {
                            if let n = Int(noteCountString), n > 0 {
                                noteCount = n
                            }
                        }
                }
                .padding(.bottom)
                HStack(spacing: 20) {
                    Toggle("Show 12-TET", isOn: $show12TET)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    Toggle("Show Approximation", isOn: $showApprox)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                    Toggle("Show Original", isOn: $showOriginal)
                        .toggleStyle(SwitchToggleStyle(tint: .red))
                }
                .padding(.bottom, 8)
                
                if !scalePitches.isEmpty {
                    RadialVisualizationView(
                        show12TET: show12TET,
                        showApprox: showApprox,
                        showOriginal: showOriginal,
                        scalePitches: scalePitches,
                        approximation: approximation,
                        noteCount: noteCount,
                        size: visualizationHeight,
                        playingOriginal: playingOriginal,
                        playingApprox: playingApprox
                    )
                    .frame(height: visualizationHeight)
                    .padding(.bottom, 0)
                    // Drag handle
                    Rectangle()
                        .fill(isSliderHovered ? Color(white: 0.82).opacity(0.85) : Color(white: 0.7).opacity(0.7))
                        .frame(height: 10)
                        .cornerRadius(5)
                        .padding(.vertical, 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let newHeight = visualizationHeight + value.translation.height
                                    visualizationHeight = min(max(newHeight, 120), 400)
                                }
                        )
                        .onHover { hovering in
                            isSliderHovered = hovering
                        }
                        .overlay(
                            Image(systemName: "line.horizontal.3")
                                .foregroundColor(.gray)
                                .opacity(0.9)
                        )
                        .padding(.bottom, 8)
                }
                Button("Import .scl File") {
                    showingImporter = true
                }
                .fileImporter(
                    isPresented: $showingImporter,
                    allowedContentTypes: [UTType.scl],
                    allowsMultipleSelection: false
                ) { result in
                    do {
                        guard let url = try result.get().first else { return }
                        importedFileName = url.lastPathComponent
                        guard url.startAccessingSecurityScopedResource() else {
                            errorMessage = "Unable to access file: permission denied."
                            return
                        }
                        defer { url.stopAccessingSecurityScopedResource() }

                        try loadSCL(from: url)
                        calculateApproximation()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }

                if let error = errorMessage {
                    Text("Error: \(error)").foregroundColor(.red)
                }

                if !scalePitches.isEmpty {
                    Text("Imported Scale and Approximation:")
                        .font(.headline)
                        .padding(.top)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("Original Scale: \(importedFileName)")
                                .font(.subheadline)
                                .padding(.bottom, 2)
                            // Table Header for Original Scale
                            HStack {
                                Text("Index")
                                    .frame(width: 50, alignment: .leading)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.92))
                                Text("Cents")
                                    .frame(width: 100, alignment: .leading)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.92))
                                Text("Listen")
                                    .frame(width: 50, alignment: .center)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.92))
                                Button(action: {
                                    // Stop all original notes
                                    for i in 0..<originalTonePlayers.count {
                                        originalTonePlayers[i].player.stop(id: i)
                                        playingOriginal[i] = false
                                    }
                                }) {
                                    Image(systemName: "nosign")
                                        .foregroundColor(.red)
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                HStack(spacing: 4) {
                                    Text("Reset")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(white: 0.92))
                                    Button(action: {
                                        editableScalePitches = originalScalePitches
                                    }) {
                                        Image(systemName: "arrow.counterclockwise.circle.fill")
                                            .foregroundColor(Color(white: 0.92))
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .frame(width: 70, alignment: .center)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                            List(0..<editableScalePitches.count, id: \.self) { i in
                                HStack {
                                    Text("\(i):")
                                        .frame(width: 50, alignment: .leading)
                                    TextField("Cents", value: $editableScalePitches[i], formatter: centsFormatter)
                                        .frame(width: 100, alignment: .leading)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    Toggle(isOn: Binding(
                                        get: { playingOriginal[i] },
                                        set: { isOn in
                                            playingOriginal[i] = isOn
                                            if isOn {
                                                originalTonePlayers[i].player.play(cents: editableScalePitches[i], id: i)
                                            } else {
                                                originalTonePlayers[i].player.stop(id: i)
                                            }
                                        }
                                    )) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                    .toggleStyle(.button)
                                    .frame(width: 50, alignment: .center)
                                    Button(action: {
                                        editableScalePitches[i] = originalScalePitches[i]
                                    }) {
                                        Image(systemName: "arrow.counterclockwise")
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .frame(width: 70, alignment: .center)
                                }
                                .padding(.horizontal)
                            }
                            .onChange(of: editableScalePitches) { oldValue, newValue in
                                calculateApproximation()
                            }
                        }

                        Spacer()

                        VStack(alignment: .leading) {
                            Text("\(noteCount)-TET Approximation:")
                                .font(.subheadline)
                                .padding(.bottom, 2)
                            
                            // Table Header for Approximation
                            HStack {
                                Text("n-TET")
                                    .frame(width: 50, alignment: .leading)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.92))
                                Text("Original")
                                    .frame(width: 60, alignment: .leading)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.92))
                                Text("Adjust")
                                    .frame(width: 70, alignment: .leading)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.92))
                                Text("Listen")
                                    .frame(width: 50, alignment: .center)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.92))
                                Button(action: {
                                    // Stop all approx notes
                                    for i in 0..<approxTonePlayers.count {
                                        approxTonePlayers[i].player.stop(id: i)
                                        playingApprox[i] = false
                                    }
                                }) {
                                    Image(systemName: "nosign")
                                        .foregroundColor(.red)
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                Text("Cents")
                                    .frame(width: 100, alignment: .trailing)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.92))
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                            
                            List(0..<approximation.count, id: \.self) { i in
                                HStack {
                                    Text("\(i)")
                                        .frame(width: 50, alignment: .leading)
                                    Text("(\(approximationIndices[i]))")
                                        .frame(width: 60, alignment: .leading)
                                    Stepper(value: Binding(
                                        get: { approximationIndices[i] },
                                        set: { newIndex in
                                            if newIndex >= 0 && newIndex < scalePitches.count {
                                                approximationIndices[i] = newIndex
                                                approximation[i] = editableScalePitches[newIndex]
                                            }
                                        }
                                    ), in: 0...(scalePitches.count - 1)) {
                                        EmptyView()
                                    }
                                    .frame(width: 70, alignment: .leading)
                                    Toggle(isOn: Binding(
                                        get: { playingApprox[i] },
                                        set: { isOn in
                                            playingApprox[i] = isOn
                                            if isOn {
                                                approxTonePlayers[i].player.play(cents: approximation[i], id: i)
                                            } else {
                                                approxTonePlayers[i].player.stop(id: i)
                                            }
                                        }
                                    )) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                    .toggleStyle(.button)
                                    .frame(width: 50, alignment: .center)
                                    if let formattedValue = centsFormatter.string(from: NSNumber(value: approximation[i])) {
                                        Text(formattedValue)
                                            .frame(width: 100, alignment: .trailing)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Button("Export Approximation as .scl") {
                        exportApproximation()
                    }
                    .padding(.top)
                }
            }
        }
        .padding()
    }

    func loadSCL(from url: URL) throws {
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("!") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count >= 2,
              let count = Int(lines[1].trimmingCharacters(in: .whitespaces)) else {
            throw NSError(domain: "Invalid .scl format", code: 1)
        }

        let pitchLines = lines[2..<min(2 + count, lines.count)]
        var parsed: [Double] = []

        for line in pitchLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("/") {
                // ratio, e.g. 3/2
                let components = trimmed.split(separator: "/").compactMap { Double($0) }
                if components.count == 2 && components[1] != 0 {
                    let ratio = components[0] / components[1]
                    parsed.append(1200 * log2(ratio))
                }
            } else if let cents = Double(trimmed) {
                parsed.append(cents)
            }
        }

        var fullScale = [0.0] + parsed.sorted()
        if fullScale.count < 13 {
            fullScale.append(1200.0)
        } else if fullScale.count == 13 {
            fullScale[12] = 1200.0
        }
        scalePitches = fullScale
        editableScalePitches = fullScale // For editing
        originalScalePitches = fullScale // For reset
        // Initialize tone players and playing arrays
        originalTonePlayers = Array(repeating: TonePlayerWrapper(), count: fullScale.count)
        playingOriginal = Array(repeating: false, count: fullScale.count)
    }

    func calculateApproximation() {
        guard noteCount > 0 else { return }
        let tet = (0..<noteCount).map { Double($0) * (1200.0 / Double(noteCount)) }
        approximation = []
        approximationIndices = []
        for target in tet {
            if let (index, closestPitch) = editableScalePitches.enumerated().min(by: { abs($0.element - target) < abs($1.element - target) }) {
                approximation.append(closestPitch)
                approximationIndices.append(index)
            } else {
                approximation.append(target)
                approximationIndices.append(-1)
            }
        }
        // Initialize approximation tone players and playing array
        approxTonePlayers = Array(repeating: TonePlayerWrapper(), count: approximation.count)
        playingApprox = Array(repeating: false, count: approximation.count)
    }
    
    func exportApproximation() {
        // Compose the .scl content string
        var lines = [String]()
        lines.append("! Generated by Xen Approximations Calc")
        lines.append("!")
        lines.append("\(noteCount)-TET Approximation of \(importedFileName)")
        lines.append("\(noteCount)") // number of notes

        // Write all approximated notes, skipping any that are 0 or very close to 0
        for cents in approximation {
            if abs(cents) < 0.0001 { continue }
            lines.append(String(format: "%.6f", cents))
        }

        // Add the octave at 1200.0 cents (with one decimal place)
        lines.append("1200.0")

        let sclContent = lines.joined(separator: "\n")

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.scl]
        let defaultExportName = "\(noteCount)-TET approximation of " + (importedFileName.isEmpty ? "scale" : importedFileName)
        panel.nameFieldStringValue = defaultExportName.replacingOccurrences(of: ".scl", with: "") + ".scl"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try sclContent.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                errorMessage = "Failed to save file: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
}
