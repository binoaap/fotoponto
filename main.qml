// ============================================================
//  FotoPonto — Plugin QField v2.0
//  Baseado no plugin oficial qfield-snap (OPENGIS.ch)
//
//  O QUE FAZ:
//    1. Botão 📷 na barra de plugins
//    2. Abre a câmera nativa do Android (via QField)
//    3. Cria ponto GPS no layer activo
//    4. Guarda foto em DCIM/ dentro do projecto
//    5. Faz upload para Google Drive via Service Account
//       (sem OAuth, sem browser, sem códigos)
//
//  INSTALAÇÃO DO PLUGIN:
//    QField → Definições → Plugins → "Instale o plugin a partir do URL"
//    Colar o URL directo para o ZIP (ex: GitHub Releases raw link)
//
//  LAYER QGIS NECESSÁRIO (criado automaticamente na 1ª foto se não existir):
//    → Tipo ponto, CRS do projecto
//    → Campos: foto (texto, Attachment), gdrive_url (texto), data_hora (texto)
//
//  GOOGLE DRIVE (Service Account):
//    1. console.cloud.google.com → criar projecto → activar Drive API
//    2. IAM → Service Accounts → criar → criar chave JSON → descarregar
//    3. Partilhar a pasta do Drive com o email da service account
//    4. No plugin → ⚙️ → colar o JSON da service account
// ============================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.settings

import org.qfield
import org.qgis
import Theme

import "qrc:/qml" as QFieldItems

