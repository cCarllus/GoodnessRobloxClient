import SwiftUI
import GoodnessRobloxClientCore

struct ContentView: View {
    @StateObject private var player = PlayerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            HStack(spacing: 0) {
                sidebar
                Divider()
                pianoSheetsScreen
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            player.refreshPermissionStatus()
            player.parseSheet()
        }
        .onChange(of: player.sheetText) { _ in player.parseSheet() }
        .onChange(of: player.whitespaceCreatesRests) { _ in player.parseSheet() }
        .onChange(of: player.newlineRestUnits) { _ in player.parseSheet() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.keyboard")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Goodness Roblox Client")
                    .font(.title2.weight(.semibold))
                Text("Client local para automacao de Piano Sheets no macOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            permissionBadge
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CLIENT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Label("Piano Sheets", systemImage: "pianokeys")
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            Label("Local Input", systemImage: "keyboard")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            Spacer()

            Text("Sem injecao, leitura de memoria ou bypass. Apenas eventos locais de teclado autorizados pelo macOS.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var permissionBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(player.permissionGranted ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
            Text(player.permissionGranted ? "Acessibilidade ativa" : "Permissao necessaria")
                .font(.callout.weight(.medium))
            if !player.permissionGranted {
                Button("Autorizar") {
                    player.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var pianoSheetsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                screenHeader
                centralPlayer
                editorPanel
                settingsPanel
                preview
            }
            .frame(maxWidth: 1060)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private var screenHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Piano Sheets")
                    .font(.largeTitle.weight(.semibold))
                Text("Cole a sheet, ajuste o tempo e toque no Roblox Piano usando entrada local do macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(player.parsedEvents.count)")
                    .font(.title2.monospacedDigit().weight(.semibold))
                Text("eventos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var centralPlayer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Piano Sheet Controller", systemImage: "play.circle")
                    .font(.headline)
                Spacer()
                Text(player.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView(value: player.progressValue)

            HStack(spacing: 10) {
                Button {
                    player.play()
                } label: {
                    Label(player.isPaused ? "Continuar" : "Tocar", systemImage: "play.fill")
                        .frame(minWidth: 104)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])

                Button {
                    player.pause()
                } label: {
                    Label("Pausar", systemImage: "pause.fill")
                        .frame(minWidth: 96)
                }
                .disabled(!player.isPlaying || player.isPaused)

                Button(role: .destructive) {
                    player.stop()
                } label: {
                    Label("Parar", systemImage: "stop.fill")
                        .frame(minWidth: 86)
                }
                .disabled(!player.isPlaying && !player.isPaused)

                Spacer()

                metric(title: "Notas", value: "\(player.supportedEventCount)")
                metric(title: "Passo", value: "\(Int(player.tempoMilliseconds)) ms")
                metric(title: "Delay", value: "\(Int(player.startDelaySeconds)) s")
            }
            .controlSize(.large)
        }
        .padding(18)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        )
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 68, alignment: .trailing)
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Sheet Input", systemImage: "text.alignleft")
                    .font(.headline)
                Spacer()
                Text("\(player.supportedEventCount) notas/acordes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $player.sheetText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 260)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                )

            Text("Use colchetes para acordes, por exemplo [6psu]. Caracteres fora dos colchetes viram teclas individuais.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ajustes", systemImage: "slider.horizontal.3")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Tempo por passo")
                        Spacer()
                        Text("\(Int(player.tempoMilliseconds)) ms")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $player.tempoMilliseconds, in: 40...600, step: 5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Duracao da tecla")
                        Spacer()
                        Text("\(Int(player.holdPercentage))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $player.holdPercentage, in: 10...90, step: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Atraso inicial")
                        Spacer()
                        Text("\(Int(player.startDelaySeconds)) s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $player.startDelaySeconds, in: 0...15, step: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Pausa por quebra de linha")
                        Spacer()
                        Text("\(Int(player.newlineRestUnits)) passos")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $player.newlineRestUnits, in: 1...8, step: 1)
                        .disabled(!player.whitespaceCreatesRests)
                }
            }

            Toggle("Espacos e quebras de linha criam pausas", isOn: $player.whitespaceCreatesRests)
        }
        .padding(18)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        )
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Previa parseada", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Text("\(player.parsedEvents.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(player.parsedEvents.prefix(160).enumerated()), id: \.element.id) { index, event in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .trailing)

                            Text(event.displayName)
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(index + 1 == player.currentEventIndex ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(minHeight: 150)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            )
        }
    }
}
