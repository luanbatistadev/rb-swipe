# Code Style - dFora Mobile

## Princípios

### KISS (Keep It Simple, Stupid)
- Código simples e direto
- Evitar abstrações desnecessárias
- Preferir soluções óbvias

### DRY (Don't Repeat Yourself)
- Extrair código repetido para funções/classes reutilizáveis
- Usar constantes para valores repetidos

### YAGNI (You Aren't Gonna Need It)
- Não implementar funcionalidades "para o futuro"
- Implementar apenas o necessário agora

## Flutter/Dart

### Widgets
- **NÃO** criar métodos privados que retornam Widget (ex: `Widget _buildHeader()`)
- Preferir criar classes de Widget separadas para componentes reutilizáveis
- Para UI simples, manter inline no `build()`
- Widgets complexos devem ser extraídos para arquivos próprios

### State Management
- Usar `ValueNotifier` + `ValueListenableBuilder` (padrão do projeto)
- Stores em arquivos separados na pasta `store/`

### Nomenclatura
- Classes: PascalCase
- Variáveis/métodos: camelCase
- Constantes: camelCase
- Arquivos: snake_case
- Prefixo `_` para membros privados

### Imports
- Ordenar: dart, package, relativos
- Evitar imports não utilizados

### Estrutura de Arquivos
```
feature/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   └── repositories/
└── presentation/
    ├── pages/
    ├── store/
    ├── widgets/
    └── models/
```

## Boas Práticas

### Geral
- **SEM comentários** - código deve ser autoexplicativo
- Nomes descritivos para variáveis, métodos e classes
- Sem emojis em logs
- Métodos curtos e focados
- Early return para reduzir aninhamento

### Tratamento de Erros
- Usar try/catch apenas onde necessário
- Logs informativos sem emojis

### Firebase
- Queries otimizadas com limit()
- Batch operations quando possível
- Invalidar tokens no logout

### UI
- Usar cores do `AppColors`
- Usar estilos do `AppTextStyles`
- Respeitar o design system existente
- Usar `const` sempre que possível

## Padrões do Projeto

### Localização
- Textos em `l10n/` usando ARB
- Acessar via `context.l10n.key`

### Temas
- Cores em `AppColors`
- Estilos de texto em `AppTextStyles`

### Assets
- Ícones SVG em `assets/icons/`
- Usar `SvgPicture.asset()`