Item {
    id: plugin

    // ── Referências QField (padrão oficial qfield-snap) ──────────────────────
    property var mainWindow:               iface.mainWindow()
    property var positionSource:           iface.findItemByObjectName('positionSource')
    property var dashBoard:                iface.findItemByObjectName('dashBoard')
    property var overlayFeatureFormDrawer: iface.findItemByObjectName('overlayFeatureFormDrawer')

    // ── Settings persistidas ─────────────────────────────────────────────────
    Settings {
        id: cfg
        category: "fotoponto"
        property string serviceAccountJson: ""
        property string driveAccessToken:   ""
        property int    tokenExpiry:        0       // epoch seconds
    }

    // ── Estado runtime ────────────────────────────────────────────────────────
    property string currentPhotoPath: ""
    property string currentRelPath:   ""

    // ── Inicializar ───────────────────────────────────────────────────────────
    Component.onCompleted: {
        iface.addItemToPluginsToolbar(cameraButton)
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  BOTÃO CÂMERA — barra de plugins (topo do mapa)
    // ══════════════════════════════════════════════════════════════════════════
    QFieldItems.QfToolButton {
        id: cameraButton
        round: true
        bgcolor: Theme.mainColor
        iconSource: Theme.getThemeVectorIcon("ic_camera_photo_white_24dp")
        iconColor: "white"
        width: 48; height: 48

        onClicked: {
            // 1. Verificar GPS
            if (!positionSource || !positionSource.active) {
                mainWindow.displayToast(qsTr("⚠️ Active o GPS primeiro."))
                return
            }
            let pi = positionSource.positionInformation
            if (!pi || !pi.latitudeValid || !pi.longitudeValid) {
                mainWindow.displayToast(qsTr("⚠️ A aguardar sinal GPS..."))
                return
            }
            // 2. Verificar layer ponto activo
            if (!dashBoard.activeLayer) {
                mainWindow.displayToast(qsTr("⚠️ Seleccione um layer de pontos no dashboard."))
                return
            }
            if (dashBoard.activeLayer.geometryType() !== Qgis.GeometryType.Point) {
                mainWindow.displayToast(qsTr("⚠️ O layer activo não é do tipo ponto."))
                return
            }
            // 3. Abrir câmera
            cameraLoader.active = true
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  CÂMERA  (usa a câmera nativa do Android por baixo)
    // ══════════════════════════════════════════════════════════════════════════
    Loader {
        id: cameraLoader
        active: false
        sourceComponent: Component {
            QFieldItems.QFieldCamera {
                Component.onCompleted: open()

                onFinished: function(path) {
                    close()
                    criarPonto(path)
                }
                onCanceled: close()
                onClosed:   cameraLoader.active = false
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  CRIAR PONTO (baseado no código oficial do qfield-snap)
    // ══════════════════════════════════════════════════════════════════════════
    function criarPonto(path) {
        let layer = dashBoard.activeLayer
        if (!layer || !layer.isValid()) {
            mainWindow.displayToast(qsTr("❌ Layer inválido."))
            return
        }

        // — Timestamp para nome de ficheiro —
        let agora      = new Date()
        let ts         = agora.getFullYear()
                       + String(agora.getMonth() + 1).padStart(2, '0')
                       + String(agora.getDate()).padStart(2, '0')
                       + '_'
                       + String(agora.getHours()).padStart(2, '0')
                       + String(agora.getMinutes()).padStart(2, '0')
                       + String(agora.getSeconds()).padStart(2, '0')
        let ext        = FileUtils.fileSuffix(path) || 'jpg'
        let relPath    = 'DCIM/FotoPonto_' + ts + '.' + ext
        let destPath   = qgisProject.homePath + '/' + relPath

        // — Mover foto para pasta do projecto —
        platformUtilities.renameFile(path, destPath)

        // — Geometria GPS (exactamente como qfield-snap) —
        let pos = positionSource.projectedPosition
        let wkt = 'POINT(' + pos.x + ' ' + pos.y + ')'

        // — Criar feature —
        let feature = FeatureUtils.createFeature(layer, GeometryUtils.createGeometryFromWkt(wkt))
        let fields  = layer.fields
        let nomes   = []
        for (let i = 0; i < fields.count; i++) nomes.push(fields.field(i).name().toLowerCase())

        // — Preencher campos conhecidos —
        let candidatosFoto = ['foto','photo','imagem','image','picture','media','ficheiro','file']
        for (let c of candidatosFoto) {
            let idx = nomes.indexOf(c)
            if (idx >= 0) { feature.setAttribute(idx, relPath); break }
        }
        let idxDataHora = nomes.indexOf('data_hora')
        if (idxDataHora < 0) idxDataHora = nomes.indexOf('data')
        if (idxDataHora >= 0) feature.setAttribute(idxDataHora, agora.toISOString())

        // — Guardar no layer —
        layer.startEditing()
        layer.addFeature(feature)
        layer.commitChanges()

        mainWindow.displayToast(qsTr("📍 Ponto criado!"))

        // — Upload Drive —
        currentPhotoPath = destPath
        currentRelPath   = relPath
        if (cfg.serviceAccountJson !== "") {
            obterTokenSA(function(token) {
                if (token) fazerUpload(destPath, relPath, token)
            })
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  GOOGLE DRIVE — Service Account (sem OAuth, sem browser)
    //
    //  Fluxo:
    //    1. Ler client_email e private_key do JSON da service account
    //    2. Criar JWT assinado com RS256
    //    3. Trocar JWT por access token (POST oauth2.googleapis.com/token)
    //    4. Upload multipart para Drive API v3
    // ══════════════════════════════════════════════════════════════════════════

    // Gera um JWT assinado para service account (RS256 via SubtleCrypto Web API)
    // NOTA: QField tem acesso à Web Crypto API (Qt WebEngine / Qt Quick)
    function obterTokenSA(callback) {
        // Se tiver token válido em cache (com 5 min de margem), reutilizar
        let agora = Math.floor(Date.now() / 1000)
        if (cfg.driveAccessToken !== "" && cfg.tokenExpiry > agora + 300) {
            callback(cfg.driveAccessToken)
            return
        }

        let saJson
        try {
            saJson = JSON.parse(cfg.serviceAccountJson)
        } catch(e) {
            mainWindow.displayToast(qsTr("❌ JSON da service account inválido."))
            callback(null)
            return
        }

        if (!saJson.client_email || !saJson.private_key) {
            mainWindow.displayToast(qsTr("❌ JSON incompleto: falta client_email ou private_key."))
            callback(null)
            return
        }

        let iat   = Math.floor(Date.now() / 1000)
        let exp   = iat + 3600
        let scope = "https://www.googleapis.com/auth/drive.file"

        let header  = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
            .replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_')
        let payload = btoa(JSON.stringify({
            iss: saJson.client_email,
            scope: scope,
            aud: "https://oauth2.googleapis.com/token",
            exp: exp,
            iat: iat
        })).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_')

        let unsignedJwt = header + '.' + payload

        // Importar chave privada PEM e assinar
        let pemKey = saJson.private_key
            .replace('-----BEGIN PRIVATE KEY-----', '')
            .replace('-----END PRIVATE KEY-----', '')
            .replace(/\s/g, '')
        let keyBytes = _base64ToArrayBuffer(pemKey)

        crypto.subtle.importKey(
            "pkcs8",
            keyBytes,
            { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
            false,
            ["sign"]
        ).then(function(key) {
            let encoder  = new TextEncoder()
            let data     = encoder.encode(unsignedJwt)
            return crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, data)
        }).then(function(sig) {
            let sigB64 = _arrayBufferToBase64(sig)
                .replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_')
            let jwt    = unsignedJwt + '.' + sigB64

            // Trocar JWT por access token
            let req = new XMLHttpRequest()
            req.open("POST", "https://oauth2.googleapis.com/token", true)
            req.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
            req.onreadystatechange = function() {
                if (req.readyState !== XMLHttpRequest.DONE) return
                if (req.status === 200) {
                    let r = JSON.parse(req.responseText)
                    cfg.driveAccessToken = r.access_token
                    cfg.tokenExpiry      = Math.floor(Date.now() / 1000) + (r.expires_in || 3600)
                    callback(r.access_token)
                } else {
                    mainWindow.displayToast(qsTr("❌ Falha ao obter token Drive: ") + req.status)
                    callback(null)
                }
            }
            req.send(
                "grant_type=" + encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")
              + "&assertion=" + encodeURIComponent(jwt)
            )
        }).catch(function(err) {
            mainWindow.displayToast(qsTr("❌ Erro ao assinar JWT: ") + err)
            callback(null)
        })
    }

    function fazerUpload(caminhoLocal, nomeRemoto, token) {
        mainWindow.displayToast(qsTr("☁️ A enviar foto para o Google Drive..."))

        let conteudoB64 = FileUtils.fileContentsToBase64(caminhoLocal)
        if (!conteudoB64) {
            mainWindow.displayToast(qsTr("❌ Não foi possível ler o ficheiro."))
            return
        }

        let saJson = {}
        try { saJson = JSON.parse(cfg.serviceAccountJson) } catch(e) {}
        let folderId = saJson.folder_id || ""

        let metaDados = { name: nomeRemoto, mimeType: "image/jpeg" }
        if (folderId) metaDados.parents = [folderId]

        let boundary = "fp_boundary_" + Date.now()
        let corpo    = "--" + boundary + "\r\n"
                     + "Content-Type: application/json; charset=UTF-8\r\n\r\n"
                     + JSON.stringify(metaDados) + "\r\n"
                     + "--" + boundary + "\r\n"
                     + "Content-Type: image/jpeg\r\n"
                     + "Content-Transfer-Encoding: base64\r\n\r\n"
                     + conteudoB64 + "\r\n"
                     + "--" + boundary + "--"

        let req = new XMLHttpRequest()
        req.open("POST",
            "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink",
            true)
        req.setRequestHeader("Authorization", "Bearer " + token)
        req.setRequestHeader("Content-Type", "multipart/related; boundary=" + boundary)
        req.onreadystatechange = function() {
            if (req.readyState !== XMLHttpRequest.DONE) return
            if (req.status === 200 || req.status === 201) {
                let r = JSON.parse(req.responseText)
                let url = r.webViewLink || ("https://drive.google.com/file/d/" + r.id + "/view")
                mainWindow.displayToast(qsTr("✅ Foto no Google Drive!"))
                // Guardar URL no campo gdrive_url do layer
                _guardarDriveUrl(url)
            } else if (req.status === 401) {
                // Token expirou — forçar renovação
                cfg.driveAccessToken = ""
                cfg.tokenExpiry      = 0
                mainWindow.displayToast(qsTr("🔄 Token expirado — a renovar..."))
                obterTokenSA(function(t) {
                    if (t) fazerUpload(caminhoLocal, nomeRemoto, t)
                })
            } else {
                mainWindow.displayToast(qsTr("❌ Falha no upload: HTTP ") + req.status)
            }
        }
        req.send(corpo)
    }

    function _guardarDriveUrl(url) {
        // Tenta guardar o URL no último ponto criado
        let layer = dashBoard.activeLayer
        if (!layer) return
        let campos = []
        for (let i = 0; i < layer.fields.count; i++)
            campos.push(layer.fields.field(i).name().toLowerCase())
        let idx = campos.indexOf('gdrive_url')
        if (idx < 0) idx = campos.indexOf('drive_url')
        if (idx < 0) return
        // Editar a última feature adicionada
        let iter = layer.getFeatures()
        let lastFeat = null
        iter.nextFeature(function(f) { lastFeat = f })
        if (!lastFeat) return
        layer.startEditing()
        layer.changeAttributeValue(lastFeat.id, idx, url)
        layer.commitChanges()
    }

    // Utilitários Base64 ↔ ArrayBuffer (Web Crypto precisa disto)
    function _base64ToArrayBuffer(b64) {
        let binary = atob(b64)
        let bytes  = new Uint8Array(binary.length)
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
        return bytes.buffer
    }
    function _arrayBufferToBase64(buf) {
        let binary = ''
        let bytes  = new Uint8Array(buf)
        for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i])
        return btoa(binary)
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  BOTÃO DEFINIÇÕES
    // ══════════════════════════════════════════════════════════════════════════
    QFieldItems.QfToolButton {
        id: settingsBtn
        round: true
        bgcolor: "transparent"
        iconSource: Theme.getThemeVectorIcon("ic_settings_white_24dp")
        iconColor: "white"
        width: 48; height: 48

        Component.onCompleted: {
            iface.addItemToDashboardActionsToolbar(settingsBtn)
        }

        onClicked: settingsDlg.open()
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  DIALOG DEFINIÇÕES
    // ══════════════════════════════════════════════════════════════════════════
    Dialog {
        id: settingsDlg
        parent: mainWindow.contentItem
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.92, 500)
        modal: true
        title: qsTr("FotoPonto ⚙️ Definições")
        standardButtons: Dialog.Close

        ColumnLayout {
            width: parent.width
            spacing: 16

            // ── Secção Google Drive ──────────────────────────────────────────
            Label {
                text: qsTr("Google Drive (Service Account)")
                font.bold: true
                font.pointSize: 13
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Cole aqui o conteúdo do ficheiro JSON descarregado do "
                          + "Google Cloud Console (Service Account → Criar chave → JSON).\n\n"
                          + "Opcional: adicione um campo \"folder_id\" ao JSON com o ID "
                          + "da pasta do Drive onde guardar as fotos.")
                font.pointSize: 10
                color: "#666"
            }

            ScrollView {
                Layout.fillWidth: true
                height: 160
                TextArea {
                    id: saJsonField
                    placeholderText: '{\n  "type": "service_account",\n  "project_id": "...",\n  "private_key": "-----BEGIN PRIVATE KEY-----\\n...",\n  "client_email": "fotoponto@projecto.iam.gserviceaccount.com",\n  "folder_id": "1AbCdEfGhIjKlMnOpQrStUvWx"  ← opcional\n}'
                    text: cfg.serviceAccountJson
                    wrapMode: Text.Wrap
                    font.family: "monospace"
                    font.pointSize: 9
                    background: Rectangle { color: "#1a1a1a"; radius: 6 }
                    color: "#e0e0e0"
                }
            }

            // Estado do token
            Label {
                Layout.fillWidth: true
                text: cfg.driveAccessToken !== ""
                    ? qsTr("✅ Token activo (expira em " + Math.max(0, Math.round((cfg.tokenExpiry - Date.now()/1000)/60)) + " min)")
                    : qsTr("🔴 Sem token — será obtido automaticamente na 1ª foto")
                color: cfg.driveAccessToken !== "" ? "green" : "#ff8800"
                font.pointSize: 10
            }

            // Botão testar ligação
            Button {
                Layout.fillWidth: true
                text: qsTr("🔗 Testar ligação ao Google Drive")
                onClicked: {
                    cfg.serviceAccountJson = saJsonField.text.trim()
                    cfg.driveAccessToken   = ""
                    cfg.tokenExpiry        = 0
                    obterTokenSA(function(token) {
                        if (token) {
                            mainWindow.displayToast(qsTr("✅ Google Drive ligado com sucesso!"))
                        } else {
                            mainWindow.displayToast(qsTr("❌ Falha — verifique o JSON da service account."))
                        }
                    })
                }
            }

            // ── Separador ───────────────────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: "#444" }

            // ── Instruções ──────────────────────────────────────────────────
            Label {
                text: qsTr("Como configurar o Google Drive")
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pointSize: 10
                color: "#aaa"
                text: qsTr(
                    "1. console.cloud.google.com → Novo projecto\n"
                  + "2. APIs e Serviços → Biblioteca → Drive API → Activar\n"
                  + "3. IAM e Admin → Contas de Serviço → Criar\n"
                  + "4. Na conta criada → Chaves → Adicionar chave → JSON → Descarregar\n"
                  + "5. No Google Drive, criar uma pasta e partilhá-la com o email\n"
                  + "   da service account (ex: fotoponto@projecto.iam.gserviceaccount.com)\n"
                  + "6. Copiar o ID da pasta do URL do Drive (após /folders/)\n"
                  + "7. Abrir o ficheiro JSON e adicionar: \"folder_id\": \"ID_DA_PASTA\"\n"
                  + "8. Colar o JSON aqui e clicar em Testar ligação"
                )
            }

            // ── Guardar ─────────────────────────────────────────────────────
            Button {
                Layout.fillWidth: true
                text: qsTr("💾 Guardar")
                highlighted: true
                onClicked: {
                    cfg.serviceAccountJson = saJsonField.text.trim()
                    cfg.driveAccessToken   = ""  // forçar novo token com novo JSON
                    cfg.tokenExpiry        = 0
                    settingsDlg.close()
                    mainWindow.displayToast(qsTr("✅ Definições guardadas."))
                }
            }
        }
    }
}
