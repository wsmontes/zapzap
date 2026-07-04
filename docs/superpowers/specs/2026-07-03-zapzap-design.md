# ZapZap — Design Spec

**Data:** 2026-07-03
**Status:** Aprovado
**Plataforma:** iOS 17+ (SwiftUI + MVVM)

---

## 1. Visão Geral

ZapZap é um app iOS gratuito, ultra-simples e 100% em português (pt-BR) para criar figurinhas (stickers) para o WhatsApp. Público-alvo: brasileiros que querem criar memes e figurinhas sem complicação.

### Diferenciais

- **Simplicidade máxima** — UI limpa, fluxos óbvios, zero atrito
- **Gratuito** — sem anúncios, sem assinatura, sem limite de uso
- **Brasileiro** — interface em pt-BR, foco em memes e cultura BR
- **Privacidade** — remoção de fundo on-device (Vision), sem upload de imagens

---

## 2. Funcionalidades

### 2.1 Entradas de Criação

| Entrada | Descrição |
|---|---|
| 📸 **Foto/Minha Imagem** | Câmera ou galeria → remove fundo com IA (1 toque) → sticker |
| 🌐 **Imagem da Internet** | Cola URL ou clipboard → adiciona texto de meme → sticker |
| ✍️ **Texto de Meme** | Sobrepõe texto estilo meme (bordão/punchline) em qualquer imagem |

### 2.2 Remoção de Fundo

- Apple **Vision** framework (`VNGeneratePersonSegmentationRequest`)
- On-device, sem custo, funciona offline
- Fallback: recorte manual (borracha/pincel) quando Vision não detecta sujeito

### 2.3 Texto de Meme

- Fonte **Impact** (padrão), branco com borda preta
- Posicionamento superior (bordão) e inferior (punchline)
- Ajuste de tamanho, posição, cor

### 2.4 Stickers Animados

- GIFs e vídeos curtos → WebP animado
- Trim para ≤ 6 segundos
- Compressão automática para ≤ 500 KB

### 2.5 Exportação

- **Individual** — figurinha avulsa direto pro WhatsApp
- **Pack** — coleção de 3–30 stickers exportada de uma vez
- Formato `.wastickers` (ZIP com `sticker_packs.json`, PNG tray icon, WebP stickers)
- Compartilhamento via AirDrop, link ou arquivo

### 2.6 Organização

- Home com grid de packs (2 colunas)
- Cada pack: visualização, adicionar mais stickers, exportar, deletar
- Persistência local via SwiftData

---

## 3. Especificações Técnicas

### 3.1 Formato dos Stickers

| Propriedade | Requisito |
|---|---|
| Formato | WebP com canal alpha (transparência) |
| Dimensões | Exatamente **512×512** pixels |
| Peso estático | ≤ **100 KB** |
| Peso animado | ≤ **500 KB** |
| Animação | ≤ **6 segundos** |
| Tray icon | PNG **96×96px** com transparência, ≤ 50 KB |

### 3.2 Estrutura do .wastickers

```
sticker_pack.wastickers (ZIP)
├── sticker_packs.json    # identifier, name, publisher, tray_image_file, image_files[]
├── tray.png              # 96×96 PNG
├── 00.webp               # Sticker 1
├── 01.webp               # Sticker 2
└── ...
```

### 3.3 Stack Técnica

| Camada | Tecnologia |
|---|---|
| UI | SwiftUI (iOS 17+) |
| Arquitetura | MVVM com `@Observable` |
| Persistência | SwiftData |
| Remoção de fundo | Vision (`VNGeneratePersonSegmentationRequest`) |
| Conversão WebP | libwebp via SDWebImage/libwebp-Xcode (SPM) |
| API WhatsApp | Adaptado do repo oficial `github.com/WhatsApp/stickers` |
| Animações | GIF/MP4 → frames → WebP animado via libwebp |
| Rede | URLSession (download de imagens da internet) |

### 3.4 Requisitos do Sistema

- iOS 17.0+
- iPhone (não requer iPad)
- Não requer login/cadastro
- Não requer internet (exceto para baixar imagens da web)

---

## 4. Arquitetura

### 4.1 Estrutura de Diretórios

```
zapzap/
├── App/
│   ├── ZapZapApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── StickerPack.swift        # SwiftData model
│   ├── Sticker.swift            # SwiftData model
│   └── MemeText.swift           # Config de texto sobreposto
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── EditorViewModel.swift
│   ├── MemeEditorViewModel.swift
│   └── ExportViewModel.swift
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── PackCardView.swift
│   │   └── PackDetailView.swift
│   ├── Editor/
│   │   ├── EditorView.swift
│   │   ├── CropOverlay.swift
│   │   └── BackgroundEraserView.swift
│   ├── MemeEditor/
│   │   └── MemeTextEditorView.swift
│   ├── Export/
│   │   └── ExportView.swift
│   └── Components/
│       ├── SourcePicker.swift     # Foto / Internet / Meme
│       └── EmojiPicker.swift
├── Services/
│   ├── BackgroundRemovalService.swift
│   ├── WebPConverter.swift
│   ├── WhatsAppExporter.swift
│   ├── ImageDownloadService.swift
│   └── PasteboardService.swift
└── Resources/
    ├── Assets.xcassets
    └── pt-BR.lproj/
        └── Localizable.strings
```

