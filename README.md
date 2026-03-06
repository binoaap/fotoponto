# FotoPonto — Plugin QField v2.0

Tira foto com a câmera nativa do Android → cria ponto GPS → faz upload para o Google Drive.  
Sem OAuth, sem login, sem complicações.

---

## Instalar no QField (por URL)

O QField só aceita instalação por URL — não por ZIP directo.

### Opção A — Usar GitHub (recomendado, gratuito)

1. Criar conta em [github.com](https://github.com) se não tiver
2. Criar repositório público chamado `fotoponto`
3. Fazer upload de todos os ficheiros do plugin
4. Ir a **Releases → Create a new release → Attach files** → fazer upload do `fotoponto-v2.0.zip`
5. Após publicar o release, clicar com o botão direito no ficheiro ZIP → **Copy link address**
6. URL ficará assim:
   ```
   https://github.com/SEU_USUARIO/fotoponto/releases/download/v2.0/fotoponto-v2.0.zip
   ```
7. No QField: **Definições → Plugins → "Instale o plugin a partir do URL"** → colar o URL

### Opção B — Usar Dropbox

1. Fazer upload do `fotoponto-v2.0.zip` para o Dropbox
2. Partilhar o ficheiro → copiar link
3. Substituir `dl=0` por `dl=1` no final do URL
4. Colar no QField

### Opção C — Qualquer servidor web

Qualquer URL directo para o ficheiro ZIP funciona.

---

## Preparar o layer QGIS

No QGIS Desktop, criar um layer de pontos GeoPackage com estes campos:

| Campo       | Tipo    | Widget          | Descrição                |
|-------------|---------|-----------------|--------------------------|
| `foto`      | Texto   | **Attachment**  | Caminho relativo da foto |
| `gdrive_url`| Texto   | Text Edit       | URL do Google Drive      |
| `data_hora` | Texto   | Text Edit       | Timestamp ISO 8601       |
| `notas`     | Texto   | Text Edit       | Notas de campo           |

**Configurar o campo `foto` como Attachment:**
- QGIS → Layer → Propriedades → Formulário de atributos
- Campo `foto` → Widget: `Attachment`
- Modo de caminho: `Relativo ao projecto`

Depois copiar a pasta do projecto para o Android (via USB ou QFieldCloud).

---

## Configurar Google Drive (Service Account)

### 1. Criar projecto no Google Cloud

1. Aceder a [console.cloud.google.com](https://console.cloud.google.com)
2. Clique no selector de projecto (topo) → **Novo projecto**
3. Nome: `FotoPonto` → Criar

### 2. Activar a Drive API

1. **APIs e Serviços → Biblioteca**
2. Pesquisar `Google Drive API` → clicar → **Activar**

### 3. Criar Service Account

1. **IAM e Admin → Contas de Serviço** → **Criar conta de serviço**
2. Nome: `fotoponto-upload`
3. Clicar em **Concluído** (sem atribuir papéis — não são necessários para Drive)

### 4. Criar chave JSON

1. Clicar no email da service account criada
2. Separador **Chaves** → **Adicionar chave** → **Criar nova chave** → **JSON**
3. O ficheiro JSON é descarregado automaticamente. Guarde-o!

### 5. Partilhar pasta do Drive

1. No Google Drive, criar uma pasta (ex: `FotoPonto Campo`)
2. Clique com o botão direito → **Partilhar**
3. Colar o email da service account (ex: `fotoponto-upload@fotoponto-12345.iam.gserviceaccount.com`)
4. Permissão: **Editor** → Enviar
5. Copiar o ID da pasta: no URL do Drive após `/folders/`

### 6. Adicionar folder_id ao JSON

Abrir o ficheiro JSON descarregado e adicionar uma linha antes do `}` final:
```json
{
  "type": "service_account",
  "project_id": "fotoponto-12345",
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "fotoponto-upload@fotoponto-12345.iam.gserviceaccount.com",
  ...
  "folder_id": "1AbCdEfGhIjKlMnOpQrStUvWxYz"
}
```

### 7. Configurar no plugin

1. QField → Menu lateral → ⚙️ → **FotoPonto Definições**
2. Copiar e colar o conteúdo completo do ficheiro JSON
3. Clicar em **🔗 Testar ligação ao Google Drive**
4. Deve aparecer: ✅ Google Drive ligado com sucesso!
5. Clicar **💾 Guardar**

---

## Uso em campo

```
1. Abrir o projecto no QField
2. Seleccionar o layer de pontos no dashboard
3. Activar GPS (botão de localização)
4. Clicar no botão 📷 na barra de plugins (topo do mapa)
5. Tirar a foto na câmera nativa do Android
6. Ponto criado automaticamente com coordenadas GPS!
7. Upload para o Google Drive em segundo plano (~5 seg)
```

---

## Estrutura de ficheiros no projecto

```
projecto.qgz
├── pontos.gpkg              ← layer com os pontos
├── pontos.qml               ← plugin (se for plugin de projecto)
└── DCIM/
    ├── FotoPonto_20240315_143022.jpg
    └── FotoPonto_20240315_143512.jpg
```

---

## Resolução de problemas

| Problema | Causa | Solução |
|---|---|---|
| "Active o GPS primeiro" | GPS desligado | Tocar no botão de localização |
| "Seleccione um layer" | Nenhum layer activo | Tocar no nome do layer no dashboard |
| "JSON inválido" | Texto colado incorrecto | Copiar o ficheiro JSON completo |
| "Falha ao obter token: 400" | Email da SA errado no Drive | Verificar se partilhou a pasta com o email correcto |
| "Falha no upload: 403" | Drive API não activada | Activar no Cloud Console |
| Fotos sem GPS | GPS perdeu sinal | Esperar pelo sinal GPS antes de fotografar |
