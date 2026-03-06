import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield

/**
 * Campo Notes — Plugin QField
 *
 * Adiciona um botão à toolbar do QField para registar notas rápidas
 * com data/hora e coordenadas GPS atuais.
 *
 * Instalação:
 *   1. Compacte os ficheiros em campo-notes.zip
 *   2. Copie para a pasta 'plugins' do diretório QField
 *   3. Ative nas definições > Plugins
 */
Item {
    id: root

    // ─── Lista de notas guardadas em memória ────────────────────────────────
    property var notas: []

    // ─── Botão na toolbar principal ─────────────────────────────────────────
    Component.onCompleted: {
        iface.addItemToPluginsToolbar(toolbarButton)
        iface.mainWindow().displayToast("📋 Campo Notes ativado!")
    }

    // Botão na toolbar
    QfToolButton {
        id: toolbarButton
        iconSource: Qt.resolvedUrl("icon.svg")
        iconColor: "transparent"
        bgcolor: Qt.rgba(0, 0, 0, 0)
        round: true
        onClicked: notasDialog.open()
    }

    // ─── Diálogo principal ──────────────────────────────────────────────────
    Dialog {
        id: notasDialog
        parent: iface.mainWindow().contentItem
        anchors.centerIn: parent

        width: Math.min(parent.width * 0.92, 480)
        height: Math.min(parent.height * 0.88, 620)

        modal: true
        title: "📋 Campo Notes"
        standardButtons: Dialog.Close

        background: Rectangle {
            color: "#FAFAFA"
            radius: 12
            border.color: "#E0E0E0"
            border.width: 1
        }

        header: Rectangle {
            color: "#2E7D32"
            radius: 12
            height: 56
            // Arredondar apenas cantos superiores
            Rectangle {
                color: parent.color
                height: parent.radius
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            }
            Label {
                anchors.centerIn: parent
                text: "📋 Campo Notes"
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── Área de nova nota ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 160
                color: "white"
                radius: 8
                border.color: textoNota.activeFocus ? "#2E7D32" : "#E0E0E0"
                border.width: textoNota.activeFocus ? 2 : 1

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4

                    TextArea {
                        id: textoNota
                        placeholderText: "Escreva a sua nota aqui...\n\nEx: Solo argiloso, humidade elevada.\nObservações: presença de afloramento rochoso a Norte."
                        wrapMode: Text.Wrap
                        font.pixelSize: 13
                        background: null
                        color: "#212121"
                    }
                }
            }

            // ── Coordenadas GPS ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 44
                color: "#E8F5E9"
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Label {
                        text: "📍"
                        font.pixelSize: 16
                    }
                    Label {
                        id: coordLabel
                        Layout.fillWidth: true
                        text: obterCoordenadas()
                        font.pixelSize: 11
                        color: "#1B5E20"
                        elide: Text.ElideRight

                        // Atualiza as coordenadas periodicamente
                        Timer {
                            interval: 2000
                            running: notasDialog.visible
                            repeat: true
                            onTriggered: coordLabel.text = root.obterCoordenadas()
                        }
                    }
                    ToolButton {
                        text: "🔄"
                        font.pixelSize: 14
                        onClicked: coordLabel.text = root.obterCoordenadas()
                        ToolTip.text: "Atualizar coordenadas"
                        ToolTip.visible: hovered
                    }
                }
            }

            // ── Botão guardar ──────────────────────────────────────────────
            Button {
                Layout.fillWidth: true
                height: 44
                text: "💾  Guardar Nota"
                enabled: textoNota.text.trim() !== ""

                background: Rectangle {
                    color: parent.enabled
                        ? (parent.pressed ? "#1B5E20" : "#2E7D32")
                        : "#BDBDBD"
                    radius: 8
                }
                contentItem: Label {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (textoNota.text.trim() === "") return

                    var nota = {
                        texto: textoNota.text.trim(),
                        coordenadas: coordLabel.text,
                        hora: new Date().toLocaleString(Qt.locale("pt_PT"), "dd/MM/yyyy HH:mm")
                    }
                    root.notas.unshift(nota)
                    root.notasChanged()
                    textoNota.text = ""
                    iface.mainWindow().displayToast("✅ Nota guardada com sucesso!")
                }
            }

            // ── Separador ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Rectangle { Layout.fillWidth: true; height: 1; color: "#E0E0E0" }
                Label { text: "  Notas Guardadas  "; font.pixelSize: 11; color: "#757575" }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#E0E0E0" }
            }

            // ── Lista de notas guardadas ───────────────────────────────────
            ListView {
                id: listaNotas
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: root.notas

                // Mensagem quando vazio
                Label {
                    anchors.centerIn: parent
                    text: "Ainda não há notas.\nEscreva a primeira nota acima! 👆"
                    visible: root.notas.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    color: "#9E9E9E"
                    font.pixelSize: 13
                }

                delegate: Rectangle {
                    width: listaNotas.width
                    height: notaContent.implicitHeight + 20
                    color: "white"
                    radius: 8
                    border.color: "#E0E0E0"
                    border.width: 1

                    ColumnLayout {
                        id: notaContent
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top
                            margins: 10
                        }
                        spacing: 4

                        // Cabeçalho: hora + apagar
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "🕐 " + modelData.hora
                                font.pixelSize: 10
                                color: "#9E9E9E"
                                Layout.fillWidth: true
                            }
                            ToolButton {
                                text: "🗑"
                                font.pixelSize: 12
                                onClicked: {
                                    root.notas.splice(index, 1)
                                    root.notasChanged()
                                    iface.mainWindow().displayToast("Nota eliminada.")
                                }
                            }
                        }

                        // Texto da nota
                        Label {
                            text: modelData.texto
                            wrapMode: Text.Wrap
                            font.pixelSize: 13
                            color: "#212121"
                            Layout.fillWidth: true
                        }

                        // Coordenadas
                        Label {
                            text: "📍 " + modelData.coordenadas
                            font.pixelSize: 10
                            color: "#2E7D32"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // ─── Função auxiliar: obter coordenadas do GPS ──────────────────────────
    function obterCoordenadas() {
        try {
            var pos = iface.positioning()
            if (pos && pos.positionInformation) {
                var info = pos.positionInformation
                if (info.latitudeValid && info.longitudeValid) {
                    var lat = info.latitude.toFixed(6)
                    var lon = info.longitude.toFixed(6)
                    var alt = info.elevationValid
                        ? " | Alt: " + info.elevation.toFixed(1) + "m"
                        : ""
                    return "Lat: " + lat + "  Lon: " + lon + alt
                }
            }
        } catch (e) {
            // GPS não disponível ou sem sinal
        }
        return "GPS não disponível (sem sinal ou permissão)"
    }
}
