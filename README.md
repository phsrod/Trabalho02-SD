# Detecção de Objetos — Trabalho 02 (SD)

Aplicativo mobile de detecção de objetos que captura imagens com a câmera do dispositivo e as envia via **socket TCP** para um servidor Python. O servidor processa a imagem com **YOLO** e **OpenCV**, retornando a lista de objetos detectados. Projeto acadêmico da disciplina de Sistemas Distribuídos.

![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B?logo=flutter&logoColor=white) ![Dart](https://img.shields.io/badge/Dart-3.13.2-0175C2?logo=dart&logoColor=white) ![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-29.7.2-2496ED?logo=docker&logoColor=white) ![OpenCV](https://img.shields.io/badge/OpenCV-4.x-5C3EE8?logo=opencv&logoColor=white)

---

## Sumário

- [Como rodar](#como-rodar)
- [Configuração de IP e porta](#configuração-de-ip-e-porta)
- [Capturas de tela](#capturas-de-tela)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Arquitetura](#arquitetura)
- [Licença](#licença)

---

## Como rodar

### Pré-requisitos

| Componente | Requisito |
|------------|-----------|
| **Servidor** | [Docker](https://docs.docker.com/get-docker/) |
| **App** | Celular Android — instale pelo [APK nos Releases](https://github.com/phsrod/Trabalho02-SD/releases) ou compile com [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.47+ |
| **Dispositivo** | Celular Android com câmera (ou emulador com câmera habilitada) |
| **Rede** | Celular e computador na **mesma rede Wi-Fi** |

> O modelo YOLO deve estar em `server/models/modelo_pretreinado.pt` antes de iniciar o servidor.

### 1. Clonar o repositório

```bash
git clone <url-do-repositorio>
cd Trabalho02-SD
```

### 2. Rodar o servidor (Docker)

```bash
cd server
docker compose up --build
```

O container expõe a porta **5000** e salva as imagens recebidas em `server/received_images/`.

Ao iniciar com sucesso, o terminal exibirá:

```text
Servidor aguardando conexoes em 0.0.0.0:5000...
```

### 3. Instalar o app

#### Opção A — APK (recomendado)

O repositório possui um **release com o APK pronto** para instalação, sem necessidade de Flutter ou compilação local:

1. Acesse a [página de Releases](https://github.com/phsrod/Trabalho02-SD/releases) do repositório.
2. Baixe o arquivo `.apk` da versão mais recente.
3. Transfira para o celular Android (ou baixe diretamente no aparelho).
4. Instale o app — se solicitado, permita a instalação de apps de fontes desconhecidas nas configurações do Android.

#### Opção B — Flutter (desenvolvimento)

Para compilar e executar a partir do código-fonte, em outro terminal:

```bash
cd app

# Instalar dependências
flutter pub get

# Listar dispositivos disponíveis
flutter devices

# Executar no dispositivo conectado
flutter run
```

### 4. Testar a comunicação

1. Descubra o **IP local** da máquina onde o servidor está rodando (ex.: `192.168.0.100`).
2. No app, configure esse IP e a porta do servidor (veja a seção abaixo).
3. Toque no botão de captura para tirar uma foto e enviar ao servidor.
4. Aguarde o painel de resultado com os objetos detectados.

> **Importante:** use o IP da máquina na rede local, **não** `localhost` ou `127.0.0.1`, pois o app roda no celular e precisa alcançar o computador pela rede.

---

## Configuração de IP e porta

A comunicação entre app e servidor é feita por **socket TCP**. O IP e a porta devem ser os mesmos nos dois lados.

### No servidor (Python)

Edite as constantes em `server/main.py`:

```python
HOST = "0.0.0.0"   # escuta em todas as interfaces de rede
PORT = 5000        # porta do socket
```

| Valor | Descrição |
|-------|-----------|
| `HOST = "0.0.0.0"` | Permite conexões de outros dispositivos na rede (celular, emulador, etc.) |
| `PORT` | Porta TCP em que o servidor aguarda conexões |

Se usar Docker, a porta externa é definida em `server/docker-compose.yaml`:

```yaml
ports:
  - "5000:5000"   # host:container
```

Altere o primeiro valor (`5000`) para expor outra porta no computador.

### No app (Flutter)

O app permite configurar IP e porta pela interface, sem recompilar:

1. Abra o app no celular.
2. Toque no ícone **Conexão do servidor** (canto superior direito).
3. Preencha:
   - **IP do servidor** — IP local da máquina (ex.: `192.168.0.100`)
   - **Porta** — mesma porta configurada no servidor (padrão: `5000`)
4. Toque em **Salvar**.

Os valores são persistidos com `SharedPreferences` e reaplicados na próxima abertura do app. O status da conexão atual aparece na parte inferior da tela (`Servidor: IP:porta`).

**Valores padrão do app** (antes de salvar configurações):

| Campo | Padrão |
|-------|--------|
| IP | `192.168.0.100` |
| Porta | `5000` |

### Descobrir o IP da máquina

```bash
# Windows
ipconfig

# Linux / macOS
ip addr
# ou
ifconfig
```

Procure o endereço IPv4 da interface Wi-Fi ou Ethernet (geralmente começa com `192.168.x.x` ou `10.x.x.x`).

### Firewall

Certifique-se de que a porta escolhida (ex.: 5000) está liberada no firewall do sistema operacional para conexões de entrada na rede local.

---

## Capturas de tela

> Adicione as imagens em `.github/screenshots/` com os nomes abaixo para que apareçam no README.

### App — tela principal

Prévia da câmera, botão de captura e indicador do servidor configurado.

![Tela principal do app](.github/screenshots/app.png)

### Imagem capturada

Miniatura da última foto tirada (clicável para visualização ampliada).

![Imagem capturada](.github/screenshots/imagem_capturada.png)

### Resultado da detecção

Painel com os objetos identificados pelo YOLO após o processamento no servidor.

![Resultado da detecção](.github/screenshots/resultado_deteccao.png)

---

## Estrutura do projeto

```
Trabalho02-SD/
├── README.md
├── LICENSE
├── .gitignore
│
├── .github/
│   └── screenshots/              # Capturas de tela do app
│       ├── app.png
│       ├── imagem_capturada.png
│       └── resultado_deteccao.png
│
├── app/                          # ── App mobile (Flutter) ──────────────
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart             # Entry point e tema do app
│   │   ├── screens/
│   │   │   └── home_screen.dart  # Tela principal (câmera, config, resultado)
│   │   ├── services/
│   │   │   ├── camera_service.dart   # Captura e preparo da imagem
│   │   │   └── socket_service.dart   # Comunicação TCP com o servidor
│   │   └── models/
│   │       └── detection_result.dart # Modelo da resposta JSON
│   └── android/                  # Configuração Android (permissões, build)
│
└── server/                       # ── Servidor (Python) ─────────────────
    ├── main.py                   # Ponto de entrada — socket TCP
    ├── server.py                 # Protocolo de recebimento/envio
    ├── detector.py               # Detecção com YOLO (Ultralytics)
    ├── image_utils.py            # Decodificação e salvamento de imagens
    ├── requirements.txt
    ├── Dockerfile
    ├── docker-compose.yaml
    ├── models/
    │   └── modelo_pretreinado.pt # Modelo YOLO pré-treinado
    └── received_images/          # Imagens recebidas (gerado em runtime)
```

---

## Arquitetura

O sistema segue uma arquitetura **cliente-servidor** distribuída: o app Flutter atua como cliente (captura e envio) e o servidor Python como processador (detecção de objetos). A comunicação é **síncrona por conexão TCP**, sem HTTP ou banco de dados.

### Visão geral

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DISPOSITIVO MÓVEL (Flutter)                     │
│                                                                     │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────────┐   │
│  │  HomeScreen  │──▶│ CameraService│   │    SharedPreferences   │   │
│  │  (UI/câmera) │   │ (captura/JPEG)│   │  (IP e porta salvos)  │   │
│  └──────┬───────┘   └──────────────┘   └────────────────────────┘   │
│         │                                                             │
│         │  imagem JPEG (bytes)                                        │
│         ▼                                                             │
│  ┌──────────────┐                                                     │
│  │SocketService │  TCP ──────────────────────────────────────────┐   │
│  └──────────────┘                                                 │   │
└───────────────────────────────────────────────────────────────────┼───┘
                                                                    │
                              Rede local (Wi-Fi)                    │
                                                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     SERVIDOR (Python)                               │
│                                                                     │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────────┐   │
│  │   main.py    │──▶│  server.py   │──▶│  image_utils.py        │   │
│  │ (socket TCP) │   │  (protocolo) │   │  (decode + save .jpg)  │   │
│  └──────────────┘   └──────────────┘   └────────────────────────┘   │
│         │                                    │                      │
│         │                                    ▼                      │
│         │                           ┌──────────────┐                │
│         └──────────────────────────▶│ detector.py  │                │
│                                     │ (YOLO)       │                │
│                                     └──────┬───────┘                │
│                                            │                        │
│                                            ▼                        │
│                              JSON {"objects": ["person", ...]}      │
└─────────────────────────────────────────────────────────────────────┘
```

### Protocolo de comunicação

Cada requisição usa **uma conexão TCP** por foto. O fluxo é binário com prefixo de tamanho:

**Cliente → Servidor (envio da imagem)**

| Etapa | Formato | Descrição |
|-------|---------|-----------|
| 1 | 4 bytes (big-endian) | Tamanho da imagem em bytes |
| 2 | N bytes | Conteúdo JPEG da imagem |

**Servidor → Cliente (resposta)**

| Etapa | Formato | Descrição |
|-------|---------|-----------|
| 1 | 4 bytes (big-endian) | Tamanho do JSON em bytes |
| 2 | N bytes | JSON UTF-8: `{"objects": ["label1", "label2", ...]}` |

Em caso de erro no processamento, o servidor ainda responde com JSON contendo `"objects": []` e um campo `"error"`.

### Fluxo de uma captura

```
Usuário          App (Flutter)              Servidor (Python)
   │                    │                           │
   │  toca obturador    │                           │
   │───────────────────▶│                           │
   │                    │  captura foto (câmera)    │
   │                    │  corrige orientação       │
   │                    │  redimensiona (max 1280px)│
   │                    │  comprime JPEG (80%)      │
   │                    │                           │
   │                    │  TCP connect (IP:porta)   │
   │                    │──────────────────────────▶│
   │                    │  [4 bytes][imagem JPEG]   │
   │                    │──────────────────────────▶│
   │                    │                           │ decodifica imagem
   │                    │                           │ salva em received_images/
   │                    │                           │ YOLO detect (conf ≥ 0.5)
   │                    │  [4 bytes][JSON resposta] │
   │                    │◀──────────────────────────│
   │                    │  exibe chips com labels   │
   │◀───────────────────│                           │
   │  vê resultado      │                           │
```

### Componentes principais

| Camada | Arquivo | Responsabilidade |
|--------|---------|------------------|
| **App** | `home_screen.dart` | Interface: prévia da câmera, configuração do servidor, exibição do resultado |
| | `camera_service.dart` | Inicialização da câmera, alternância frontal/traseira, preparo da imagem para envio |
| | `socket_service.dart` | Conexão TCP, envio da imagem e leitura da resposta JSON |
| | `detection_result.dart` | Parse do JSON retornado pelo servidor |
| **Servidor** | `main.py` | Cria o socket, escuta conexões e delega o processamento |
| | `server.py` | Implementa o protocolo (receber imagem, enviar resposta) |
| | `detector.py` | Carrega o modelo YOLO e retorna os nomes das classes detectadas |
| | `image_utils.py` | Decodifica bytes com OpenCV e persiste a imagem recebida |

### Tratamento da imagem no app

Antes do envio, o `CameraService`:

1. Lê os bytes da foto capturada.
2. Corrige a orientação (`bakeOrientation`), especialmente na câmera frontal.
3. Redimensiona para largura máxima de **1280 px** (se necessário).
4. Comprime em **JPEG com qualidade 80%** para reduzir o tráfego de rede.

### Detecção no servidor

O `YOLODetector` usa o pacote **Ultralytics** com um modelo pré-treinado (`modelo_pretreinado.pt`). Para cada imagem:

1. Decodifica os bytes recebidos em array NumPy (OpenCV).
2. Executa inferência com limiar de confiança **0.5**.
3. Extrai os nomes das classes detectadas e retorna como lista de strings.
4. Salva a imagem em `server/received_images/` com timestamp no nome do arquivo.

---

## Licença

Este projeto é licenciado sob a [MIT License](LICENSE).

Projeto acadêmico da disciplina de Sistemas Distribuídos — UFPI.