### 4.2 Navegação

```
HomeView (NavigationStack)
  ├── Sheet: SourcePicker (Foto / Internet / Meme)
  │   ├── → EditorView (com a imagem selecionada)
  │   └── → MemeTextEditorView (sobreposição de texto)
  ├── Push: PackDetailView (pack selecionado)
  │   └── Sheet: ExportView
  └── Push: EditorView (adicionar sticker a pack existente)
```

### 4.3 Modelagem de Dados (SwiftData)

```swift
@Model
class StickerPack {
    var identifier: String      // UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var stickers: [Sticker]
    var trayImageData: Data?    // PNG 96×96
}

@Model
class Sticker {
    var id: String              // UUID
    var imageData: Data         // WebP 512×512
    var emojis: [String]        // emojis associados
    var isAnimated: Bool
    var createdAt: Date
    var pack: StickerPack?
}
```

---

## 5. Fluxos Detalhados

### 5.1 Criar sticker de foto com remoção de fundo

1. Usuário escolhe "Foto" no SourcePicker
2. Permissão de câmera/fotos (se primeiro uso)
3. Imagem carregada no EditorView (crop quadrado 512×512)
4. Toque em "Remover Fundo" → `BackgroundRemovalService` processa
5. Preview com checkerboard (transparência)
6. Opções: refinar manual, adicionar texto, adicionar emojis
7. Salvar → volta pra Home com pack atualizado

### 5.2 Criar sticker da internet

1. Usuário escolhe "Internet" no SourcePicker
2. Cola URL ou imagem do clipboard
3. Download via `ImageDownloadService`
4. Preview no EditorView
5. Opcional: adicionar texto de meme
6. Salvar

### 5.3 Criar sticker animado

1. Importa GIF da galeria ou URL de vídeo
2. Preview animado no editor
3. Slider de trim (0–6s)
4. Converte para WebP animado via `WebPConverter`
5. Compressão com qualidade ajustável se > 500 KB
6. Salvar

### 5.4 Exportar para WhatsApp

1. `WhatsAppExporter` monta o ZIP `.wastickers`
2. Verifica se WhatsApp está instalado (`LSApplicationQueriesSchemes`)
3. Chama `stickerPack.sendToWhatsApp()` via API oficial
4. WhatsApp abre e importa o pack

---

## 6. Tratamento de Erros

| Situação | Comportamento |
|---|---|
| WhatsApp não instalado | Alerta + opção de salvar arquivo .wastickers |
| Falha na conversão WebP | Retry automático com qualidade reduzida |
| Pack com < 3 stickers | Bloqueia export, mostra "Faltam X figurinhas" |
| Sem internet (download) | Cache offline, erro com botão de retry |
| Armazenamento cheio | Detecta antes de salvar, sugere liberar espaço |
| Permissão negada (câmera/fotos) | Explica como liberar nos Ajustes |
| Clipboard vazio | Indica "Cole uma imagem ou link primeiro" |
| URL inválida | Erro amigável com sugestão |
| Foto sem sujeito detectável | "Não encontrei nada pra recortar 😕" |
| GIF > 6 segundos | Trim automático, usuário ajusta |
| Arquivo final > 500 KB (animado) | Compressão com warning de qualidade |

---

## 7. Acessibilidade

- 100% pt-BR (Localizable.strings)
- VoiceOver: todos os botões e imagens têm `accessibilityLabel`
- Dynamic Type para textos de UI (não de meme)
- Suporte a Light/Dark mode
- Contraste adequado em todos os temas

---

## 8. O Que NÃO Está no Escopo

- Geração de imagens por IA (texto→imagem)
- Sincronização em nuvem / contas
- Anúncios ou monetização
- iPad (iPhone apenas)
- Android
- Suporte a iMessage stickers (só WhatsApp)
- Edição colaborativa
- Marketplace/biblioteca pública de stickers
- Animações complexas nos stickers (além de GIF/vídeo → WebP)

---

## 9. Referências

- [WhatsApp Stickers — Repositório Oficial](https://github.com/WhatsApp/stickers)
- [SDWebImage/libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode)
- [Apple Vision Framework](https://developer.apple.com/documentation/vision)
- [WebP Documentation](https://developers.google.com/speed/webp)
