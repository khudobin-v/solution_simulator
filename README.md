# Симулятор растворения

Приложение для моделирования растворения твёрдых веществ методом клеточного автомата.  
Состоит из двух частей: **сервер** (FastAPI) и **клиент** (Flutter).

---

## Скачать готовое приложение

| Платформа | Файл |
|-----------|------|
| macOS | [dissolution-simulator-macos.dmg](https://github.com/khudobin-v/solution_simulator/releases/latest) |
| Windows | [dissolution-simulator-windows.zip](https://github.com/khudobin-v/solution_simulator/releases/latest) |

Приложение подключается к серверу автоматически — интернет-соединение обязательно.

### Установка macOS

1. Открыть DMG, перетащить приложение в **Applications**
2. При первом запуске: ПКМ на иконке → **Открыть** (обход Gatekeeper для неподписанных приложений)

### Установка Windows

1. Распаковать ZIP в любую папку
2. Запустить `client.exe`

---

## Сервер

Бэкенд задеплоен на Vercel: `https://program-kappa-five.vercel.app`

Эндпоинты:

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/health` | Проверка доступности |
| POST | `/api/auth/register` | Регистрация |
| POST | `/api/auth/login` | Вход |
| POST | `/api/simulations` | Запуск симуляции |
| GET | `/api/results` | Сохранённые результаты |

---

## Сборка из исходников

### Требования

| Компонент | Версия |
|-----------|--------|
| Python | 3.10+ |
| Flutter | 3.x (Dart SDK ≥ 3.12) |

### Локальный запуск сервера

```bash
cd server
bash start.sh
```

При первом запуске скрипт создаёт `.venv` и устанавливает зависимости.  
Сервер поднимается на `http://localhost:8000` в режиме `--reload`.

Чтобы клиент использовал локальный сервер, поменяйте `baseUrl` в [`client/lib/api_service.dart`](client/lib/api_service.dart):

```dart
const ApiService({this.baseUrl = 'http://localhost:8000'});
```

### Запуск клиента

```bash
cd client
flutter pub get
flutter run -d macos   # или -d windows
```

---

## Структура проекта

```
program/
├── api/
│   └── index.py          # точка входа для Vercel
├── server/               # FastAPI-сервер
│   ├── main.py
│   ├── simulation.py
│   ├── auth.py
│   ├── database.py
│   ├── models.py
│   ├── requirements.txt
│   └── start.sh
├── client/               # Flutter-приложение
│   ├── lib/
│   │   ├── main.dart
│   │   ├── api_service.dart
│   │   └── ...
│   └── pubspec.yaml
├── requirements.txt      # зависимости для Vercel
└── vercel.json
```
