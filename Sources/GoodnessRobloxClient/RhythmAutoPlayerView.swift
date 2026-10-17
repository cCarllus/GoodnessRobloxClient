import GoodnessRobloxClientCore
import SwiftUI

struct RhythmAutoPlayerView: View {
    @ObservedObject var model: RhythmAutoPlayerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                instrumentPicker
                capturePanel
                previewPanel
                settingsPanel
                helpPanel
            }
            .frame(maxWidth: 1060)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .onAppear { model.refreshSources() }
        .onDisappear { model.stop() }
        .onChange(of: model.hueDegrees) { _ in model.applySettings() }
        .onChange(of: model.hueTolerance) { _ in model.applySettings() }
        .onChange(of: model.minimumSaturation) { _ in model.applySettings() }
        .onChange(of: model.leadPixels) { _ in model.applySettings() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rhythm Auto Player")
                .font(.largeTitle.weight(.semibold))
            Text("Reconheça notas na imagem do Roblox e toque as teclas com captura local de tela.")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }

    private var instrumentPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Instrumento", systemImage: "music.note.list")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(RhythmInstrument.allCases) { instrument in
                    Button {
                        model.chooseInstrument(instrument)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: icon(for: instrument))
                                .font(.system(size: 22))
                            Text(instrument.title)
                                .font(.callout.weight(.medium))
                            Text(instrument.defaultLanes.map { String($0.key).uppercased() }.joined(separator: " "))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(
                            model.instrument == instrument
                                ? Color.accentColor.opacity(0.12)
                                : Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    model.instrument == instrument ? Color.accentColor : Color.secondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isRunning || model.isStarting)
                }
            }
        }
    }

    private func icon(for instrument: RhythmInstrument) -> String {
        switch instrument {
        case .drums: return "circle.grid.2x2"
        case .bass: return "guitars"
        case .guitar: return "guitars"
        case .keyboard: return "pianokeys"
        }
    }

    private var capturePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Captura e execução", systemImage: "record.circle")
                    .font(.headline)
                Spacer()
                Text(model.isRunning ? "Capturando" : (model.isStarting ? "Iniciando" : "Parado"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.isRunning ? Color.green : Color.secondary)
            }

            HStack(spacing: 12) {
                Picker("Fonte", selection: $model.selectedSourceID) {
                    if model.captureOptions.isEmpty {
                        Text("Nenhuma fonte encontrada").tag("")
                    }
                    ForEach(model.captureOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
                .disabled(model.isRunning || model.isStarting)
                .frame(maxWidth: .infinity)

                Button {
                    model.refreshSources()
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .disabled(model.isDiscovering || model.isRunning || model.isStarting)
            }

            HStack(spacing: 10) {
                Button {
                    model.start()
                } label: {
                    Label("Iniciar", systemImage: "play.fill")
                        .frame(minWidth: 85)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRunning || model.isStarting || model.selectedSourceID.isEmpty)

                Button(role: .destructive) {
                    model.stop()
                } label: {
                    Label("Parar", systemImage: "stop.fill")
                }
                .disabled(!model.isRunning && !model.isStarting)

                Spacer()

                Text("Notas visíveis: \(model.visibleNotes)")
                    .font(.caption.monospacedDigit())
                Text("Teclas acionadas: \(model.hits)")
                    .font(.caption.monospacedDigit())
            }

            HStack(spacing: 12) {
                Button {
                    model.testKeysAfterDelay()
                } label: {
                    Label("Testar teclas (3s)", systemImage: "keyboard")
                }
                .disabled(model.isTestingKeys)

                Text(model.robloxFocused ? "Roblox em primeiro plano" : "Roblox não está em primeiro plano")
                    .font(.caption)
                    .foregroundStyle(model.robloxFocused ? Color.green : Color.orange)

                Spacer()
                Text("Capturas: \(model.capturedUpdates)")
                    .font(.caption.monospacedDigit())
                Text("Última: \(model.lastKeysPressed)")
                    .font(.caption.monospacedDigit())
            }

            Text(model.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(18)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Visão e calibração", systemImage: "viewfinder")
                    .font(.headline)
                Spacer()
                if model.calibrationIndex == nil {
                    Button {
                        model.autoCalibrate()
                    } label: {
                        Label("Localizar receptores", systemImage: "viewfinder")
                    }
                    .disabled(!model.isRunning || model.isCalibratingAutomatically)

                    Button("Calibrar manualmente") { model.startCalibration() }
                        .disabled(model.previewImage == nil)
                } else {
                    Button("Cancelar calibração") { model.cancelCalibration() }
                }
            }

            Text(model.calibrationInstruction)
                .font(.callout)
                .foregroundStyle(model.calibrationIndex == nil ? Color.secondary : Color.accentColor)

            previewCanvas
                .frame(height: 365)
                .background(.black, in: RoundedRectangle(cornerRadius: 8))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("O aplicativo tenta localizar os círculos coloridos automaticamente. Se não conseguir, use a calibração manual e clique nos centros das teclas X/C/N/M ou F/J, na ordem.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var previewCanvas: some View {
        GeometryReader { geometry in
            let sourceWidth = CGFloat(model.previewImage?.width ?? 16)
            let sourceHeight = CGFloat(model.previewImage?.height ?? 9)
            let scale = min(
                geometry.size.width / max(1, sourceWidth),
                geometry.size.height / max(1, sourceHeight)
            )
            let imageSize = CGSize(width: sourceWidth * scale, height: sourceHeight * scale)

            ZStack(alignment: .topLeading) {
                if let image = model.previewImage {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .frame(width: imageSize.width, height: imageSize.height)
                } else {
                    ZStack {
                        Color.black
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.dashed")
                                .font(.largeTitle)
                            Text("A prévia aparece após iniciar a captura.")
                                .font(.callout)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(width: imageSize.width, height: imageSize.height)
                }

                ForEach(Array(model.lanes.enumerated()), id: \.offset) { index, lane in
                    let markerColor: Color = model.calibrationIndex == index ? .yellow : .cyan
                    ZStack {
                        Circle()
                            .stroke(markerColor, lineWidth: 2.5)
                            .frame(width: 37, height: 37)
                        Text(String(lane.key).uppercased())
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(markerColor)
                    }
                    .position(
                        x: imageSize.width * lane.x,
                        y: imageSize.height * lane.y
                    )
                }

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard model.calibrationIndex != nil else { return }
                                model.calibrate(
                                    x: value.location.x / max(1, imageSize.width),
                                    y: value.location.y / max(1, imageSize.height)
                                )
                            }
                    )
            }
            .frame(width: imageSize.width, height: imageSize.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Detecção e sincronização", systemImage: "slider.horizontal.3")
                .font(.headline)

            Toggle("Localizar receptores automaticamente ao iniciar", isOn: $model.autoCalibrateOnStart)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                settingSlider(
                    "Cor das notas (matiz)",
                    value: $model.hueDegrees,
                    range: 0...360,
                    step: 1,
                    unit: "°"
                )
                settingSlider(
                    "Tolerância da cor",
                    value: $model.hueTolerance,
                    range: 8...70,
                    step: 1,
                    unit: "°"
                )
                settingSlider(
                    "Antecipação do acerto",
                    value: $model.leadPixels,
                    range: 0...55,
                    step: 1,
                    unit: " px"
                )
                settingSlider(
                    "Duração da tecla",
                    value: $model.keyHoldMilliseconds,
                    range: 20...140,
                    step: 5,
                    unit: " ms"
                )
            }

            HStack(spacing: 12) {
                Text("Saturação mínima")
                    .font(.callout)
                Slider(value: $model.minimumSaturation, in: 0.2...0.85, step: 0.05)
                Text("\(Int(model.minimumSaturation * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .padding(18)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func settingSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.callout)
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)")
                    .foregroundStyle(.secondary)
                    .font(.callout.monospacedDigit())
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private var helpPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Permissões e uso", systemImage: "lock.shield")
                .font(.headline)

            Text("1. Autorize Gravação da Tela e Acessibilidade. 2. Escolha a janela Roblox. 3. Inicie e aguarde a localização automática dos receptores (ou calibre manualmente). 4. Use Testar teclas e volte para o Roblox em até 3 segundos. 5. Inicie a música com o Roblox em primeiro plano.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button("Autorizar Acessibilidade") { model.requestKeyboardPermission() }
                Button("Autorizar Gravação da Tela") { model.requestScreenPermission() }
            }
            .controlSize(.small)

            Text("Detecção experimental por cor e movimento. Cores e velocidade variam por jogo; ajuste a matiz e a antecipação. Não há injeção, leitura de memória ou modificação do Roblox.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
